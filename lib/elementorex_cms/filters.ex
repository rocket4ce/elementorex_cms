defmodule ElementorexCms.Filters do
  @moduledoc """
  Visitors' search and filters of loop grids.

  A loop keeps its state in the query string of the page, under its key (its
  CSS ID, or its node id): page, text search, order and one entry per filtered
  field.

      ?catalog[q]=boots&catalog[category][]=Shoes&catalog[price][min]=20000&catalog[sort]=-price&catalog[page]=2

  | Param | Filter |
  | --- | --- |
  | `key[page]` | the page (see the pagination of `ElementorexCms.Blocks.Loop`) |
  | `key[q]` | text in any searchable field (`ElementorexCms.Source.searchable/1`) |
  | `key[sort]` | `field` (ascending) or `-field` (descending), a sortable field |
  | `key[field]=value` | the field is the value |
  | `key[field][]=a&key[field][]=b` | the field is any of them |
  | `key[field][min]`, `key[field][max]`, `key[field]=min..max` | a range |
  | `key[filter]=value` | a filter of the source with logic of its own (`custom: true`) |

  Only fields the source marks `filterable` (and `sortable`, to order) are
  used, and values are cast to the type of the field, so the query string can
  never reach other columns. Empty values are ignored. The loop's own query
  (its filters, the scope of the source) always applies too.

  The *Filters* block (`ElementorexCms.Blocks.Filters`) is a form with these
  params: its fields (search, choices, range, toggle, sort) are blocks too,
  and so can yours be. Inside a filter form, a block reads its form with
  `name/2`, `value/2`, `checked?/3` and `options/2`, imported in every block:

      <input type="checkbox" name={filter_name(assigns, [@field, ""])} value="red"
             checked={filter_checked?(assigns, @field, "red")} />

  Without JavaScript the form reloads the page; with the runtime of the site
  (`ElementorexRuntime` / `initElementorex()`) the loop is filtered in place.
  """

  alias ElementorexCms.Dynamic
  alias ElementorexCms.Source
  alias ElementorexCms.Source.Field
  alias ElementorexCms.Source.Query
  alias ElementorexCms.Sources

  @reserved ~w(page q sort)
  @ranged [:integer, :number, :date, :datetime]

  ## The state of a loop

  @doc "The key of a loop in the query string: its CSS ID, or its node id."
  @spec key(map()) :: String.t()
  def key(%{"id" => id} = loop), do: get_in(loop, ["attrs", "id"]) || id

  @doc "The state of the loop with `key` in `params` (a map, empty if none)."
  @spec state(map(), String.t()) :: map()
  def state(params, key) do
    case params do
      %{^key => %{} = state} -> state
      _ -> %{}
    end
  end

  @doc "Whether the visitor filtered (or searched) the loop."
  @spec active?(map()) :: boolean()
  def active?(state) do
    Enum.any?(state, fn {name, value} -> name not in ["page", "sort"] and present?(value) end)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(values) when is_list(values), do: Enum.any?(values, &present?/1)
  defp present?(%{} = value), do: Enum.any?(Map.values(value), &present?/1)
  defp present?(_value), do: false

  @doc """
  The query of a loop with the visitor's state applied: its filters, search
  and order, validated against the fields of `source`.
  """
  @spec apply(Query.t(), map(), Source.t()) :: Query.t()
  def apply(%Query{} = query, state, %Source{} = source) when map_size(state) > 0 do
    fields = Map.new(Source.filter_fields(source), &{&1.key, &1})

    filters =
      for {name, value} <- state,
          name not in @reserved,
          field = fields[name],
          filter <- filters(field, value),
          do: filter

    {order_by, order} = sort(state["sort"], source) || {query.order_by, query.order}

    %{
      query
      | filters: query.filters ++ filters,
        search: search(state["q"], source) || query.search,
        order_by: order_by,
        order: order
    }
  end

  def apply(%Query{} = query, _state, _source), do: query

  defp filters(%Field{custom: true, key: key}, value) do
    case clean(value) do
      nil -> []
      value -> [%{field: key, op: "custom", value: value}]
    end
  end

  defp filters(%Field{key: key} = field, value) do
    case clean(value) do
      nil ->
        []

      values when is_list(values) ->
        [%{field: key, op: "in", value: values}]

      %{} = range ->
        range(key, range["min"], range["max"])

      value ->
        case field.type in @ranged and String.split(value, "..", parts: 2) do
          [min, max] -> range(key, min, max)
          _ -> [%{field: key, op: "eq", value: value}]
        end
    end
  end

  defp range(key, min, max) do
    [{"gte", min}, {"lte", max}]
    |> Enum.flat_map(fn {op, value} ->
      case clean(value) do
        value when is_binary(value) -> [%{field: key, op: op, value: value}]
        _ -> []
      end
    end)
  end

  # Trimmed values without the empty ones; nil when nothing is left.
  defp clean(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> String.slice(value, 0, 200)
    end
  end

  defp clean(values) when is_list(values) do
    case values |> Enum.map(&clean/1) |> Enum.filter(&is_binary/1) |> Enum.take(20) do
      [] -> nil
      values -> values
    end
  end

  defp clean(%{} = range) do
    range = Map.take(range, ["min", "max"])
    if present?(range), do: range
  end

  defp clean(_value), do: nil

  defp search(text, source) when is_binary(text) do
    case clean(text) do
      nil -> nil
      text -> %{text: text, fields: Source.searchable(source)}
    end
  end

  defp search(_text, _source), do: nil

  # "price" ascending, "-price" descending; only sortable fields.
  defp sort(value, source) when is_binary(value) do
    {key, order} =
      case String.trim(value) do
        "-" <> key -> {key, :desc}
        key -> {key, :asc}
      end

    if Enum.any?(source.fields, &(&1.key == key and &1.sortable)), do: {key, order}
  end

  defp sort(_value, _source), do: nil

  ## Links

  @doc """
  A query string (`"?catalog[page]=2"`) for the loop with `key`: `changes` are
  put in its state (`nil` removes an entry; `:reset` clears it). The state of
  the other loops of the page is kept; other params are not.
  """
  @spec href(map(), String.t(), map() | :reset) :: String.t()
  def href(params, key, changes) do
    loops = for {name, %{} = state} <- params, into: %{}, do: {name, state}

    state =
      case changes do
        :reset ->
          %{}

        changes ->
          Enum.reduce(changes, Map.get(loops, key, %{}), fn
            {name, nil}, state -> Map.delete(state, name)
            {name, value}, state -> Map.put(state, name, value)
          end)
      end

    loops = if state == %{}, do: Map.delete(loops, key), else: Map.put(loops, key, state)
    "?" <> (loops |> prune() |> Plug.Conn.Query.encode())
  end

  # Without empty values: `?catalog[q]=` says nothing.
  defp prune(%{} = map) do
    map
    |> Enum.flat_map(fn {key, value} ->
      case prune(value) do
        empty when empty in ["", [], %{}] -> []
        value -> [{key, value}]
      end
    end)
    |> Map.new()
  end

  defp prune(values) when is_list(values), do: Enum.reject(values, &(&1 == ""))
  defp prune(value), do: value

  @doc """
  The params of the other loops of the page as hidden inputs (`{name, value}`),
  so a filter form of one loop keeps the state of the others.
  """
  @spec hidden_inputs(map(), String.t()) :: [{String.t(), String.t()}]
  def hidden_inputs(params, key) do
    params
    |> Enum.filter(fn {name, value} -> name != key and is_map(value) end)
    |> Map.new()
    |> prune()
    |> flatten()
  end

  defp flatten(map, prefix \\ nil) do
    Enum.flat_map(map, fn {name, value} ->
      name = if prefix, do: "#{prefix}[#{name}]", else: name

      case value do
        %{} = nested -> flatten(nested, name)
        values when is_list(values) -> Enum.map(values, &{name <> "[]", &1})
        value -> [{name, value}]
      end
    end)
  end

  ## Filter forms

  @doc """
  The loop grid a filter form filters: the loop with node id `target` in the
  document, or its first one when `target` is empty. Only loops that are in no
  other loop take filters. `%{node: loop, key: key, source: source}` or `nil`.
  """
  @spec target(map(), String.t() | nil) :: map() | nil
  def target(%{doc: %{} = doc} = ctx, target) do
    loops = loops(doc, ctx.registry)

    loop =
      if target in [nil, ""], do: List.first(loops), else: Enum.find(loops, &(&1["id"] == target))

    loop &&
      %{
        node: loop,
        key: key(loop),
        source: Sources.fetch(ctx.sources, get_in(loop, ["props", "source"]))
      }
  end

  def target(_ctx, _target), do: nil

  @doc "The loop grids of a document that can be filtered (in no other loop)."
  @spec loops(map(), ElementorexCms.Registry.t() | nil) :: [map()]
  def loops(%{"root" => root}, registry), do: top_loops(root, registry)

  defp top_loops(node, registry) do
    if Dynamic.loop?(node, registry),
      do: [node],
      else: Enum.flat_map(node["children"] || [], &top_loops(&1, registry))
  end

  @doc """
  What the fields of a filter form get in `ctx.form`: the loop's key, its
  state, its source and its node id.
  """
  @spec form(map(), map()) :: map()
  def form(ctx, %{node: loop, key: key, source: source}) do
    %{
      key: key,
      state: state(ctx.params, key),
      source: source,
      loop: loop["id"],
      context: %{mode: ctx.mode, data: ctx.data}
    }
  end

  @doc """
  The name of an input of the form of a block: `name(assigns, "q")` is
  `"catalog[q]"`, `name(assigns, ["category", ""])` is `"catalog[category][]"`
  (several values) and `name(assigns, ["price", "min"])` is
  `"catalog[price][min]"`. `nil` outside a filter form.
  """
  @spec name(map(), String.t() | [String.t()]) :: String.t() | nil
  def name(%{ctx: %{form: %{key: key}}}, path) do
    path |> List.wrap() |> Enum.reduce(key, &"#{&2}[#{&1}]")
  end

  def name(_assigns, _path), do: nil

  @doc "The value the visitor gave to an entry of the form (`nil` if none)."
  @spec value(map(), String.t() | [String.t()]) :: term()
  def value(%{ctx: %{form: %{state: state}}}, path) do
    path
    |> List.wrap()
    |> Enum.reduce(state, fn
      key, %{} = map -> Map.get(map, to_string(key))
      _key, _value -> nil
    end)
  end

  def value(_assigns, _path), do: nil

  @doc "Whether `option` is the value (or one of the values) of an entry."
  @spec checked?(map(), String.t() | [String.t()], term()) :: boolean()
  def checked?(assigns, path, option) do
    option = to_string(option)

    case value(assigns, path) do
      values when is_list(values) -> option in values
      value when is_binary(value) -> value == option
      _ -> false
    end
  end

  @doc """
  The options of a field of the form's source: `[%{label: text, value: value,
  count: count | nil}]`, from `ElementorexCms.Source.values/3`.
  """
  @spec options(map(), String.t()) :: [map()]
  def options(%{ctx: %{form: %{source: %Source{} = source, context: context}}}, key) do
    field = Enum.find(source.fields, &(&1.key == key))

    if field && not field.custom do
      source
      |> Source.values(key, context)
      |> Enum.map(fn {value, count} ->
        %{label: Dynamic.display(value, field, %{}), value: param(value), count: count}
      end)
    else
      []
    end
  end

  def options(_assigns, _key), do: []

  @doc "The field `key` of the form's source, or `nil`."
  @spec field(map(), String.t()) :: Field.t() | nil
  def field(%{ctx: %{form: %{source: %Source{fields: fields}}}}, key),
    do: Enum.find(fields, &(&1.key == key))

  def field(_assigns, _key), do: nil

  defp param(value) when is_binary(value), do: value
  defp param(value) when is_atom(value), do: Atom.to_string(value)

  defp param(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: ""
  end

  @doc "The choices for the target of a filter form in the editor: `[{label, node_id}]`."
  @spec loop_choices(map(), ElementorexCms.Registry.t() | nil, Sources.t() | nil) :: [
          {String.t(), String.t()}
        ]
  def loop_choices(doc, registry, sources) do
    doc
    |> loops(registry)
    |> Enum.with_index(1)
    |> Enum.map(fn {loop, number} ->
      source = Sources.fetch(sources, get_in(loop, ["props", "source"]))

      # Its name in the structure, its CSS ID or its place among the grids
      name =
        get_in(loop, ["attrs", "label"]) ||
          (get_in(loop, ["attrs", "id"]) && "#" <> loop["attrs"]["id"]) ||
          "#{ElementorexCms.I18n.t("Loop grid")} #{number}"

      label =
        [name, source && ElementorexCms.I18n.t(source.label)]
        |> Enum.filter(& &1)
        |> Enum.join(" · ")

      {label, loop["id"]}
    end)
  end
end
