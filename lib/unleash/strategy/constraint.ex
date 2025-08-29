defmodule Unleash.Strategy.Constraint do
  @moduledoc """
  Module that is used to verify
  [constraints](https://www.unleash-hosted.com/docs/strategy-constraints/) are
  met.

  These constraints allow for very complex and specifc strategies to be
  enacted by allowing users to specify context values to include or exclude.
  """
  alias Unleash.Config

  def from_map(map), do: from_map(map, Config.constraint_precompilation())

  def from_map(map, true), do: op_compile(map)
  def from_map(map, _), do: map

  def verify_all(constraints, context) do
    Enum.all?(constraints, &verify(&1, context))
  end

  defp verify(
         %{"contextName" => name, "operator" => op, "inverted" => inverted} = constraint,
         context
       ) do
    context
    |> find_value(name)
    |> check(op, constraint)
    |> invert(inverted)
  end

  defp verify(%{}, _context), do: false

  defp find_value(nil, _name), do: nil

  defp find_value(ctx, name) do
    Map.get(
      ctx,
      String.to_atom(Recase.to_snake(name)),
      find_value(Map.get(ctx, :properties), name)
    )
  end

  defp invert(result, true), do: !result
  defp invert(result, _), do: result

  # ---------------------------------------------------------------------------------------------
  # Runtime constarint checks
  # ---------------------------------------------------------------------------------------------

  def check(nil, _, _), do: false

  def check(value, f, _) when is_function(f), do: f.(value)

  def check(value, "IN", %{"values" => values}), do: value in values
  def check(value, "NOT_IN", %{"values" => values}), do: value not in values

  def check(daytime, "DATE_AFTER", %{"value" => value}),
    do: daytime |> compare_dates(value) == :gt

  def check(daytime, "DATE_BEFORE", %{"value" => value}),
    do: daytime |> compare_dates(value) == :lt

  def check(str, "STR_CONTAINS", %{"values" => values, "caseInsensitive" => true}),
    do: str |> String.downcase() |> String.contains?(values |> Enum.map(&String.downcase/1))

  def check(str, "STR_CONTAINS", %{"values" => values}),
    do: str |> String.contains?(values)

  def check(str, "STR_STARTS_WITH", %{"values" => values, "caseInsensitive" => true}),
    do: str |> String.downcase() |> String.starts_with?(values |> Enum.map(&String.downcase/1))

  def check(str, "STR_STARTS_WITH", %{"values" => values}),
    do: str |> String.starts_with?(values)

  def check(str, "STR_ENDS_WITH", %{"values" => values, "caseInsensitive" => true}),
    do: str |> String.downcase() |> String.ends_with?(values |> Enum.map(&String.downcase/1))

  def check(str, "STR_ENDS_WITH", %{"values" => values}),
    do: str |> String.ends_with?(values)

  def check(numb, "NUM_EQ", %{"value" => value}) do
    case to_numbers(numb, value) do
      :error -> false
      {n, m} -> n == m
    end
  end

  def check(numb, "NUM_NEQ", %{"value" => value}) do
    case to_numbers(numb, value) do
      :error -> false
      {n, m} -> n != m
    end
  end

  def check(numb, "NUM_GT", %{"value" => value}) do
    case to_numbers(numb, value) do
      :error -> false
      {n, m} -> n > m
    end
  end

  def check(numb, "NUM_GTE", %{"value" => value}) do
    case to_numbers(numb, value) do
      :error -> false
      {n, m} -> n >= m
    end
  end

  def check(numb, "NUM_LE", %{"value" => value}) do
    case to_numbers(numb, value) do
      :error -> false
      {n, m} -> n < m
    end
  end

  def check(numb, "NUM_LTE", %{"value" => value}) do
    case to_numbers(numb, value) do
      :error -> false
      {n, m} -> n <= m
    end
  end

  def check(semver, "SEMVER_EQ", %{"value" => value}), do: cmp_semver(semver, value, &Kernel.==/2)
  def check(semver, "SEMVER_GT", %{"value" => value}), do: cmp_semver(semver, value, &Kernel.>/2)
  def check(semver, "SEMVER_LT", %{"value" => value}), do: cmp_semver(semver, value, &Kernel.</2)

  # ---------------------------------------------------------------------------------------------
  # Constraint compilation
  # ---------------------------------------------------------------------------------------------

  def op_compile(map) do
    {_, new_map} =
      Map.get_and_update(map, "operator", fn op ->
        {op, op_comp(op, map)}
      end)

    new_map
  end

  defp op_comp("IN", %{"values" => values}), do: fn x -> x in values end
  defp op_comp("NOT_IN", %{"values" => values}), do: fn x -> x not in values end

  defp op_comp("DATE_AFTER", %{"value" => value}) do
    dt = day_adapter(value)
    fn daytime -> daytime |> day_adapter |> day_cpm(dt) == :gt end
  end

  defp op_comp("DATE_BEFORE", %{"value" => value}) do
    dt = day_adapter(value)
    fn daytime -> daytime |> day_adapter |> day_cpm(dt) == :lt end
  end

  defp op_comp("STR_CONTAINS", %{"values" => values, "caseInsensitive" => true}) do
    pat = :binary.compile_pattern(values |> Enum.map(&String.downcase/1))
    fn str -> str |> String.downcase() |> String.contains?(pat) end
  end

  defp op_comp("STR_CONTAINS", %{"values" => values}) do
    pat = :binary.compile_pattern(values)
    fn str -> str |> String.contains?(pat) end
  end

  defp op_comp("STR_STARTS_WITH", %{"values" => values, "caseInsensitive" => true}) do
    pat = values |> Enum.map(&String.downcase/1)
    fn str -> str |> String.downcase() |> String.starts_with?(pat) end
  end

  defp op_comp("STR_STARTS_WITH", %{"values" => values}) do
    fn str -> str |> String.starts_with?(values) end
  end

  defp op_comp("STR_ENDS_WITH", %{"values" => values, "caseInsensitive" => true}) do
    pat = values |> Enum.map(&String.downcase/1)
    fn str -> str |> String.downcase() |> String.ends_with?(pat) end
  end

  defp op_comp("STR_ENDS_WITH", %{"values" => values}) do
    fn str -> str |> String.ends_with?(values) end
  end

  defp op_comp("NUM_EQ", %{"value" => value}) do
    y = to_number(value)
    fn x -> x == y end
  end

  defp op_comp("NUM_NEQ", %{"value" => value}) do
    y = to_number(value)
    fn x -> x != y end
  end

  defp op_comp("NUM_GT", %{"value" => value}) do
    y = to_number(value)
    fn x -> x > y end
  end

  defp op_comp("NUM_GTE", %{"value" => value}) do
    y = to_number(value)
    fn x -> x >= y end
  end

  defp op_comp("NUM_LE", %{"value" => value}) do
    y = to_number(value)
    fn x -> x < y end
  end

  defp op_comp("NUM_LTE", %{"value" => value}) do
    y = to_number(value)
    fn x -> x <= y end
  end

  defp op_comp("SEMVER_EQ", %{"value" => value}) do
    v2 = mk_semver(value)
    fn v1 -> mk_semver(v1) == v2 end
  end

  defp op_comp("SEMVER_GT", %{"value" => value}) do
    v2 = mk_semver(value)
    fn v1 -> mk_semver(v1) > v2 end
  end

  defp op_comp("SEMVER_LT", %{"value" => value}) do
    v2 = mk_semver(value)
    fn v1 -> mk_semver(v1) < v2 end
  end

  defp op_comp(op, _), do: op

  # ---------------------------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------------------------

  defp compare_dates(d1, d2), do: day_adapter(d1) |> day_cpm(day_adapter(d2))

  defp day_adapter(:now), do: {:ok, DateTime.utc_now(), 0}

  defp day_adapter(day) when is_binary(day) do
    DateTime.from_iso8601(day)
  end

  defp day_adapter(_), do: {:error, "Invalid Date"}

  defp day_cpm({:ok, date1, _}, {:ok, date2, _}), do: date1 |> DateTime.compare(date2)
  defp day_cpm(_, _), do: :error

  def to_numbers(a, b) do
    case to_number(a) do
      :error ->
        :error

      n ->
        case to_number(b) do
          :error -> :error
          m -> {n, m}
        end
    end
  end

  def to_number(str) when is_binary(str) do
    case Integer.parse(str, 10) do
      {int, ""} -> int
      {_, _} -> to_real(str)
      _ -> :error
    end
  end

  def to_number(num) when is_number(num), do: num
  def to_number(_), do: :error

  defp to_real(str) when is_binary(str) do
    case Float.parse(str) do
      {float, _} -> float
      _ -> :error
    end
  end

  def mk_semver(version) when is_binary(version) do
    l = for x <- String.split(version, "."), do: Integer.parse(x, 10)
    mk_semver(for y <- l, do: elem(y, 0))
  end

  def mk_semver(version) when is_list(version), do: mk_semver(List.to_tuple(version))

  def mk_semver({a}), do: {a, 0, 0}
  def mk_semver({a, b}), do: {a, b, 0}
  def mk_semver({a, b, c}), do: {a, b, c}

  def mk_semver(version) when is_tuple(version),
    do: {elem(version, 0), elem(version, 1), elem(version, 2)}

  def cmp_semver(v1, v2, pred), do: pred.(mk_semver(v1), mk_semver(v2))
end
