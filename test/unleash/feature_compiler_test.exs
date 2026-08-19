defmodule Unleash.FeatureCompilerTest do
  use ExUnit.Case, async: true

  alias Unleash.Feature
  alias Unleash.FeatureCompiler

  setup do
    # Clean up persistent_term keys after each test
    on_exit(fn ->
      for name <- :persistent_term.get(:unleash_compiled_names, []) do
        :persistent_term.erase({:unleash_compiled, name})
      end

      :persistent_term.erase(:unleash_compiled_names)
    end)

    :ok
  end

  describe "compile_all/1" do
    test "compiles a disabled feature into a closure that returns false" do
      feature = %Feature{name: "disabled_feat", enabled: false}
      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("disabled_feat")
      assert compiled.enabled == false
      assert compiled.eval.(%{}) == false
    end

    test "compiles an enabled feature with no strategies to return true" do
      feature = %Feature{name: "always_on", enabled: true, strategies: []}
      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("always_on")
      assert compiled.enabled == true
      assert compiled.eval.(%{}) == true
    end

    test "compiles a feature with default strategy" do
      feature = %Feature{
        name: "with_default",
        enabled: true,
        strategies: [
          %{"name" => "default", "parameters" => %{}, "constraints" => []}
        ]
      }

      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("with_default")
      assert compiled.eval.(%{}) == true
    end

    test "compiles a feature with userWithId strategy" do
      feature = %Feature{
        name: "user_check",
        enabled: true,
        strategies: [
          %{
            "name" => "userWithId",
            "parameters" => %{"userIds" => "1,2,3"},
            "constraints" => []
          }
        ]
      }

      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("user_check")
      assert compiled.eval.(%{user_id: "2"}) == true
      assert compiled.eval.(%{user_id: "99"}) == false
    end

    test "compiles a feature with NUM_LTE constraint" do
      feature = %Feature{
        name: "num_constrained",
        enabled: true,
        strategies: [
          %{
            "name" => "default",
            "parameters" => %{},
            "constraints" => [
              %{
                "contextName" => "userId",
                "operator" => "NUM_LTE",
                "value" => "100",
                "values" => [],
                "inverted" => false,
                "caseInsensitive" => false
              }
            ]
          }
        ]
      }

      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("num_constrained")
      # user_id 50 <= 100 → passes constraint → default strategy → true
      assert compiled.eval.(%{user_id: "50"}) == true
      # user_id 200 > 100 → fails constraint → false
      assert compiled.eval.(%{user_id: "200"}) == false
    end

    test "precomputes NUM constraint values (no string parsing at eval time)" do
      feature = %Feature{
        name: "precomputed_num",
        enabled: true,
        strategies: [
          %{
            "name" => "default",
            "parameters" => %{},
            "constraints" => [
              %{
                "contextName" => "userId",
                "operator" => "NUM_GT",
                "value" => "42",
                "values" => [],
                "inverted" => false,
                "caseInsensitive" => false
              }
            ]
          }
        ]
      }

      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("precomputed_num")
      assert compiled.eval.(%{user_id: "100"}) == true
      assert compiled.eval.(%{user_id: "10"}) == false
    end

    test "handles IN constraint" do
      feature = %Feature{
        name: "in_constrained",
        enabled: true,
        strategies: [
          %{
            "name" => "default",
            "parameters" => %{},
            "constraints" => [
              %{
                "contextName" => "userId",
                "operator" => "IN",
                "value" => "",
                "values" => ["alice", "bob"],
                "inverted" => false,
                "caseInsensitive" => false
              }
            ]
          }
        ]
      }

      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("in_constrained")
      assert compiled.eval.(%{user_id: "alice"}) == true
      assert compiled.eval.(%{user_id: "charlie"}) == false
    end

    test "stores feature struct for variant access" do
      feature = %Feature{name: "with_variants", enabled: true, strategies: []}
      FeatureCompiler.compile_all([feature])

      compiled = FeatureCompiler.get("with_variants")
      assert compiled.feature == feature
    end
  end

  describe "get/1" do
    test "returns nil for unknown features" do
      assert FeatureCompiler.get("nonexistent") == nil
    end

    test "accepts atom names" do
      feature = %Feature{name: "atom_test", enabled: true, strategies: []}
      FeatureCompiler.compile_all([feature])

      assert FeatureCompiler.get(:atom_test) != nil
    end
  end

  describe "cleanup/1" do
    test "removes stale compiled entries" do
      features = [
        %Feature{name: "keep", enabled: true, strategies: []},
        %Feature{name: "remove_me", enabled: true, strategies: []}
      ]

      FeatureCompiler.compile_all(features)
      assert FeatureCompiler.get("remove_me") != nil

      # Now only "keep" exists
      FeatureCompiler.cleanup([%Feature{name: "keep", enabled: true}])
      assert FeatureCompiler.get("remove_me") == nil
      assert FeatureCompiler.get("keep") != nil
    end
  end
end
