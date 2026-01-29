defmodule Mix.Tasks.Benchmark.Feature do
  @moduledoc """
  Mix task for benchmarking feature evaluation performance.

  Compares performance across all compilation levels:
  - No compilation (baseline)
  - Constraint operator compilation only
  - Constraint list compilation + strategy module pre-resolution
  - Full feature compilation

  ## Usage

      mix benchmark.feature

  ## Options

      --quick       Run quick benchmark (reduced time)
      --stress      Include stress tests with multiple contexts
      --help        Show this help

  """

  use Mix.Task

  alias Unleash.Feature
  alias Unleash.FeatureCompiler
  alias Unleash.Strategy
  alias Unleash.Strategy.Constraint

  @shortdoc "Benchmark feature evaluation performance"

  @sample_feature_map %{
    "name" => "test-feature",
    "enabled" => true,
    "strategies" => [
      %{
        "name" => "flexibleRollout",
        "parameters" => %{"rollout" => 50, "stickiness" => "userId", "groupId" => "test"},
        "constraints" => [
          %{
            "contextName" => "appName",
            "operator" => "IN",
            "values" => ["app1", "app2", "app3"],
            "inverted" => false
          },
          %{
            "contextName" => "userId",
            "operator" => "STR_STARTS_WITH",
            "values" => ["user_"],
            "inverted" => false,
            "caseInsensitive" => false
          },
          %{
            "contextName" => "version",
            "operator" => "SEMVER_GT",
            "value" => "1.0.0",
            "inverted" => false
          }
        ]
      },
      %{
        "name" => "userWithId",
        "parameters" => %{"userIds" => "user_123,user_456,user_789"},
        "constraints" => [
          %{
            "contextName" => "environment",
            "operator" => "IN",
            "values" => ["production", "staging"],
            "inverted" => false
          }
        ]
      }
    ],
    "variants" => []
  }

  @sample_context %{
    app_name: "app1",
    user_id: "user_123",
    version: "1.2.3",
    environment: "production"
  }

  def run(args) do
    {options, _} =
      OptionParser.parse!(args,
        switches: [
          quick: :boolean,
          stress: :boolean,
          help: :boolean
        ]
      )

    if options[:help] do
      Mix.shell().info(@moduledoc)
    else
      # Ensure application is started for proper config access
      Mix.Task.run("app.start")

      run_benchmarks(options)
    end
  end

  defp run_benchmarks(options) do
    IO.puts("""
    FEATURE EVALUATION BENCHMARK
    #{String.duplicate("=", 60)}

    Comparing all compilation levels:
    1. No compilation (baseline)
    2. Constraint operator compilation only
    3. Constraint list + strategy module pre-resolution
    4. Full feature compilation

    Sample feature: #{@sample_feature_map["name"]}
    Strategies: #{length(@sample_feature_map["strategies"])}
    Total constraints: #{count_constraints(@sample_feature_map)}
    """)

    time = if options[:quick], do: 1, else: 3

    run_constraint_level_benchmark(time)
    run_feature_level_benchmark(time)

    if options[:stress] do
      run_stress_benchmark(time * 2)
    end

    print_summary()
  end

  defp count_constraints(%{"strategies" => strategies}) do
    strategies
    |> Enum.map(fn s -> length(s["constraints"] || []) end)
    |> Enum.sum()
  end

  defp run_constraint_level_benchmark(time) do
    IO.puts("\n[CONSTRAINT LEVEL BENCHMARK] (#{time}s each)")
    IO.puts(String.duplicate("-", 50))

    # Get constraints from first strategy for testing
    constraints_raw = hd(@sample_feature_map["strategies"])["constraints"]

    # Level 1: No compilation at all
    constraints_no_comp = Enum.map(constraints_raw, &Constraint.from_map(&1, false))

    # Level 2: Operator compilation only (current default)
    constraints_op_comp = Enum.map(constraints_raw, &Constraint.from_map(&1, true))

    # Level 3: Full constraint list compilation
    compiled_fn = Constraint.compile_all(constraints_op_comp, true)

    Benchee.run(
      %{
        "1. No compilation (baseline)" => fn ->
          Constraint.verify_all(constraints_no_comp, @sample_context)
        end,
        "2. Operator compilation only" => fn ->
          Constraint.verify_all(constraints_op_comp, @sample_context)
        end,
        "3. Constraint list compilation" => fn ->
          compiled_fn.(@sample_context)
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
      ]
    )
  end

  defp run_feature_level_benchmark(time) do
    IO.puts("\n[FEATURE LEVEL BENCHMARK] (#{time}s each)")
    IO.puts(String.duplicate("-", 50))

    # Build feature with different compilation levels
    # We need to temporarily modify config behavior, so we'll build manually

    # Level 1: No compilation - build strategies without compilation
    strategies_no_comp =
      @sample_feature_map["strategies"]
      |> Enum.map(fn s ->
        constraints = Enum.map(s["constraints"] || [], &Constraint.from_map(&1, false))

        s
        |> Map.put("constraints", constraints)
        |> Map.put("parameters", s["parameters"] || %{})
      end)

    feature_no_comp = %Feature{
      name: @sample_feature_map["name"],
      enabled: @sample_feature_map["enabled"],
      strategies: strategies_no_comp
    }

    # Level 2: Operator compilation + strategy pre-resolution (current)
    strategies_partial = Enum.map(@sample_feature_map["strategies"], &Strategy.update_map/1)

    feature_partial = %Feature{
      name: @sample_feature_map["name"],
      enabled: @sample_feature_map["enabled"],
      strategies: strategies_partial
    }

    # Level 3: Full feature compilation
    feature_full = %Feature{
      name: @sample_feature_map["name"],
      enabled: @sample_feature_map["enabled"],
      strategies: strategies_partial,
      __compiled_enabled__:
        FeatureCompiler.compile_feature(%{
          enabled: @sample_feature_map["enabled"],
          strategies: strategies_partial
        })
    }

    Benchee.run(
      %{
        "1. No compilation (baseline)" => fn ->
          Feature.enabled?(feature_no_comp, @sample_context)
        end,
        "2. Op comp + strategy pre-resolution" => fn ->
          Feature.enabled?(feature_partial, @sample_context)
        end,
        "3. Full feature compilation" => fn ->
          Feature.enabled?(feature_full, @sample_context)
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
      ]
    )
  end

  defp run_stress_benchmark(time) do
    IO.puts("\n[STRESS TEST] Multiple contexts (#{time}s each)")
    IO.puts(String.duplicate("-", 50))

    # Generate varied contexts
    contexts =
      for i <- 1..100 do
        %{
          app_name: Enum.random(["app1", "app2", "app3", "other"]),
          user_id: "user_#{i}",
          version: "1.#{rem(i, 5)}.#{rem(i, 10)}",
          environment: Enum.random(["production", "staging", "development"])
        }
      end

    # Build features
    strategies = Enum.map(@sample_feature_map["strategies"], &Strategy.update_map/1)

    feature_partial = %Feature{
      name: @sample_feature_map["name"],
      enabled: @sample_feature_map["enabled"],
      strategies: strategies
    }

    feature_full = %Feature{
      name: @sample_feature_map["name"],
      enabled: @sample_feature_map["enabled"],
      strategies: strategies,
      __compiled_enabled__:
        FeatureCompiler.compile_feature(%{
          enabled: @sample_feature_map["enabled"],
          strategies: strategies
        })
    }

    Benchee.run(
      %{
        "Partial compilation (100 contexts)" => fn ->
          Enum.map(contexts, &Feature.enabled?(feature_partial, &1))
        end,
        "Full compilation (100 contexts)" => fn ->
          Enum.map(contexts, &Feature.enabled?(feature_full, &1))
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true}
      ]
    )
  end

  defp print_summary do
    IO.puts("""

    #{String.duplicate("=", 60)}
    BENCHMARK SUMMARY

    Compilation Levels Explained:

    1. No compilation (baseline):
       - Constraints evaluated with string operators at runtime
       - Recase.to_snake called for every constraint check
       - Enum.find for strategy lookup on every evaluation

    2. Operator compilation + strategy pre-resolution:
       - Constraint operators pre-compiled to closures
       - Strategy modules pre-resolved at feature load
       - Constraint list still uses Enum.all? at runtime
       - Context field names (snake_case) pre-computed

    3. Full feature compilation:
       - Entire feature evaluation compiled to single function
       - All strategy/constraint checks inlined
       - Maximum performance, slightly higher memory

    Configuration:
    - constraint_precompilation: true (default) - enables operator compilation
    - feature_compilation: true (default) - enables full feature compilation

    #{String.duplicate("=", 60)}
    """)
  end
end
