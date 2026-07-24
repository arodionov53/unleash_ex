defmodule Unleash.MetricsFast do
  @moduledoc """
  High-performance metrics collection using Exfoil-compiled lookup modules and
  optimizations.

  Key optimizations:
  1. Cached disable_metrics flag at startup (no runtime Config check)
  2. Direct :counters for lock-free atomic updates
  3. Feature/variant name -> counter *slot id* lookup is an Exfoil-compiled
     module (`Exfoil.Maps.convert/2`), giving allocation-free reads once
     `register_features/1` has warmed it up
  4. Pre-initialized counters for known features
  5. Minimal pattern matching in hot path

  ## Why an indirection through slot ids

  Exfoil compiles the values it's given directly into a module's source via
  `Macro.escape/1`, which cannot represent references - and every
  `:counters` instance is itself a term containing a reference. So a
  feature/variant name cannot map directly to its own `:counters` reference
  through Exfoil.

  Instead, each known name maps to a small integer *slot id* (escapable),
  and the actual mutable tallies live in one shared `:counters` block per
  table (features, variants), stored in `:persistent_term` so reads never
  go through the GenServer. A feature's yes/no counts live at slots
  `2 * id - 1` and `2 * id`; a variant's count lives at slot `id`.

  Because Exfoil lookup modules are immutable snapshots, previously-unseen
  names (not passed through `register_features/1`) fall back to a
  `GenServer.call/2` that assigns a slot id (growing the shared `:counters`
  block if needed) and recompiles the lookup module in place. This keeps the
  common case (registered features) on a pure, message-passing-free read
  path while still supporting features that show up outside of the
  registration flow.

  Growing the shared `:counters` block allocates a new, larger block and
  copies existing tallies over before swapping it into `:persistent_term`.
  This only happens on a cold name or a `register_features/1` call that
  introduces new names - not on every metric update - but it does mean any
  increment racing with a growth's copy-and-swap can land on the
  about-to-be-discarded block and be lost. This is an accepted trade-off:
  growth is rare, and losing an occasional increment during it is
  preferable to serializing every read behind the GenServer.

  Performance: ~70-100 ns per metric update (vs ~22 μs for GenServer-based)
  """

  use GenServer

  alias Exfoil.Maps
  alias Unleash.Config
  alias Unleash.Feature

  require Logger

  @counter_index Unleash.MetricsFast.CounterIndex
  @variant_index Unleash.MetricsFast.VariantIndex
  @meta_table :unleash_metrics_fast_meta

  @counter_slots_key :unleash_metrics_fast_counter_slots
  @variant_slots_key :unleash_metrics_fast_variant_slots

  # A feature needs 2 slots (yes/no); a variant needs 1. Start small - growth
  # doubles the block as needed, so this only affects how many early growths
  # happen before things settle.
  @initial_counter_slots 2
  @initial_variant_slots 1

  # @counter_index/@variant_index only exist once Exfoil.Maps.convert/2 has
  # compiled them at runtime (see recompile/2, called from init/1) - the
  # compiler can't see them ahead of time, so silence the undefined-module
  # warning for the fixed set of Map-API functions Exfoil generates.
  @compile {:no_warn_undefined,
            [
              {Unleash.MetricsFast.CounterIndex, :fetch, 1},
              {Unleash.MetricsFast.CounterIndex, :all, 0},
              {Unleash.MetricsFast.CounterIndex, :to_map, 0},
              {Unleash.MetricsFast.VariantIndex, :fetch, 1},
              {Unleash.MetricsFast.VariantIndex, :all, 0},
              {Unleash.MetricsFast.VariantIndex, :to_map, 0}
            ]}

  # ============================================================
  # Public API - Optimized for speed
  # ============================================================

  @doc """
  Add a metric for a feature flag check. Optimized for minimal overhead.
  Returns the enabled? value unchanged for pipeline compatibility.
  """
  @spec add_metric({Feature.t() | any(), boolean()}) :: boolean()
  def add_metric({%Feature{name: name}, enabled?}) do
    if metrics_enabled?() do
      {ref, id} = get_or_create_counter(name)
      :counters.add(ref, counter_slot(id, enabled?), 1)
    end

    enabled?
  end

  def add_metric({_non_feature, enabled?}), do: enabled?

  @doc """
  Add a metric for a variant check.
  """
  @spec add_variant_metric({Feature.t() | any(), map()}) :: map()
  def add_variant_metric({%Feature{name: name, enabled: enabled?}, %{name: variant_name} = variant}) do
    if metrics_enabled?() do
      # Update feature counter
      {ref, id} = get_or_create_counter(name)
      :counters.add(ref, counter_slot(id, enabled?), 1)

      # Update variant counter
      {variant_ref, variant_id} = get_or_create_variant_counter(name, variant_name)
      :counters.add(variant_ref, variant_id, 1)
    end

    variant
  end

  def add_variant_metric({_non_feature, variant}), do: variant

  @doc """
  Bulk register features to pre-create counters.
  Call this when features are loaded to avoid counter creation overhead during checks.
  """
  @spec register_features([Feature.t()]) :: :ok
  def register_features(features) when is_list(features) do
    GenServer.call(__MODULE__, {:register_features, features})
  end

  @doc """
  Get current metrics as a bucket for sending to server.
  """
  @spec get_metrics() :: {:ok, map()}
  def get_metrics do
    {:ok, to_bucket(collect_metrics())}
  end

  @doc """
  Force send metrics to server (for testing).
  """
  @spec do_send_metrics() :: :ok
  def do_send_metrics do
    GenServer.call(__MODULE__, :send_metrics)
  end

  # ============================================================
  # Fast path - inlined for performance
  # ============================================================

  @compile {:inline, metrics_enabled?: 0, counter_slot: 2}

  defp metrics_enabled? do
    case :ets.lookup(@meta_table, :metrics_enabled) do
      [{:metrics_enabled, enabled}] -> enabled
      [] -> true
    end
  end

  defp counter_slot(id, true), do: 2 * id - 1
  defp counter_slot(id, false), do: 2 * id

  defp get_or_create_counter(name) do
    case @counter_index.fetch(name) do
      {:ok, id} -> {:persistent_term.get(@counter_slots_key), id}
      :error -> GenServer.call(__MODULE__, {:create_counter, name})
    end
  end

  defp get_or_create_variant_counter(feature_name, variant_name) do
    key = {feature_name, variant_name}

    case @variant_index.fetch(key) do
      {:ok, id} -> {:persistent_term.get(@variant_slots_key), id}
      :error -> GenServer.call(__MODULE__, {:create_variant_counter, feature_name, variant_name})
    end
  end

  # ============================================================
  # Metrics collection and sending
  # ============================================================

  defp collect_metrics do
    ref = :persistent_term.get(@counter_slots_key)
    variant_ref = :persistent_term.get(@variant_slots_key)

    toggles =
      @counter_index.all()
      |> Enum.reduce(%{}, fn {name, id}, acc ->
        yes = :counters.get(ref, counter_slot(id, true))
        no = :counters.get(ref, counter_slot(id, false))

        variants = collect_variants(name, variant_ref)

        entry =
          if map_size(variants) > 0 do
            %{yes: yes, no: no, variants: variants}
          else
            %{yes: yes, no: no}
          end

        Map.put(acc, name, entry)
      end)

    %{
      start: get_start_time(),
      toggles: toggles
    }
  end

  defp collect_variants(feature_name, variant_ref) do
    @variant_index.all()
    |> Enum.reduce(%{}, fn
      {{^feature_name, variant_name}, id}, acc ->
        Map.put(acc, variant_name, :counters.get(variant_ref, id))

      _, acc ->
        acc
    end)
  end

  defp reset_metrics do
    ref = :persistent_term.get(@counter_slots_key)

    @counter_index.all()
    |> Enum.each(fn {_name, id} ->
      :counters.put(ref, counter_slot(id, true), 0)
      :counters.put(ref, counter_slot(id, false), 0)
    end)

    variant_ref = :persistent_term.get(@variant_slots_key)

    @variant_index.all()
    |> Enum.each(fn {_key, id} ->
      :counters.put(variant_ref, id, 0)
    end)

    set_start_time()
  end

  defp get_start_time do
    case :ets.lookup(@meta_table, :start_time) do
      [{:start_time, time}] -> time
      [] -> current_date()
    end
  end

  defp set_start_time do
    :ets.insert(@meta_table, {:start_time, current_date()})
  end

  defp to_bucket(state) do
    %{bucket: Map.put(state, :stop, current_date())}
  end

  defp current_date do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end

  # ============================================================
  # Exfoil lookup module (re)compilation + shared :counters growth helpers
  # ============================================================

  # Exfoil lookup modules are immutable snapshots - recompiling the same
  # module name is expected here (every counter/variant creation and every
  # register_features/1 call redefines it), so silence the standard
  # "redefining module" compiler warning around the recompile itself.
  defp recompile(module_name, map) do
    previous = Code.compiler_options(ignore_module_conflict: true)

    try do
      {:ok, module_name} = Maps.convert(map, module_name)
      module_name
    after
      Code.compiler_options(previous)
    end
  end

  # Ensures the shared :counters block stored under `pt_key` has at least
  # `needed_slots` slots, growing (allocate new block, copy old tallies,
  # swap into persistent_term) if it doesn't. Always called from inside the
  # GenServer, so growth itself is serialized.
  defp ensure_capacity(pt_key, needed_slots) do
    ref = :persistent_term.get(pt_key)
    current_size = :counters.info(ref).size

    if needed_slots > current_size do
      new_size = max(needed_slots, current_size * 2)
      new_ref = :counters.new(new_size, [:write_concurrency])

      for slot <- 1..current_size do
        :counters.put(new_ref, slot, :counters.get(ref, slot))
      end

      :persistent_term.put(pt_key, new_ref)
      new_ref
    else
      ref
    end
  end

  # ============================================================
  # GenServer callbacks (only for initialization and periodic sending)
  # ============================================================

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :persistent_term.put(@counter_slots_key, :counters.new(@initial_counter_slots, [:write_concurrency]))
    :persistent_term.put(@variant_slots_key, :counters.new(@initial_variant_slots, [:write_concurrency]))

    recompile(@counter_index, %{})
    recompile(@variant_index, %{})

    :ets.new(@meta_table, [:named_table, :public, :set])

    # Cache the disable_metrics config
    :ets.insert(@meta_table, {:metrics_enabled, not Config.disable_metrics()})

    set_start_time()

    unless Config.test?() do
      schedule_metrics()
    end

    {:ok, %{}}
  end

  @impl true
  def handle_call(:send_metrics, _from, state) do
    send_metrics_to_server()
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    {:reply, get_metrics(), state}
  end

  @impl true
  def handle_call({:create_counter, name}, _from, state) do
    {ref, id} =
      case @counter_index.fetch(name) do
        {:ok, id} ->
          {:persistent_term.get(@counter_slots_key), id}

        :error ->
          map = @counter_index.to_map()
          id = map_size(map) + 1
          ref = ensure_capacity(@counter_slots_key, id * 2)
          recompile(@counter_index, Map.put(map, name, id))
          {ref, id}
      end

    {:reply, {ref, id}, state}
  end

  @impl true
  def handle_call({:create_variant_counter, feature_name, variant_name}, _from, state) do
    key = {feature_name, variant_name}

    {ref, id} =
      case @variant_index.fetch(key) do
        {:ok, id} ->
          {:persistent_term.get(@variant_slots_key), id}

        :error ->
          map = @variant_index.to_map()
          id = map_size(map) + 1
          ref = ensure_capacity(@variant_slots_key, id)
          recompile(@variant_index, Map.put(map, key, id))
          {ref, id}
      end

    {:reply, {ref, id}, state}
  end

  @impl true
  def handle_call({:register_features, features}, _from, state) do
    counters_map = @counter_index.to_map()
    variants_map = @variant_index.to_map()

    {new_counters_map, new_variants_map} = merge_features(features, counters_map, variants_map)

    if map_size(new_counters_map) != map_size(counters_map) do
      ensure_capacity(@counter_slots_key, map_size(new_counters_map) * 2)
      recompile(@counter_index, new_counters_map)
    end

    if map_size(new_variants_map) != map_size(variants_map) do
      ensure_capacity(@variant_slots_key, map_size(new_variants_map))
      recompile(@variant_index, new_variants_map)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:send_metrics, state) do
    send_metrics_to_server()
    schedule_metrics()
    {:noreply, state}
  end

  defp send_metrics_to_server do
    bucket = to_bucket(collect_metrics())

    case Config.client().metrics(bucket) do
      {:ok, _} ->
        reset_metrics()

      error ->
        Logger.error("#{Config.appname()} #{__MODULE__}; HTTP response: #{inspect(error)}")
    end
  end

  defp schedule_metrics do
    Process.send_after(self(), :send_metrics, Config.metrics_period())
  end

  # Assigns the next free integer slot id to any name in `features` (and
  # their variants) not already present in `counters_map`/`variants_map`.
  # Ids are assigned sequentially by insertion order, starting at
  # map_size(...) + 1, so every name keeps a stable id for its lifetime.
  defp merge_features(features, counters_map, variants_map) do
    Enum.reduce(features, {counters_map, variants_map}, fn
      %Feature{name: name, variants: feature_variants}, {counters_map, variants_map} ->
        counters_map = assign_id(counters_map, name)
        variants_map = merge_variants(feature_variants, name, variants_map)
        {counters_map, variants_map}

      _, acc ->
        acc
    end)
  end

  defp merge_variants(feature_variants, feature_name, variants_map) do
    Enum.reduce(feature_variants, variants_map, fn
      %{name: variant_name}, variants_map -> assign_id(variants_map, {feature_name, variant_name})
      _, variants_map -> variants_map
    end)
  end

  defp assign_id(map, key) do
    Map.put_new_lazy(map, key, fn -> map_size(map) + 1 end)
  end
end
