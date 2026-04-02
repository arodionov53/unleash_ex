# Micro-benchmark for Constraint.check/3 function
# Focuses on the core evaluation performance differences
#
# Run with: mix run benchmark/micro_constraint_benchmark.exs
#
# Make sure to add {:benchee, "~> 1.0"} to your mix.exs dependencies

alias Unleash.Strategy.Constraint

defmodule MicroConstraintBenchmark do
  @moduledoc """
  Micro-benchmarks focusing on the core Constraint.check/3 function.

  This directly compares the performance of individual constraint operators
  between compiled and non-compiled versions to isolate the optimization impact.
  """

  # Test values for different constraint types
  @test_values %{
    string: "user123@example.com",
    numeric: "85",
    date: "2024-01-15",
    version: "1.2.3",
    list_value: "us-west"
  }

  def run_micro_benchmarks do
    IO.puts("""
    🔬 MICRO-BENCHMARK: Constraint.check/3 Function Performance
    #{String.duplicate("=", 70)}

    Testing the core constraint evaluation function with different operators.
    This isolates the performance impact of precompilation optimizations.

    Test values: #{inspect(@test_values, pretty: true)}
    """)

    benchmark_string_operations()
    benchmark_numeric_operations()
    benchmark_membership_operations()
    benchmark_date_operations()
    benchmark_version_operations()

    print_micro_summary()
  end

  defp benchmark_string_operations do
    IO.puts("\n📝 String Operations Benchmark")
    IO.puts(String.duplicate("-", 40))

    # STR_CONTAINS - benefits from binary pattern compilation
    contains_compiled = compile_operator("STR_CONTAINS", %{
      "values" => ["@example.com", "@test.org", "@company.net"]
    })

    contains_non_compiled = "STR_CONTAINS"
    contains_constraint = %{"values" => ["@example.com", "@test.org", "@company.net"]}

    # STR_CONTAINS with case insensitive - more complex compilation
    contains_ci_compiled = compile_operator("STR_CONTAINS", %{
      "values" => ["@EXAMPLE.COM", "@TEST.ORG"],
      "caseInsensitive" => true
    })

    Benchee.run(
      %{
        "STR_CONTAINS compiled" => fn ->
          Constraint.check(@test_values.string, contains_compiled, nil)
        end,
        "STR_CONTAINS non-compiled" => fn ->
          Constraint.check(@test_values.string, contains_non_compiled, contains_constraint)
        end,
        "STR_CONTAINS case-insensitive compiled" => fn ->
          Constraint.check(@test_values.string, contains_ci_compiled, nil)
        end
      },
      time: 2,
      memory_time: 1,
      formatters: [{Benchee.Formatters.Console, comparison: true}]
    )
  end

  defp benchmark_numeric_operations do
    IO.puts("\n🔢 Numeric Operations Benchmark")
    IO.puts(String.duplicate("-", 40))

    # NUM_GT - benefits from pre-parsed numeric values
    num_gt_compiled = compile_operator("NUM_GT", %{"value" => "80"})
    num_gt_non_compiled = "NUM_GT"
    num_gt_constraint = %{"value" => "80"}

    # NUM_EQ - simpler comparison
    num_eq_compiled = compile_operator("NUM_EQ", %{"value" => "85"})
    num_eq_non_compiled = "NUM_EQ"
    num_eq_constraint = %{"value" => "85"}

    Benchee.run(
      %{
        "NUM_GT compiled" => fn ->
          Constraint.check(@test_values.numeric, num_gt_compiled, nil)
        end,
        "NUM_GT non-compiled" => fn ->
          Constraint.check(@test_values.numeric, num_gt_non_compiled, num_gt_constraint)
        end,
        "NUM_EQ compiled" => fn ->
          Constraint.check(@test_values.numeric, num_eq_compiled, nil)
        end,
        "NUM_EQ non-compiled" => fn ->
          Constraint.check(@test_values.numeric, num_eq_non_compiled, num_eq_constraint)
        end
      },
      time: 2,
      memory_time: 1,
      formatters: [{Benchee.Formatters.Console, comparison: true}]
    )
  end

  defp benchmark_membership_operations do
    IO.puts("\n📋 Membership Operations Benchmark")
    IO.puts(String.duplicate("-", 40))

    # IN operation - benefits from compiled membership check
    in_compiled = compile_operator("IN", %{
      "values" => ["us-west", "us-east", "eu-west", "ap-south"]
    })
    in_non_compiled = "IN"
    in_constraint = %{"values" => ["us-west", "us-east", "eu-west", "ap-south"]}

    # NOT_IN operation
    not_in_compiled = compile_operator("NOT_IN", %{
      "values" => ["ap-north", "ap-east"]
    })
    not_in_non_compiled = "NOT_IN"
    not_in_constraint = %{"values" => ["ap-north", "ap-east"]}

    Benchee.run(
      %{
        "IN compiled" => fn ->
          Constraint.check(@test_values.list_value, in_compiled, nil)
        end,
        "IN non-compiled" => fn ->
          Constraint.check(@test_values.list_value, in_non_compiled, in_constraint)
        end,
        "NOT_IN compiled" => fn ->
          Constraint.check(@test_values.list_value, not_in_compiled, nil)
        end,
        "NOT_IN non-compiled" => fn ->
          Constraint.check(@test_values.list_value, not_in_non_compiled, not_in_constraint)
        end
      },
      time: 2,
      memory_time: 1,
      formatters: [{Benchee.Formatters.Console, comparison: true}]
    )
  end

  defp benchmark_date_operations do
    IO.puts("\n📅 Date Operations Benchmark")
    IO.puts(String.duplicate("-", 40))

    # DATE_AFTER - benefits from pre-parsed date values
    date_after_compiled = compile_operator("DATE_AFTER", %{"value" => "2024-01-01"})
    date_after_non_compiled = "DATE_AFTER"
    date_after_constraint = %{"value" => "2024-01-01"}

    Benchee.run(
      %{
        "DATE_AFTER compiled" => fn ->
          Constraint.check(@test_values.date, date_after_compiled, nil)
        end,
        "DATE_AFTER non-compiled" => fn ->
          Constraint.check(@test_values.date, date_after_non_compiled, date_after_constraint)
        end
      },
      time: 2,
      memory_time: 1,
      formatters: [{Benchee.Formatters.Console, comparison: true}]
    )
  end

  defp benchmark_version_operations do
    IO.puts("\n🏷️  Version Operations Benchmark")
    IO.puts(String.duplicate("-", 40))

    # SEMVER_GT - benefits from pre-parsed semantic versions
    semver_gt_compiled = compile_operator("SEMVER_GT", %{"value" => "1.0.0"})
    semver_gt_non_compiled = "SEMVER_GT"
    semver_gt_constraint = %{"value" => "1.0.0"}

    Benchee.run(
      %{
        "SEMVER_GT compiled" => fn ->
          Constraint.check(@test_values.version, semver_gt_compiled, nil)
        end,
        "SEMVER_GT non-compiled" => fn ->
          Constraint.check(@test_values.version, semver_gt_non_compiled, semver_gt_constraint)
        end
      },
      time: 2,
      memory_time: 1,
      formatters: [{Benchee.Formatters.Console, comparison: true}]
    )
  end

  # Helper function to create compiled operators using the internal compilation logic
  defp compile_operator(operator, constraint_map) do
    full_constraint = Map.put(constraint_map, "operator", operator)
    compiled_constraint = Constraint.from_map(full_constraint, true)
    compiled_constraint["operator"]
  end

  defp print_micro_summary do
    IO.puts("""

    #{String.duplicate("=", 70)}
    🔬 MICRO-BENCHMARK ANALYSIS

    Performance improvements from constraint precompilation:

    🚀 STRING OPERATIONS:
       • Binary pattern compilation via :binary.compile_pattern/1
       • Case-insensitive operations pre-convert patterns to lowercase
       • Avoid repeated pattern parsing on each evaluation

    ⚡ NUMERIC OPERATIONS:
       • Pre-parse string values to numbers during compilation
       • Eliminate to_number/1 calls during runtime evaluation
       • Direct numeric comparisons instead of string conversion

    📊 MEMBERSHIP OPERATIONS:
       • Compile to direct 'in' and 'not in' checks
       • Avoid list iteration and value comparison loops
       • Optimize for Erlang's efficient membership testing

    📆 DATE OPERATIONS:
       • Pre-parse date strings to internal date representations
       • Eliminate DateTime parsing overhead during evaluation
       • Direct date comparison instead of string parsing

    🏷️  VERSION OPERATIONS:
       • Pre-parse semantic versions using mk_semver/1
       • Cache parsed version structures for comparison
       • Avoid repeated version string parsing and validation

    The compiled approach trades upfront compilation time and memory
    for significantly faster runtime evaluation, especially beneficial
    for high-frequency constraint checking in production environments.

    #{String.duplicate("=", 70)}
    """)
  end
end

# Run the micro-benchmarks
MicroConstraintBenchmark.run_micro_benchmarks()