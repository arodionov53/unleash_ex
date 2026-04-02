# Constraint Evaluation Benchmark
# Compares performance of constraint evaluation with and without precompilation
#
# Run with: mix run benchmark/constraint_benchmark.exs
#
# Make sure to add {:benchee, "~> 1.0"} to your mix.exs dependencies

alias Unleash.Strategy.Constraint

defmodule ConstraintBenchmark do
  @moduledoc """
  Benchmarks for constraint evaluation performance comparing:
  - Compiled constraints (constraint_precompilation: true)
  - Non-compiled constraints (constraint_precompilation: false)
  """

  # Sample contexts for testing different constraint types
  @user_context %{
    "userId" => "user123",
    "sessionId" => "session456",
    "email" => "test@example.com",
    "appName" => "myApp",
    "version" => "1.2.3",
    "date" => "2024-01-15",
    "region" => "us-west",
    "score" => "85",
    "tags" => ["premium", "beta"],
    "hostname" => "api.example.com"
  }

  # Constraint definitions for benchmarking
  @constraints %{
    # String operations
    string_contains: %{
      "contextName" => "email",
      "operator" => "STR_CONTAINS",
      "values" => ["@example.com", "@test.org"],
      "caseInsensitive" => false
    },
    string_contains_case_insensitive: %{
      "contextName" => "email",
      "operator" => "STR_CONTAINS",
      "values" => ["@EXAMPLE.COM", "@TEST.ORG"],
      "caseInsensitive" => true
    },
    string_starts_with: %{
      "contextName" => "email",
      "operator" => "STR_STARTS_WITH",
      "values" => ["test", "admin"],
      "caseInsensitive" => false
    },
    string_ends_with: %{
      "contextName" => "email",
      "operator" => "STR_ENDS_WITH",
      "values" => [".com", ".org"],
      "caseInsensitive" => false
    },

    # Numeric operations
    num_equal: %{
      "contextName" => "score",
      "operator" => "NUM_EQ",
      "value" => "85"
    },
    num_greater_than: %{
      "contextName" => "score",
      "operator" => "NUM_GT",
      "value" => "80"
    },
    num_less_than_equal: %{
      "contextName" => "score",
      "operator" => "NUM_LTE",
      "value" => "90"
    },

    # In/Not In operations
    in_operation: %{
      "contextName" => "region",
      "operator" => "IN",
      "values" => ["us-west", "us-east", "eu-west"]
    },
    not_in_operation: %{
      "contextName" => "region",
      "operator" => "NOT_IN",
      "values" => ["ap-south", "ap-north"]
    },

    # Date operations
    date_after: %{
      "contextName" => "date",
      "operator" => "DATE_AFTER",
      "value" => "2024-01-01"
    },
    date_before: %{
      "contextName" => "date",
      "operator" => "DATE_BEFORE",
      "value" => "2024-12-31"
    },

    # Semantic version operations
    semver_equal: %{
      "contextName" => "version",
      "operator" => "SEMVER_EQ",
      "value" => "1.2.3"
    },
    semver_greater_than: %{
      "contextName" => "version",
      "operator" => "SEMVER_GT",
      "value" => "1.0.0"
    }
  }

  def create_constraints_compiled do
    @constraints
    |> Enum.map(fn {key, constraint_map} ->
      {key, Constraint.from_map(constraint_map, true)}
    end)
    |> Map.new()
  end

  def create_constraints_non_compiled do
    @constraints
    |> Enum.map(fn {key, constraint_map} ->
      {key, Constraint.from_map(constraint_map, false)}
    end)
    |> Map.new()
  end

  def create_constraint_lists do
    compiled = create_constraints_compiled()
    non_compiled = create_constraints_non_compiled()

    # Create lists of all constraints for batch verification
    compiled_list = Map.values(compiled)
    non_compiled_list = Map.values(non_compiled)

    {compiled, non_compiled, compiled_list, non_compiled_list}
  end

  def run_single_constraint_benchmarks do
    {compiled, non_compiled, _, _} = create_constraint_lists()

    IO.puts("🚀 Running Single Constraint Verification Benchmarks...")
    IO.puts("=" |> String.duplicate(60))

    @constraints
    |> Map.keys()
    |> Enum.each(fn constraint_key ->
      IO.puts("\n📊 Benchmarking: #{constraint_key}")

      compiled_constraint = Map.get(compiled, constraint_key)
      non_compiled_constraint = Map.get(non_compiled, constraint_key)

      Benchee.run(
        %{
          "compiled (precompilation: true)" => fn ->
            Constraint.verify_all([compiled_constraint], @user_context)
          end,
          "non-compiled (precompilation: false)" => fn ->
            Constraint.verify_all([non_compiled_constraint], @user_context)
          end
        },
        time: 3,
        memory_time: 1,
        formatters: [
          {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
        ]
      )
    end)
  end

  def run_batch_constraint_benchmarks do
    {_, _, compiled_list, non_compiled_list} = create_constraint_lists()

    IO.puts("\n🎯 Running Batch Constraint Verification Benchmarks...")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Testing all #{length(compiled_list)} constraints together")

    Benchee.run(
      %{
        "compiled batch (precompilation: true)" => fn ->
          Constraint.verify_all(compiled_list, @user_context)
        end,
        "non-compiled batch (precompilation: false)" => fn ->
          Constraint.verify_all(non_compiled_list, @user_context)
        end
      },
      time: 5,
      memory_time: 2,
      formatters: [
        {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
      ]
    )
  end

  def run_constraint_creation_benchmarks do
    IO.puts("\n⚡ Running Constraint Creation Benchmarks...")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Testing constraint compilation overhead")

    sample_constraints = [
      @constraints.string_contains,
      @constraints.num_greater_than,
      @constraints.in_operation,
      @constraints.date_after,
      @constraints.semver_greater_than
    ]

    Benchee.run(
      %{
        "constraint creation (compiled)" => fn ->
          Enum.map(sample_constraints, &Constraint.from_map(&1, true))
        end,
        "constraint creation (non-compiled)" => fn ->
          Enum.map(sample_constraints, &Constraint.from_map(&1, false))
        end
      },
      time: 3,
      memory_time: 1,
      formatters: [
        {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
      ]
    )
  end

  def run_stress_test_benchmarks do
    {_, _, compiled_list, non_compiled_list} = create_constraint_lists()

    IO.puts("\n🔥 Running Stress Test Benchmarks...")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("Testing constraint evaluation under high load")

    # Create a larger set of contexts to simulate real-world usage
    contexts = 1..100
    |> Enum.map(fn i ->
      %{
        "userId" => "user#{i}",
        "sessionId" => "session#{i}",
        "email" => "user#{i}@example.com",
        "appName" => "myApp",
        "version" => "1.2.#{rem(i, 10)}",
        "date" => "2024-01-#{rem(i, 28) + 1 |> Integer.to_string() |> String.pad_leading(2, "0")}",
        "region" => Enum.random(["us-west", "us-east", "eu-west", "ap-south"]),
        "score" => "#{80 + rem(i, 20)}",
        "tags" => if(rem(i, 2) == 0, do: ["premium"], else: ["basic"]),
        "hostname" => "api#{rem(i, 5)}.example.com"
      }
    end)

    Benchee.run(
      %{
        "stress test compiled (100 contexts)" => fn ->
          Enum.all?(contexts, &Constraint.verify_all(compiled_list, &1))
        end,
        "stress test non-compiled (100 contexts)" => fn ->
          Enum.all?(contexts, &Constraint.verify_all(non_compiled_list, &1))
        end
      },
      time: 10,
      memory_time: 3,
      formatters: [
        {Benchee.Formatters.Console, comparison: true, extended_statistics: true}
      ]
    )
  end

  def print_summary do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("📈 CONSTRAINT BENCHMARK SUMMARY")
    IO.puts(String.duplicate("=", 80))
    IO.puts("""
    This benchmark compared constraint evaluation performance between:

    🟢 COMPILED MODE (constraint_precompilation: true - DEFAULT)
       - Pre-compiles operators into anonymous functions at load time
       - Pre-parses values (numbers, dates, patterns) during initialization
       - Uses Erlang binary pattern compilation for string operations

    🔴 NON-COMPILED MODE (constraint_precompilation: false)
       - Evaluates operators as strings with pattern matching at runtime
       - Parses values during each constraint check
       - No pre-compilation optimizations

    Key Performance Insights:
    • Compiled constraints should show significant performance gains
    • Memory usage may be slightly higher for compiled due to closures
    • Creation time is higher for compiled due to upfront compilation cost
    • Runtime evaluation should be much faster for compiled constraints
    • Benefits increase with constraint complexity and evaluation frequency

    Configuration:
    • Default setting: constraint_precompilation: true (recommended)
    • Can be overridden in config files or environment variables
    • Applied when features are loaded from Unleash server
    """)
    IO.puts(String.duplicate("=", 80))
  end

  def run_all_benchmarks do
    IO.puts("""
    🎪 UNLEASH CONSTRAINT EVALUATION BENCHMARK SUITE
    #{String.duplicate("=", 80)}

    Testing constraint evaluation performance with and without precompilation.
    This will run several benchmark scenarios:

    1. Single Constraint Tests - Individual operator performance
    2. Batch Constraint Tests - Multiple constraints together
    3. Constraint Creation Tests - Compilation overhead
    4. Stress Tests - High-load simulation

    Sample Context: #{inspect(@user_context, pretty: true)}

    Total Constraints: #{map_size(@constraints)}
    """)

    run_single_constraint_benchmarks()
    run_batch_constraint_benchmarks()
    run_constraint_creation_benchmarks()
    run_stress_test_benchmarks()
    print_summary()
  end
end

# Run the complete benchmark suite
ConstraintBenchmark.run_all_benchmarks()