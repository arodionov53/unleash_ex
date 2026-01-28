defmodule Mix.Tasks.Benchmark.Constraint do
  @moduledoc """
  Mix task for benchmarking constraint evaluation performance.

  Compares performance between compiled and non-compiled constraints.

  ## Usage

      mix benchmark.constraint

  ## Options

      --quick       Run quick benchmark (reduced time)
      --stress      Include stress tests with multiple contexts
      --creation    Benchmark constraint creation overhead
      --help        Show this help

  """

  use Mix.Task

  alias Unleash.Strategy.Constraint

  @shortdoc "Benchmark constraint evaluation performance"

  @sample_context %{
    "userId" => "user123",
    "email" => "test@example.com",
    "version" => "1.2.3",
    "score" => "85",
    "region" => "us-west",
    "date" => "2024-01-15"
  }

  @test_constraints [
    # String operations with pattern compilation benefits
    %{
      "contextName" => "email",
      "operator" => "STR_CONTAINS",
      "values" => ["@example.com", "@test.org", "@company.net"],
      "caseInsensitive" => false
    },
    # Numeric operations with parsing benefits
    %{
      "contextName" => "score",
      "operator" => "NUM_GT",
      "value" => "80"
    },
    # In operations with membership testing
    %{
      "contextName" => "region",
      "operator" => "IN",
      "values" => ["us-west", "us-east", "eu-west", "ap-south"]
    },
    # Date operations with parsing benefits
    %{
      "contextName" => "date",
      "operator" => "DATE_AFTER",
      "value" => "2024-01-01"
    },
    # Semver operations with version parsing benefits
    %{
      "contextName" => "version",
      "operator" => "SEMVER_GT",
      "value" => "1.0.0"
    }
  ]

  def run(args) do
    {options, _} = OptionParser.parse!(args,
      switches: [
        quick: :boolean,
        stress: :boolean,
        creation: :boolean,
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
    🎯 CONSTRAINT EVALUATION BENCHMARK
    #{String.duplicate("=", 50)}

    Comparing compiled vs non-compiled constraint evaluation.
    Sample context: #{inspect(@sample_context, limit: :infinity)}
    Test constraints: #{length(@test_constraints)} different operators
    """)

    time = if options[:quick], do: 1, else: 3

    run_core_benchmark(time)

    if options[:creation] do
      run_creation_benchmark(time)
    end

    if options[:stress] do
      run_stress_benchmark(time * 2)
    end

    print_results_summary()
  end

  defp run_core_benchmark(time) do
    compiled_constraints = Enum.map(@test_constraints, &Constraint.from_map(&1, true))
    non_compiled_constraints = Enum.map(@test_constraints, &Constraint.from_map(&1, false))

    IO.puts("\n📊 Core Performance Benchmark (#{time}s each)")
    IO.puts(String.duplicate("-", 40))

    Benchee.run(
      %{
        "compiled (precompilation: true)" => fn ->
          Constraint.verify_all(compiled_constraints, @sample_context)
        end,
        "non-compiled (precompilation: false)" => fn ->
          Constraint.verify_all(non_compiled_constraints, @sample_context)
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
      ]
    )
  end

  defp run_creation_benchmark(time) do
    IO.puts("\n⚡ Constraint Creation Overhead Benchmark")
    IO.puts(String.duplicate("-", 40))

    Benchee.run(
      %{
        "creation compiled" => fn ->
          Enum.map(@test_constraints, &Constraint.from_map(&1, true))
        end,
        "creation non-compiled" => fn ->
          Enum.map(@test_constraints, &Constraint.from_map(&1, false))
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true}
      ]
    )
  end

  defp run_stress_benchmark(time) do
    compiled_constraints = Enum.map(@test_constraints, &Constraint.from_map(&1, true))
    non_compiled_constraints = Enum.map(@test_constraints, &Constraint.from_map(&1, false))

    # Generate varied contexts
    contexts = for i <- 1..50 do
      %{
        "userId" => "user#{i}",
        "email" => "user#{i}@example.com",
        "version" => "1.2.#{rem(i, 10)}",
        "score" => "#{75 + rem(i, 25)}",
        "region" => Enum.random(["us-west", "us-east", "eu-west"]),
        "date" => "2024-01-#{rem(i, 28) + 1 |> Integer.to_string() |> String.pad_leading(2, "0")}"
      }
    end

    IO.puts("\n🔥 Stress Test (50 contexts, #{time}s each)")
    IO.puts(String.duplicate("-", 40))

    Benchee.run(
      %{
        "stress compiled" => fn ->
          Enum.all?(contexts, &Constraint.verify_all(compiled_constraints, &1))
        end,
        "stress non-compiled" => fn ->
          Enum.all?(contexts, &Constraint.verify_all(non_compiled_constraints, &1))
        end
      },
      time: time,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true}
      ]
    )
  end

  defp print_results_summary do
    IO.puts("""

    #{String.duplicate("=", 60)}
    📈 BENCHMARK SUMMARY

    Constraint precompilation (constraint_precompilation: true) provides:
    • Faster runtime evaluation through pre-compiled functions
    • Binary pattern compilation for string operations
    • Pre-parsed numeric and date values
    • Reduced CPU overhead during high-frequency evaluations

    Trade-offs:
    • Slightly higher memory usage (closures store compiled state)
    • Longer initial compilation time when constraints are loaded
    • Overall recommended for production workloads

    Configuration:
    • Default: constraint_precompilation: true (in config.ex:32)
    • Override in config/*.exs or via Config.constraint_precompilation/0
    • Applied during Constraint.from_map/1 calls when features load

    #{String.duplicate("=", 60)}
    """)
  end
end