defmodule Mix.Tasks.Benchmark.Constraint do
  @moduledoc "Benchmarks constraint evaluation with vs without precomputed values."
  use Mix.Task

  alias Unleash.Strategy.Constraint

  @shortdoc "Benchmark constraint precompute optimization"

  def run(_args) do
    # --- Numeric constraints ---
    num_constraint_raw = %{
      "contextName" => "buildNumber",
      "operator" => "NUM_GTE",
      "value" => "500",
      "values" => [],
      "inverted" => false
    }

    num_constraint_precomputed = Constraint.precompute(num_constraint_raw)

    # --- Semver constraints ---
    semver_constraint_raw = %{
      "contextName" => "appVersion",
      "operator" => "SEMVER_GT",
      "value" => "2.10.3",
      "values" => [],
      "inverted" => false
    }

    semver_constraint_precomputed = Constraint.precompute(semver_constraint_raw)

    # --- Date constraints ---
    date_constraint_raw = %{
      "contextName" => "currentTime",
      "operator" => "DATE_AFTER",
      "value" => "2023-06-15T10:30:00Z",
      "values" => [],
      "inverted" => false
    }

    date_constraint_precomputed = Constraint.precompute(date_constraint_raw)

    context = %{
      build_number: "1200",
      app_version: "3.1.0",
      current_time: "2024-01-01T00:00:00Z"
    }

    IO.puts("\n=== Numeric constraint (NUM_GTE) ===\n")

    Benchee.run(%{
      "without precompute" => fn ->
        Constraint.verify_all([num_constraint_raw], context)
      end,
      "with precompute" => fn ->
        Constraint.verify_all([num_constraint_precomputed], context)
      end
    })

    IO.puts("\n=== Semver constraint (SEMVER_GT) ===\n")

    Benchee.run(%{
      "without precompute" => fn ->
        Constraint.verify_all([semver_constraint_raw], context)
      end,
      "with precompute" => fn ->
        Constraint.verify_all([semver_constraint_precomputed], context)
      end
    })

    IO.puts("\n=== Date constraint (DATE_AFTER) ===\n")

    Benchee.run(%{
      "without precompute" => fn ->
        Constraint.verify_all([date_constraint_raw], context)
      end,
      "with precompute" => fn ->
        Constraint.verify_all([date_constraint_precomputed], context)
      end
    })

    IO.puts("\n=== Mixed constraints (all three) ===\n")

    raw_all = [num_constraint_raw, semver_constraint_raw, date_constraint_raw]
    precomputed_all = [num_constraint_precomputed, semver_constraint_precomputed, date_constraint_precomputed]

    Benchee.run(%{
      "without precompute (3 constraints)" => fn ->
        Constraint.verify_all(raw_all, context)
      end,
      "with precompute (3 constraints)" => fn ->
        Constraint.verify_all(precomputed_all, context)
      end
    })
  end
end
