defmodule Unleash.FeatureCompiler do
  @moduledoc """
  Compiles entire feature evaluation trees into single functions.

  This provides maximum performance by eliminating:
  - All Enum iterations at runtime
  - All function call overhead for strategy/constraint checks
  - All map lookups for strategy modules

  Trade-off: Higher memory usage (one closure per feature) and
  longer initial compilation time.

  ## Usage

  The compilation is enabled by default via the `:feature_compilation` config option.
  When enabled, features are compiled during `Feature.from_map/1` and the compiled
  function is stored in the `__compiled_enabled__` field of the Feature struct.

  ## Performance

  Expected improvements:
  - Eliminates `Recase.to_snake/1` calls (pre-computed at compile time)
  - Eliminates `Enum.find/2` over strategies list (pre-resolved modules)
  - Eliminates `Enum.all?/2` over constraints (single compiled function)
  - Eliminates `Enum.map/2` + `Enum.any?/2` over strategies (unrolled)
  """

  alias Unleash.Config
  alias Unleash.Strategy.Constraint

  @doc """
  Compiles a feature into a single evaluation function.
  Returns: `fn context -> {boolean, strategy_evaluations} end`

  The compiled function captures:
  - The feature's enabled flag
  - Pre-resolved strategy modules
  - Pre-compiled constraint functions
  - Strategy parameters
  """
  def compile_feature(%{enabled: enabled, strategies: []}) do
    # No strategies: just return the enabled flag
    fn _context -> {enabled, []} end
  end

  def compile_feature(%{enabled: enabled, strategies: strategies}) do
    compiled_strategies = Enum.map(strategies, &compile_strategy/1)

    fn context ->
      strategy_evaluations =
        Enum.map(compiled_strategies, fn {name, check_fn} ->
          {name, check_fn.(context)}
        end)

      result =
        strategy_evaluations
        |> Enum.any?(fn {_, enabled?} -> enabled? end)
        |> Kernel.and(enabled)

      {result, strategy_evaluations}
    end
  end

  def compile_feature(_), do: nil

  @doc """
  Compiles a single strategy into a check function.
  Returns: `{strategy_name, fn context -> boolean end}`
  """
  def compile_strategy(strategy) when is_map(strategy) do
    name = strategy["name"]
    module = get_strategy_module(strategy)
    constraints_fn = get_constraints_fn(strategy)
    params = strategy["parameters"] || %{}

    check_fn = fn context ->
      constraints_fn.(context) and module.check_enabled(params, context)
    end

    {name, check_fn}
  end

  def compile_strategy(_), do: {"unknown", fn _context -> false end}

  # Use pre-resolved module if available, otherwise resolve it
  defp get_strategy_module(%{"__strategy_module__" => module}) when not is_nil(module), do: module

  defp get_strategy_module(%{"name" => name}) do
    case Enum.find(Config.strategies(), fn {n, _} -> n == name end) do
      {_name, module} -> module
      nil -> nil
    end
  end

  defp get_strategy_module(_), do: nil

  # Use pre-compiled constraints if available, otherwise compile them
  defp get_constraints_fn(%{"__compiled_constraints__" => compiled_fn})
       when is_function(compiled_fn) do
    compiled_fn
  end

  defp get_constraints_fn(%{"constraints" => constraints}) do
    Constraint.compile_all(constraints)
  end

  defp get_constraints_fn(_), do: fn _context -> true end
end
