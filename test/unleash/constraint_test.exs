defmodule Unleash.Strategy.ConstraintTest do
  use ExUnit.Case

  alias Unleash.Strategy.Constraint

  describe "IN and NOT_IN tests no compilation" do
    test "it returns true if there is no constraints" do
      assert true == Constraint.verify_all([], %{})
    end

    test "it returns false if there is no context" do
      assert false == Constraint.verify_all([mk_constraint(%{}, false)], %{})
    end

    test "IN positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "IN",
                       "values" => ["unleash"]
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end

    test "IN positive test inverted" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "IN",
                       "values" => ["unleash"],
                       "inverted" => true
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end

    test "NOT_IN negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "NOT_IN",
                       "values" => ["unleash"]
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end

    test "NOT_IN positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "NOT_IN",
                       "values" => ["not_unleash"]
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end
  end

  describe "IN and NOT_IN tests compiled" do
    test "it returns true if there is no constraints" do
      assert true == Constraint.verify_all([], %{})
    end

    test "it returns false if there is no context" do
      assert false == Constraint.verify_all([mk_constraint(%{}, true)], %{})
    end

    test "IN positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "IN",
                       "values" => ["unleash"]
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end

    test "IN positive test inverted" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "IN",
                       "values" => ["unleash"],
                       "inverted" => true
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end

    test "NOT_IN negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "NOT_IN",
                       "values" => ["unleash"]
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end

    test "NOT_IN positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "appName",
                       "operator" => "NOT_IN",
                       "values" => ["not_unleash"]
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash"}
               )
    end
  end

  describe "DATE_AFTER and DATE_BEFORE tests no compilation" do
    test "DATE_AFTER positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_AFTER",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-06-16T12:10:00.000Z"}
               )
    end

    test "DATE_AFTER positive test :now" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_AFTER",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: :now}
               )
    end

    test "DATE_AFTER negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_AFTER",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-04-16T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-04-16T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE negapositivetive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: "2024-05-15T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-05-15T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE negative test inverted" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z",
                       "inverted" => true
                     },
                     false
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-05-15T12:10:00.000Z"}
               )
    end
  end

  describe "DATE_AFTER and DATE_BEFORE tests compiled" do
    test "DATE_AFTER positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_AFTER",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-06-16T12:10:00.000Z"}
               )
    end

    test "DATE_AFTER positive test :now" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_AFTER",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: :now}
               )
    end

    test "DATE_AFTER negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_AFTER",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-04-16T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-04-16T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE negapositivetive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: "2024-05-15T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z"
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-05-15T12:10:00.000Z"}
               )
    end

    test "DATE_BEFORE negative test inverted" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "currentTime",
                       "operator" => "DATE_BEFORE",
                       "value" => "2025-05-15T12:10:00.000Z",
                       "inverted" => true
                     },
                     true
                   )
                 ],
                 %{app_name: "unleash", current_time: "2025-05-15T12:10:00.000Z"}
               )
    end
  end

  describe "STR_CONTAINS,  STR_STARTS_WITH and STR_ENDS_WITH tests no compilation" do
    test "STR_CONTAINS positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"]
                     },
                     false
                   )
                 ],
                 %{string_value: "unleash feature toggle"}
               )
    end

    test "STR_CONTAINS negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"]
                     },
                     false
                   )
                 ],
                 %{string_value: "unlEash feature toggle"}
               )
    end

    test "STR_CONTAINS negative test inverted" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"],
                       "inverted" => true
                     },
                     false
                   )
                 ],
                 %{string_value: "unlEash feature toggle"}
               )
    end

    test "STR_CONTAINS caseInsensitive negative test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "caseInsensitive" => true,
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"]
                     },
                     false
                   )
                 ],
                 %{string_value: "unlEash feature toggle"}
               )
    end

    test "STR_ENDS_WITH positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"]
                     },
                     false
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_ENDS_WITH negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"]
                     },
                     false
                   )
                 ],
                 %{string_value: "anyone@user.COM"}
               )
    end

    test "STR_ENDS_WITH caseInsensitive positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "caseInsensitive" => true,
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"]
                     },
                     false
                   )
                 ],
                 %{string_value: "anyone@user.COM"}
               )
    end

    test "STR_ENDS_WITH positive test inverted" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"],
                       "inverted" => true
                     },
                     false
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_STARTS_WITH positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"]
                     },
                     false
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_STARTS_WITH positive test inverted" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"],
                       "inverted" => true
                     },
                     false
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_STARTS_WITH negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"]
                     },
                     false
                   )
                 ],
                 %{string_value: "ANYone@user.com"}
               )
    end

    test "STR_STARTS_WITH caseInsensitive positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "caseInsensitive" => true,
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"]
                     },
                     false
                   )
                 ],
                 %{string_value: "ANYone@user.com"}
               )
    end
  end

  describe "STR_CONTAINS,  STR_STARTS_WITH and STR_ENDS_WITH tests compiled" do
    test "STR_CONTAINS positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"]
                     },
                     true
                   )
                 ],
                 %{string_value: "unleash feature toggle"}
               )
    end

    test "STR_CONTAINS negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"]
                     },
                     true
                   )
                 ],
                 %{string_value: "unlEash feature toggle"}
               )
    end

    test "STR_CONTAINS negative test inverted" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"],
                       "inverted" => true
                     },
                     true
                   )
                 ],
                 %{string_value: "unlEash feature toggle"}
               )
    end

    test "STR_CONTAINS caseInsensitive negative test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "caseInsensitive" => true,
                       "contextName" => "string_value",
                       "operator" => "STR_CONTAINS",
                       "values" => ["unleash", "elixir"]
                     },
                     true
                   )
                 ],
                 %{string_value: "unlEash feature toggle"}
               )
    end

    test "STR_ENDS_WITH positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"]
                     },
                     true
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_ENDS_WITH negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"]
                     },
                     true
                   )
                 ],
                 %{string_value: "anyone@user.COM"}
               )
    end

    test "STR_ENDS_WITH caseInsensitive positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "caseInsensitive" => true,
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"]
                     },
                     true
                   )
                 ],
                 %{string_value: "anyone@user.COM"}
               )
    end

    test "STR_ENDS_WITH positive test inverted" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_ENDS_WITH",
                       "values" => ["@unreal.com", "@user.com"],
                       "inverted" => true
                     },
                     true
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_STARTS_WITH positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"]
                     },
                     true
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_STARTS_WITH positive test inverted" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"],
                       "inverted" => true
                     },
                     true
                   )
                 ],
                 %{string_value: "anyone@user.com"}
               )
    end

    test "STR_STARTS_WITH negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"]
                     },
                     true
                   )
                 ],
                 %{string_value: "ANYone@user.com"}
               )
    end

    test "STR_STARTS_WITH caseInsensitive positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "caseInsensitive" => true,
                       "contextName" => "string_value",
                       "operator" => "STR_STARTS_WITH",
                       "values" => ["anyone", "someone"]
                     },
                     true
                   )
                 ],
                 %{string_value: "ANYone@user.com"}
               )
    end
  end

  describe "NUM_EQ, NUM_GT, NUM_GTE, NUM_LT and NUM_LTE tests no compilation" do
    test "NUM_EQ positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_EQ",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_EQ negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_EQ",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 120}
               )
    end

    test "NUM_NEQ negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_NEQ",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_NEQ positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_NEQ",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 120}
               )
    end

    test "NUM_GT positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GT",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 223}
               )
    end

    test "NUM_GT negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GT",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_GTE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GTE",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_GTE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GTE",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: "120"}
               )
    end

    test "NUM_LE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LE",
                       "value" => "223"
                     },
                     false
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_LE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LE",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: "123"}
               )
    end

    test "NUM_LTE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LTE",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_LTE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LTE",
                       "value" => "123"
                     },
                     false
                   )
                 ],
                 %{user_id: 223}
               )
    end
  end

  describe "NUM_EQ, NUM_GT, NUM_GTE, NUM_LT and NUM_LTE tests compiled" do
    test "NUM_EQ positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_EQ",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_EQ negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_EQ",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 120}
               )
    end

    test "NUM_NEQ negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_NEQ",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_NEQ positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_NEQ",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 120}
               )
    end

    test "NUM_GT positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GT",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 223}
               )
    end

    test "NUM_GT negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GT",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_GTE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GTE",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: "123"}
               )
    end

    test "NUM_GTE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_GTE",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 120}
               )
    end

    test "NUM_LE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LE",
                       "value" => "223"
                     },
                     true
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_LE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LE",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_LTE positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LTE",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 123}
               )
    end

    test "NUM_LTE negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "userId",
                       "operator" => "NUM_LTE",
                       "value" => "123"
                     },
                     true
                   )
                 ],
                 %{user_id: 223}
               )
    end
  end

  describe "SEMVER_EQ, SEMVER_GT and  SEMVER_LT tests no compilation" do
    test "SEMVER_EQ positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_EQ",
                       "value" => "1.2.3"
                     },
                     false
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_EQ negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_EQ",
                       "value" => "1.3.3"
                     },
                     false
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_GT negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_GT",
                       "value" => "1.2.3"
                     },
                     false
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_LT negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_LT",
                       "value" => "1.2.3"
                     },
                     false
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_GT positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_GT",
                       "value" => "1.2.3"
                     },
                     false
                   )
                 ],
                 %{sem_ver: "1.2.33-pre.2+build.4"}
               )
    end

    test "SEMVER_LT positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_LT",
                       "value" => "1.3.3"
                     },
                     false
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end
  end

  describe "SEMVER_EQ, SEMVER_GT and  SEMVER_LT tests compiled" do
    test "SEMVER_EQ positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_EQ",
                       "value" => "1.2.3"
                     },
                     true
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_EQ negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_EQ",
                       "value" => "1.3.3"
                     },
                     true
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_GT negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_GT",
                       "value" => "1.2.3"
                     },
                     true
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_LT negative test" do
      assert false ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_LT",
                       "value" => "1.2.3"
                     },
                     true
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end

    test "SEMVER_GT positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_GT",
                       "value" => "1.2.3"
                     },
                     true
                   )
                 ],
                 %{sem_ver: "1.2.33-pre.2+build.4"}
               )
    end

    test "SEMVER_LT positive test" do
      assert true ==
               Constraint.verify_all(
                 [
                   mk_constraint(
                     %{
                       "contextName" => "semVer",
                       "operator" => "SEMVER_LT",
                       "value" => "1.3.3"
                     },
                     true
                   )
                 ],
                 %{sem_ver: "1.2.3-pre.2+build.4"}
               )
    end
  end

  describe "Help functions tests" do
    test "to_number converts to integer" do
      assert 123 == Constraint.to_number("123")
    end

    test "to_number converts to float" do
      assert 123.45 == Constraint.to_number("123.45")
    end

    test "to_number converts to float when zero " do
      assert 123.0 == Constraint.to_number("123.0")
    end

    test "to_number converts to float in incorrect case" do
      assert 123.0 == Constraint.to_number("123.o")
    end

    test "to_number fails to convert" do
      assert :error == Constraint.to_number("Q123.45")
    end

    test "two to_number converts to float in incorrect case" do
      assert {123.0, 17} == Constraint.to_numbers("123.o", 17)
    end

    test "two to_number incorrect case" do
      assert :error == Constraint.to_numbers("x123.o", 17)
    end

    test "mk_semver string argument" do
      assert {1, 2, 3} == Constraint.mk_semver("1.2.3-pre.2+build.4")
    end

    test "mk_semver tuple argument" do
      assert {1, 2, 3} == Constraint.mk_semver({1, 2, 3, 4, 5, 6, 7})
    end

    test "mk_semver short tuple argument" do
      assert {1, 2, 0} == Constraint.mk_semver({1, 2})
    end

    test "cmp_semver equal" do
      assert true == Constraint.cmp_semver("1.2.3", "1.2.3-pre.2+build.4", &Kernel.==/2)
    end

    test "cmp_semver equal negative" do
      assert false == Constraint.cmp_semver("1.2.3", "1.2.33-pre.2+build.4", &Kernel.==/2)
    end

    test "cmp_semver greater" do
      assert true == Constraint.cmp_semver("1.3.3", "1.2.3-pre.2+build.4", &Kernel.>/2)
    end

    test "cmp_semver less" do
      assert false == Constraint.cmp_semver("1.3.3", "1.2.33-pre.2+build.4", &Kernel.</2)
    end

    test "cmp_semver equal with tuple" do
      assert true == Constraint.cmp_semver([1, 2, 3], "1.2.3-pre.2+build.4", &Kernel.==/2)
    end
  end

  defp mk_constraint(map, do_compilation) do
    %{
      "caseInsensitive" => Map.get(map, "caseInsensitive", false),
      "contextName" => Map.get(map, "contextName", ""),
      "inverted" => Map.get(map, "inverted", false),
      "operator" => Map.get(map, "operator", ""),
      "value" => Map.get(map, "value", ""),
      "values" => Map.get(map, "values", [])
    }
    |> Constraint.from_map(do_compilation)
  end
end
