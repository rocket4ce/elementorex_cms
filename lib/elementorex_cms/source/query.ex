defmodule ElementorexCms.Source.Query do
  @moduledoc """
  What a loop asks a source for (`c:ElementorexCms.Source.list/2`):

    * `limit` and `offset`
    * `order_by` - the key of a sortable field (`nil`: the source's own order)
      and `order` - `:asc` or `:desc`
    * `filters` - `%{field: key, op: op, value: value}` maps, all of which must
      match. `op` is one of `"eq"`, `"neq"`, `"contains"`, `"gt"`, `"gte"`,
      `"lt"`, `"lte"`, `"set"` (has a value) or `"unset"`; `value` is the text
      typed in the editor or by a visitor (cast it to the type of the field).
      Visitors' filters also use `"in"` (`value` is a list: any of them) and
      `"custom"` (a filter of the source with logic of its own, see
      `ElementorexCms.Source.Field`)
    * `search` - `nil` or `%{text: text, fields: keys}`: records with the text
      in any of those fields (the search box of the visitors' filters)
    * `exclude` - ids (`c:ElementorexCms.Source.id/1`) to leave out, e.g. the
      item a page is about, in a list of related items

  Sources backed by a database turn it into a query (see
  `ElementorexCms.Source.Ecto`); sources that keep their items in a list can
  use `run/3`.
  """

  @ops ~w(eq neq contains gt gte lt lte set unset)

  defstruct limit: 12,
            offset: 0,
            order_by: nil,
            order: :asc,
            filters: [],
            search: nil,
            exclude: []

  @type t :: %__MODULE__{
          limit: pos_integer(),
          offset: non_neg_integer(),
          order_by: String.t() | nil,
          order: :asc | :desc,
          filters: [%{field: String.t(), op: String.t(), value: String.t() | [String.t()]}],
          search: %{text: String.t(), fields: [String.t()]} | nil,
          exclude: [String.t()]
        }

  @doc "Operators a designer chooses from (visitors' filters also send `\"in\"` and `\"custom\"`)."
  @spec ops() :: [String.t()]
  def ops, do: @ops

  @doc """
  Applies the query to records kept in memory: filters, search, `exclude`,
  order and page. `value` reads a field of a record (`fn record, key -> ...
  end`) and `id` its id (default: the `"id"`/`:id` key). `"custom"` filters are
  left to the source: apply them to the records before.

      def list(query, _context) do
        Query.run(query, MyApp.Team.members(), &Map.get(&1, String.to_existing_atom(&2)))
      end
  """
  @spec run(t(), [term()], (term(), String.t() -> term()), (term() -> term()) | nil) :: [term()]
  def run(%__MODULE__{} = query, records, value, id \\ nil) do
    query
    |> matching(records, value, id)
    |> sort(query, value)
    |> Enum.drop(query.offset)
    |> Enum.take(query.limit)
  end

  @doc """
  How many records kept in memory match the filters and `exclude` of the query,
  its limit and offset aside: what `c:ElementorexCms.Source.count/2` returns
  (a loop with numbered pages needs it).

      def count(query, _context) do
        Query.count(query, MyApp.Team.members(), &Map.get(&1, String.to_existing_atom(&2)))
      end
  """
  @spec count(t(), [term()], (term(), String.t() -> term()), (term() -> term()) | nil) ::
          non_neg_integer()
  def count(%__MODULE__{} = query, records, value, id \\ nil) do
    query |> matching(records, value, id) |> length()
  end

  defp matching(query, records, value, id) do
    id = id || (&default_id/1)
    exclude = MapSet.new(query.exclude, &to_string/1)

    records
    |> Enum.filter(fn record -> Enum.all?(query.filters, &matches?(record, &1, value)) end)
    |> Enum.filter(&found?(&1, query.search, value))
    |> Enum.reject(&MapSet.member?(exclude, to_string(id.(&1))))
  end

  defp found?(_record, nil, _value), do: true

  defp found?(record, %{text: text, fields: fields}, value) do
    text = String.downcase(String.trim(text))
    text == "" or Enum.any?(fields, &String.contains?(text(value.(record, &1)), text))
  end

  @doc """
  The distinct values of a field among records kept in memory, with how many
  records have each, in order: what `c:ElementorexCms.Source.values/2` returns
  (the options of a filter).

      iex> records = [%{c: "b"}, %{c: "a"}, %{c: "b"}, %{c: nil}]
      iex> ElementorexCms.Source.Query.values(records, "c", &Map.get(&1, String.to_existing_atom(&2)))
      [{"a", 1}, {"b", 2}]
  """
  @spec values([term()], String.t(), (term(), String.t() -> term())) :: [{term(), pos_integer()}]
  def values(records, key, value) do
    records
    |> Enum.map(&value.(&1, key))
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {value, _count} -> sortable(value) end)
  end

  defp default_id(record) when is_map(record), do: Map.get(record, :id) || Map.get(record, "id")
  defp default_id(_record), do: nil

  defp sort(records, %{order_by: nil}, _value), do: records

  # Numbers before text and empty values last, in both directions.
  defp sort(records, %{order_by: key, order: order}, value) do
    Enum.sort_by(records, &sortable(value.(&1, key)), fn {group_a, a}, {group_b, b} ->
      cond do
        group_a != group_b -> group_a < group_b
        order == :desc -> a >= b
        true -> a <= b
      end
    end)
  end

  defp sortable(nil), do: {2, nil}
  defp sortable(value) when is_number(value), do: {0, value}
  defp sortable(%{__struct__: Decimal} = value), do: {0, to_float(value)}
  defp sortable(%Date{} = value), do: {1, Date.to_iso8601(value)}
  defp sortable(%DateTime{} = value), do: {1, DateTime.to_iso8601(value)}
  defp sortable(%NaiveDateTime{} = value), do: {1, NaiveDateTime.to_iso8601(value)}
  defp sortable(value), do: {1, text(value)}

  defp matches?(record, %{field: key, op: op, value: expected}, value) do
    match_value?(value.(record, key), op, expected)
  end

  @doc """
  Whether a value matches a filter operator and the expected text: what
  `run/4` checks for each filter. Numbers compare as numbers, the rest as
  text without case.

      iex> ElementorexCms.Source.Query.match_value?(0, "lte", "0")
      true
      iex> ElementorexCms.Source.Query.match_value?("Shoes", "eq", "shoes")
      true
  """
  @spec match_value?(term(), String.t(), term()) :: boolean()
  def match_value?(actual, op, expected) do
    case op do
      "set" -> actual not in [nil, "", []]
      "unset" -> actual in [nil, "", []]
      "contains" -> String.contains?(text(actual), String.downcase(to_string(expected)))
      "eq" -> equal?(actual, expected)
      "neq" -> not equal?(actual, expected)
      "in" -> expected |> List.wrap() |> Enum.any?(&equal?(actual, &1))
      op when op in ~w(gt gte lt lte) -> ordered?(actual, op, expected)
      # The source's own filters: applied by the source, not here
      "custom" -> true
      _ -> false
    end
  end

  defp equal?(actual, expected) do
    case {number(actual), number(expected)} do
      {a, b} when is_number(a) and is_number(b) -> a == b
      _ -> text(actual) == String.downcase(String.trim(to_string(expected)))
    end
  end

  defp ordered?(actual, op, expected) do
    {a, b} =
      case {number(actual), number(expected)} do
        {a, b} when is_number(a) and is_number(b) -> {a, b}
        _ -> {text(actual), String.downcase(String.trim(to_string(expected)))}
      end

    case op do
      "gt" -> a > b
      "gte" -> a >= b
      "lt" -> a < b
      "lte" -> a <= b
    end
  end

  defp number(value) when is_number(value), do: value
  defp number(%{__struct__: Decimal} = value), do: to_float(value)

  defp number(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp number(_value), do: nil

  defp to_float(decimal) do
    {number, _} = decimal |> to_string() |> Float.parse()
    number
  end

  defp text(nil), do: ""
  defp text(value) when is_binary(value), do: String.downcase(value)

  defp text(value) do
    if String.Chars.impl_for(value), do: value |> to_string() |> String.downcase(), else: ""
  end
end
