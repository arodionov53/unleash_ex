defmodule Unleash.FeatureCompiler do
  @moduledoc """
  Compiles feature flags into closures stored in `persistent_term` at poll time.

  Instead of interpreting strategy/constraint maps on every `enabled?` call
  (ETS copy → strategy dispatch → constraint iteration), this module
  pre-resolves all invariant work into a single closure per feature:

  - Strategy module lookup (no `Map.fetch!` at eval time)
  - Constraint value parsing (NUM/SEMVER/DATE pre-parsed)
  - Context-name atom resolution (no `Recase.to_snake` at eval time)

  The closure is stored in `persistent_term` (zero-copy read) and called
  directly on the request path.
  """

  alias Unleash.Config
  alias Unleash.Feature
  alias Unleash.Strategy.Constraint

  @doc """
  Compiles all features and stores them in `persistent_term`.
  Called from `Unleash.Repo` after each successful features poll.
  """
  @spec compile_all([Feature.t()]) :: :ok
  def compile_all(features) do
    Enum.each(features, fn feature ->
      compiled = compile(feature)
      :persistent_term.put({:unleash_compiled, feature.name}, compiled)
    end)

    :persistent_term.put(:unleash_compiled_names, Enum.map(features, & &1.name))
    :ok
  end

  @doc """
  Removes compiled entries for features that no longer exist.
  Called after `compile_all/1` to clean up stale persistent_term keys.
  """
  @spec cleanup([Feature.t()]) :: :ok
  def cleanup(features) do
    current_names = MapSet.new(features, & &1.name)
    old_names = :persistent_term.get(:unleash_compiled_names, [])

    Enum.each(old_names, fn name ->
      unless MapSet.member?(current_names, name) do
        :persistent_term.erase({:unleash_compiled, name})
      end
    end)

    :ok
  end

  @doc """
  Returns the compiled entry for a feature, or nil if not found.
  """
  @spec get(String.t()) :: map() | nil
  def get(name) when is_binary(name) do
    :persistent_term.get({:unleash_compiled, name}, nil)
  end

  def get(name) when is_atom(name), do: get(Atom.to_string(name))

  # -- Private compilation --

  defp compile(%Feature{enabled: false} = f) do
    %{enabled: false, eval: fn _ctx -> false end, feature: f}
  end

  defp compile(%Feature{enabled: true, strategies: []} = f) do
    %{enabled: true, eval: fn _ctx -> true end, feature: f}
  end

  defp compile(%Feature{enabled: true, strategies: strategies} = f) do
    compiled_strategies = Enum.map(strategies, &compile_strategy/1)

    eval = fn context ->
      Enum.any?(compiled_strategies, fn {module, params, constraint_fn} ->
        constraint_fn.(context) and module.check_enabled(params, context)
      end)
    end

    %{enabled: true, eval: eval, feature: f}
  end

  defp compile_strategy(strategy) do
    name = strategy["name"]
    module = Map.fetch!(Config.strategies_map(), name)
    params = strategy["parameters"] || %{}
    constraints = strategy["constraints"] || []

    constraint_fn = compile_constraints(constraints)

    {module, params, constraint_fn}
  end

  defp compile_constraints([]), do: fn _ctx -> true end

  defp compile_constraints(constraints) do
    precomputed = Enum.map(constraints, &Constraint.precompute/1)
    fn context -> Constraint.verify_all(precomputed, context) end
  end
end
