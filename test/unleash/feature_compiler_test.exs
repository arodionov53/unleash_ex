defmodule Unleash.FeatureCompilerTest do
  use ExUnit.Case, async: true

  alias Unleash.Feature
  alias Unleash.FeatureCompiler
  alias Unleash.Strategy
  alias Unleash.Strategy.Constraint

  describe "Constraint.compile_all/2" do
    test "empty constraints return true function" do
      compiled = Constraint.compile_all([], true)
      assert compiled.(%{}) == true
      assert compiled.(%{user_id: "test"}) == true
    end

    test "nil constraints return true function" do
      compiled = Constraint.compile_all(nil, true)
      assert compiled.(%{}) == true
    end

    test "compiled constraints produce same results as verify_all" do
      constraints = [
        %{
          "contextName" => "userId",
          "operator" => "IN",
          "values" => ["user1", "user2"],
          "inverted" => false
        }
      ]

      # Process constraints
      processed = Enum.map(constraints, &Constraint.from_map(&1, true))
      compiled = Constraint.compile_all(processed, true)

      context_match = %{user_id: "user1"}
      context_no_match = %{user_id: "user3"}

      assert compiled.(context_match) == Constraint.verify_all(processed, context_match)
      assert compiled.(context_no_match) == Constraint.verify_all(processed, context_no_match)
    end

    test "pre-computes Recase.to_snake conversion for camelCase names" do
      constraints = [
        %{
          "contextName" => "userId",
          "operator" => "IN",
          "values" => ["test_user"],
          "inverted" => false
        },
        %{
          "contextName" => "appName",
          "operator" => "IN",
          "values" => ["my_app"],
          "inverted" => false
        }
      ]

      processed = Enum.map(constraints, &Constraint.from_map(&1, true))
      compiled = Constraint.compile_all(processed, true)

      # Should work with snake_case context keys
      assert compiled.(%{user_id: "test_user", app_name: "my_app"}) == true
      assert compiled.(%{user_id: "other", app_name: "my_app"}) == false
    end

    test "handles inverted constraints" do
      constraints = [
        %{
          "contextName" => "userId",
          "operator" => "IN",
          "values" => ["blocked_user"],
          "inverted" => true
        }
      ]

      processed = Enum.map(constraints, &Constraint.from_map(&1, true))
      compiled = Constraint.compile_all(processed, true)

      # Inverted: user NOT in list should return true
      assert compiled.(%{user_id: "allowed_user"}) == true
      assert compiled.(%{user_id: "blocked_user"}) == false
    end

    test "handles missing context values" do
      constraints = [
        %{
          "contextName" => "userId",
          "operator" => "IN",
          "values" => ["user1"],
          "inverted" => false
        }
      ]

      processed = Enum.map(constraints, &Constraint.from_map(&1, true))
      compiled = Constraint.compile_all(processed, true)

      # Missing context value should return false
      assert compiled.(%{}) == false
      assert compiled.(%{other_field: "value"}) == false
    end

    test "handles properties fallback" do
      constraints = [
        %{
          "contextName" => "customField",
          "operator" => "IN",
          "values" => ["custom_value"],
          "inverted" => false
        }
      ]

      processed = Enum.map(constraints, &Constraint.from_map(&1, true))
      compiled = Constraint.compile_all(processed, true)

      # Should look in properties if not in top-level context
      context_with_properties = %{properties: %{custom_field: "custom_value"}}
      assert compiled.(context_with_properties) == true
    end

    test "multiple constraints use AND logic" do
      constraints = [
        %{
          "contextName" => "userId",
          "operator" => "IN",
          "values" => ["user1"],
          "inverted" => false
        },
        %{
          "contextName" => "appName",
          "operator" => "IN",
          "values" => ["app1"],
          "inverted" => false
        }
      ]

      processed = Enum.map(constraints, &Constraint.from_map(&1, true))
      compiled = Constraint.compile_all(processed, true)

      # Both must match
      assert compiled.(%{user_id: "user1", app_name: "app1"}) == true
      assert compiled.(%{user_id: "user1", app_name: "app2"}) == false
      assert compiled.(%{user_id: "user2", app_name: "app1"}) == false
    end

    test "handles various operators" do
      test_cases = [
        {%{"contextName" => "v", "operator" => "NUM_GT", "value" => "10", "inverted" => false},
         %{v: 15}, true},
        {%{"contextName" => "v", "operator" => "NUM_GT", "value" => "10", "inverted" => false},
         %{v: 5}, false},
        {%{
           "contextName" => "s",
           "operator" => "STR_CONTAINS",
           "values" => ["test"],
           "inverted" => false
         }, %{s: "this is a test"}, true},
        {%{
           "contextName" => "s",
           "operator" => "STR_CONTAINS",
           "values" => ["test"],
           "inverted" => false
         }, %{s: "no match"}, false}
      ]

      for {constraint, context, expected} <- test_cases do
        processed = [Constraint.from_map(constraint, true)]
        compiled = Constraint.compile_all(processed, true)
        assert compiled.(context) == expected, "Failed for #{inspect(constraint)}"
      end
    end
  end

  describe "Strategy module pre-resolution" do
    test "update_map adds __strategy_module__" do
      strategy_map = %{
        "name" => "default",
        "parameters" => %{},
        "constraints" => []
      }

      updated = Strategy.update_map(strategy_map)

      assert updated["__strategy_module__"] == Unleash.Strategy.Default
    end

    test "update_map adds __compiled_constraints__" do
      strategy_map = %{
        "name" => "default",
        "parameters" => %{},
        "constraints" => [
          %{
            "contextName" => "userId",
            "operator" => "IN",
            "values" => ["user1"],
            "inverted" => false
          }
        ]
      }

      updated = Strategy.update_map(strategy_map)

      assert is_function(updated["__compiled_constraints__"])
      assert updated["__compiled_constraints__"].(%{user_id: "user1"}) == true
      assert updated["__compiled_constraints__"].(%{user_id: "other"}) == false
    end

    test "Strategy.enabled? uses pre-resolved module" do
      strategy_map = %{
        "name" => "default",
        "parameters" => %{},
        "constraints" => []
      }

      updated = Strategy.update_map(strategy_map)

      # Should use pre-resolved module instead of Enum.find
      assert Strategy.enabled?(updated, %{}) == true
    end

    test "Strategy.enabled? uses compiled constraints" do
      strategy_map = %{
        "name" => "default",
        "parameters" => %{},
        "constraints" => [
          %{
            "contextName" => "userId",
            "operator" => "IN",
            "values" => ["allowed"],
            "inverted" => false
          }
        ]
      }

      updated = Strategy.update_map(strategy_map)

      assert Strategy.enabled?(updated, %{user_id: "allowed"}) == true
      assert Strategy.enabled?(updated, %{user_id: "blocked"}) == false
    end
  end

  describe "FeatureCompiler.compile_feature/1" do
    test "compiles feature with empty strategies" do
      feature = %{enabled: true, strategies: []}
      compiled = FeatureCompiler.compile_feature(feature)

      {result, evaluations} = compiled.(%{})
      assert result == true
      assert evaluations == []
    end

    test "compiles feature with single strategy" do
      strategy =
        Strategy.update_map(%{
          "name" => "default",
          "parameters" => %{},
          "constraints" => []
        })

      feature = %{enabled: true, strategies: [strategy]}
      compiled = FeatureCompiler.compile_feature(feature)

      {result, evaluations} = compiled.(%{})
      assert result == true
      assert evaluations == [{"default", true}]
    end

    test "compiles feature with multiple strategies (OR logic)" do
      strategy1 =
        Strategy.update_map(%{
          "name" => "userWithId",
          "parameters" => %{"userIds" => "user1,user2"},
          "constraints" => []
        })

      strategy2 =
        Strategy.update_map(%{
          "name" => "default",
          "parameters" => %{},
          "constraints" => []
        })

      feature = %{enabled: true, strategies: [strategy1, strategy2]}
      compiled = FeatureCompiler.compile_feature(feature)

      # Should return true because default strategy always returns true
      {result, evaluations} = compiled.(%{user_id: "other_user"})
      assert result == true
      assert length(evaluations) == 2
    end

    test "respects feature enabled flag" do
      strategy =
        Strategy.update_map(%{
          "name" => "default",
          "parameters" => %{},
          "constraints" => []
        })

      # Feature disabled
      feature_disabled = %{enabled: false, strategies: [strategy]}
      compiled_disabled = FeatureCompiler.compile_feature(feature_disabled)

      {result, _} = compiled_disabled.(%{})
      assert result == false

      # Feature enabled
      feature_enabled = %{enabled: true, strategies: [strategy]}
      compiled_enabled = FeatureCompiler.compile_feature(feature_enabled)

      {result, _} = compiled_enabled.(%{})
      assert result == true
    end

    test "compiled feature produces same results as Feature.enabled?" do
      feature_map = %{
        "name" => "test",
        "enabled" => true,
        "strategies" => [
          %{
            "name" => "flexibleRollout",
            "parameters" => %{"rollout" => 100, "stickiness" => "default", "groupId" => "test"},
            "constraints" => [
              %{
                "contextName" => "appName",
                "operator" => "IN",
                "values" => ["app1", "app2"],
                "inverted" => false
              }
            ]
          }
        ],
        "variants" => []
      }

      feature = Feature.from_map(feature_map)

      contexts = [
        %{app_name: "app1", user_id: "user1"},
        %{app_name: "app2", user_id: "user2"},
        %{app_name: "other", user_id: "user3"}
      ]

      for context <- contexts do
        # Feature.enabled? should use compiled version internally
        {result, _} = Feature.enabled?(feature, context)

        # Verify manually
        strategies = Enum.map(feature_map["strategies"], &Strategy.update_map/1)

        compiled =
          FeatureCompiler.compile_feature(%{
            enabled: feature_map["enabled"],
            strategies: strategies
          })

        {compiled_result, _} = compiled.(context)

        assert result == compiled_result,
               "Results differ for context #{inspect(context)}: enabled?=#{result}, compiled=#{compiled_result}"
      end
    end
  end

  describe "Feature.enabled? with compilation" do
    test "uses compiled function when available" do
      feature_map = %{
        "name" => "compiled-test",
        "enabled" => true,
        "strategies" => [
          %{
            "name" => "default",
            "parameters" => %{},
            "constraints" => []
          }
        ],
        "variants" => []
      }

      # from_map should add compiled function
      feature = Feature.from_map(feature_map)
      assert is_function(feature.__compiled_enabled__)

      {result, evaluations} = Feature.enabled?(feature, %{})
      assert result == true
      assert evaluations == [{"default", true}]
    end

    test "falls back to non-compiled path when __compiled_enabled__ is nil" do
      feature = %Feature{
        name: "test",
        enabled: true,
        strategies: [
          Strategy.update_map(%{
            "name" => "default",
            "parameters" => %{},
            "constraints" => []
          })
        ],
        __compiled_enabled__: nil
      }

      {result, _} = Feature.enabled?(feature, %{})
      assert result == true
    end
  end

  describe "compile_single_constraint/1" do
    test "handles invalid constraint gracefully" do
      compiled = Constraint.compile_single_constraint(%{})
      assert compiled.(%{}) == false
    end

    test "compiles constraint with all operators" do
      operators = [
        {"IN", %{"values" => ["a"]}, %{x: "a"}, true},
        {"NOT_IN", %{"values" => ["a"]}, %{x: "b"}, true},
        {"NUM_GT", %{"value" => "10"}, %{x: 15}, true},
        {"NUM_LTE", %{"value" => "10"}, %{x: 10}, true},
        {"STR_CONTAINS", %{"values" => ["test"]}, %{x: "testing"}, true},
        {"STR_STARTS_WITH", %{"values" => ["pre"]}, %{x: "prefix"}, true},
        {"STR_ENDS_WITH", %{"values" => ["fix"]}, %{x: "suffix"}, true}
      ]

      for {op, extra, context, expected} <- operators do
        constraint =
          Map.merge(
            %{"contextName" => "x", "operator" => op, "inverted" => false},
            extra
          )

        processed = Constraint.from_map(constraint, true)
        compiled = Constraint.compile_single_constraint(processed)
        assert compiled.(context) == expected, "Failed for operator #{op}"
      end
    end
  end
end
