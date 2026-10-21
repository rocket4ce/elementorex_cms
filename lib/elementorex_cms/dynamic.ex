defmodule ElementorexCms.Dynamic do
  @moduledoc """
  Dynamic content: props of a block bound to fields of a record.

  A node keeps its bindings next to its props, one per bound prop:

      %{
        "type" => "heading",
        "props" => %{"text" => "Product name"},
        "dynamic" => %{
          "text" => %{"field" => "name"}
        }
      }

  When the node is rendered with a current item (inside a *Loop grid*, or a
  document rendered with `record=`), the value of the field replaces the prop;
  without one the prop keeps its own value, which works as a placeholder. Bound
  values are cast and sanitized like any other value of the prop, so a field
  can never inject markup or unsafe URLs.

  ## A binding

    * `"field"` - the key of a field of the source (`"name"`,
      `"category.name"`) or `"@url"` (the page of the item)
    * `"from"` - `"item"` (default: the current item) or `"site"` (a top-level
      value of the `data` the host passes, such as the site name)
    * `"before"` / `"after"` - text around the value (`"$"`, `" left"`)
    * `"fallback"` - used when the item has no value
    * `"format"` - `"number"` (thousands separators of the language, with
      `"decimals"`), `"date"`, `"datetime"`, `"time"`, `"excerpt"` (plain text
      cut to `"length"` characters), `"upper"` or `"lower"`

  Only fields declared by the source can be read: a binding to anything else
  renders nothing.

  ## Display conditions

  A node can also be shown only for the items that match a condition on one of
  their fields (its *Advanced* attribute `"condition"`): a *Sold out* badge
  for products without stock, a *Featured* ribbon…

      "attrs" => %{"condition" => %{"field" => "stock", "op" => "lte", "value" => "0"}}

  The operators are those of the filters of a loop (see
  `ElementorexCms.Source.Query`). Without a current item the node is shown;
  on the canvas, nodes whose condition fails are dimmed instead of removed.
  """

  alias ElementorexCms.Block
  alias ElementorexCms.Block.Prop
  alias ElementorexCms.Document
  alias ElementorexCms.HTML.Sanitizer
  alias ElementorexCms.I18n
  alias ElementorexCms.Source
  alias ElementorexCms.Source.Field
  alias ElementorexCms.Source.Query
  alias ElementorexCms.Sources

  @bindable ~w(string text richtext html url image integer number boolean select icon color datetime)a
  @formats ~w(number date datetime time excerpt upper lower)
  @froms ~w(item site)
  @path ~r/\A(@url|[a-z_][a-z0-9_]{0,63}(\.[a-z_][a-z0-9_]{0,63}){0,3})\z/
  @prop_key ~r/\A[a-z_][a-z0-9_]{0,63}\z/

  @doc "Formats of a binding (see the module docs)."
  @spec formats() :: [String.t()]
  def formats, do: @formats

  @doc "Whether a prop can be bound to a field (lists cannot)."
  @spec bindable?(Prop.t()) :: boolean()
  def bindable?(%Prop{type: type}), do: type in @bindable

  @doc "The binding of a prop of a node, or `nil`."
  @spec binding(map() | nil, atom() | String.t()) :: map() | nil
  def binding(%{"dynamic" => %{} = dynamic}, prop), do: Map.get(dynamic, to_string(prop))
  def binding(_node, _prop), do: nil

  ## Normalization

  @doc """
  Keeps the valid bindings of a node: of props of `block` that can be bound
  (any well-formed key when the block is unknown), with valid settings.
  """
  @spec normalize(term(), module() | nil) :: map()
  def normalize(dynamic, block) when is_map(dynamic) do
    for {key, binding} <- dynamic,
        key = to_string(key),
        key =~ @prop_key,
        block == nil or bindable_prop?(block, key),
        binding = normalize_binding(binding),
        into: %{} do
      {key, binding}
    end
  end

  def normalize(_dynamic, _block), do: %{}

  defp bindable_prop?(block, key) do
    case Block.find_prop(block, key) do
      %Prop{} = prop -> bindable?(prop)
      nil -> false
    end
  end

  @doc """
  A valid binding or `nil`. Takes a map (string or atom keys), a keyword list
  or just the field key.

      iex> ElementorexCms.Dynamic.normalize_binding(field: "price", before: "$", format: "number")
      %{"field" => "price", "before" => "$", "format" => "number"}
  """
  @spec normalize_binding(term()) :: map() | nil
  def normalize_binding(field) when is_binary(field), do: normalize_binding(%{"field" => field})

  def normalize_binding(binding) when is_list(binding) do
    if Keyword.keyword?(binding), do: normalize_binding(Map.new(binding))
  end

  def normalize_binding(%{} = binding) do
    binding = Map.new(binding, fn {key, value} -> {to_string(key), value} end)
    field = binding["field"]
    from = to_string(binding["from"] || "item")

    if is_binary(field) and field =~ @path and from in @froms and site_key?(from, field) do
      %{"field" => field}
      |> then(&if(from == "site", do: Map.put(&1, "from", "site"), else: &1))
      |> Map.merge(normalize_settings(binding))
    end
  end

  def normalize_binding(_binding), do: nil

  # Site values are top-level keys of `data`: no paths into structs.
  defp site_key?("site", field), do: field =~ @prop_key
  defp site_key?(_from, _field), do: true

  @doc """
  The settings of a binding (everything but the field): `before`, `after`,
  `fallback`, `format`, `decimals` and `length`, validated.
  """
  @spec normalize_settings(term()) :: map()
  def normalize_settings(settings) when is_map(settings) or is_list(settings) do
    settings = Map.new(settings, fn {key, value} -> {to_string(key), value} end)

    %{}
    |> put_text("before", settings["before"], 60)
    |> put_text("after", settings["after"], 60)
    |> put_text("fallback", settings["fallback"], 500)
    |> put_format(settings["format"])
    |> put_int("decimals", settings["decimals"], 0..4)
    |> put_int("length", settings["length"], 10..2000)
  end

  def normalize_settings(_settings), do: %{}

  defp put_text(map, key, value, max) when is_binary(value) and value != "" do
    if String.valid?(value),
      do: Map.put(map, key, value |> String.replace(~r/[\r\n\t]+/, " ") |> String.slice(0, max)),
      else: map
  end

  defp put_text(map, _key, _value, _max), do: map

  defp put_format(map, format) when format in @formats, do: Map.put(map, "format", format)
  defp put_format(map, _format), do: map

  defp put_int(map, key, value, range) do
    case to_int(value) do
      int when is_integer(int) -> if int in range, do: Map.put(map, key, int), else: map
      nil -> map
    end
  end

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp to_int(_value), do: nil

  ## Display conditions

  @doc """
  A valid display condition or `nil`: `"field"` (like a binding's), `"op"`
  (an operator of `ElementorexCms.Source.Query`), `"value"` and optionally
  `"from" => "site"`.
  """
  @spec normalize_condition(term()) :: map() | nil
  def normalize_condition(%{} = condition) do
    condition = Map.new(condition, fn {key, value} -> {to_string(key), value} end)
    op = condition["op"]
    value = condition["value"]

    with %{} = binding <- normalize_binding(Map.take(condition, ["field", "from"])),
         true <- op in Query.ops(),
         value <- if(is_binary(value) and String.valid?(value), do: value, else: "") do
      binding
      |> Map.put("op", op)
      |> Map.put("value", String.slice(value, 0, 200))
    else
      _ -> nil
    end
  end

  def normalize_condition(_condition), do: nil

  @doc """
  Whether a node is shown for the current item of `ctx`: `true` without a
  condition or without an item to check it against.
  """
  @spec visible?(map(), map()) :: boolean()
  def visible?(%{"attrs" => %{"condition" => condition}}, ctx) when is_map(condition) do
    with %{} = condition <- normalize_condition(condition),
         {:ok, value, _field} <- fetch(condition, ctx) do
      Query.match_value?(value, condition["op"], condition["value"])
    else
      _ -> true
    end
  end

  def visible?(_node, _ctx), do: true

  ## Rendering

  @doc """
  The props of `node` with its bindings applied for the current item of `ctx`
  (an `ElementorexCms.Renderer.Context`). Bindings without a value to read (no
  current item) keep the prop's own value.
  """
  @spec resolve(map(), module(), map()) :: map()
  def resolve(%{"dynamic" => %{} = dynamic} = node, block, ctx) when map_size(dynamic) > 0 do
    Enum.reduce(dynamic, node["props"] || %{}, fn {key, binding}, props ->
      with %Prop{} = prop <- Block.find_prop(block, key),
           true <- bindable?(prop),
           %{} = binding <- normalize_binding(binding),
           {:ok, raw, field} <- fetch(binding, ctx) do
        Map.put(props, key, to_prop(raw, field, binding, prop))
      else
        _ -> props
      end
    end)
  end

  def resolve(node, _block, _ctx), do: node["props"] || %{}

  @doc """
  The raw value of a binding for the current item of `ctx`: `{:ok, value,
  field}` or `:none` when there is nothing to read from.
  """
  @spec fetch(map(), map()) :: {:ok, term(), Field.t() | nil} | :none
  def fetch(%{"from" => "site", "field" => key}, ctx) do
    case site_value(ctx.data, key) do
      {:ok, value} -> {:ok, value, Field.new(key, type: guess_type(key, value))}
      :error -> :none
    end
  end

  def fetch(%{"field" => key}, %{item: %{source: %Source{} = source, record: record}}) do
    case Source.field(source, key) do
      %Field{} = field -> {:ok, Source.value(source, record, key), field}
      # A field the source does not offer (any more) is never read.
      nil -> {:ok, nil, nil}
    end
  end

  def fetch(_binding, _ctx), do: :none

  @doc """
  A top-level value of `data` (atom or string key) that can be shown: text,
  numbers, booleans and dates. Anything else (structs, maps, lists) is not
  readable from documents.
  """
  @spec site_value(term(), String.t()) :: {:ok, term()} | :error
  def site_value(data, key) when is_map(data) and is_binary(key) do
    value =
      case Map.fetch(data, key) do
        {:ok, value} ->
          value

        :error ->
          try do
            Map.get(data, String.to_existing_atom(key))
          rescue
            ArgumentError -> nil
          end
      end

    if is_nil(value) or scalar?(value), do: {:ok, value}, else: :error
  end

  def site_value(_data, _key), do: :error

  @doc "Fields for the site values of `data` (`from: \"site\"` bindings)."
  @spec site_fields(term()) :: [Field.t()]
  def site_fields(data) when is_map(data) do
    data
    |> Enum.flat_map(fn {key, value} ->
      key = to_string(key)

      if key =~ @prop_key and scalar?(value),
        do: [Field.new(key, type: guess_type(key, value))],
        else: []
    end)
    |> Enum.sort_by(& &1.key)
  end

  def site_fields(_data), do: []

  defp scalar?(value) when is_binary(value), do: String.valid?(value)
  defp scalar?(value) when is_number(value) or is_boolean(value), do: true
  defp scalar?(%struct{}) when struct in [Date, DateTime, NaiveDateTime, Time], do: true
  defp scalar?(%{__struct__: Decimal}), do: true
  defp scalar?(_value), do: false

  defp guess_type(_key, value) when is_integer(value), do: :integer
  defp guess_type(_key, value) when is_float(value), do: :number
  defp guess_type(_key, %{__struct__: Decimal}), do: :number
  defp guess_type(_key, value) when is_boolean(value), do: :boolean
  defp guess_type(_key, %Date{}), do: :date
  defp guess_type(_key, %struct{}) when struct in [DateTime, NaiveDateTime], do: :datetime
  defp guess_type(key, _value), do: Field.string_type(key)

  @doc """
  Turns a raw value into the value of `prop`: numbers for number props, `true`
  or `false` for booleans, escaped text (paragraphs for rich text) and the
  formatted text with `before`, `after` and `fallback` for the rest. The result
  is cast again by the prop when the block renders.
  """
  @spec to_prop(term(), Field.t() | nil, map(), Prop.t()) :: term()
  def to_prop(raw, field, binding, %Prop{type: type} = prop) do
    case type do
      type when type in [:integer, :number] -> number(raw) || number(binding["fallback"])
      :boolean -> truthy?(raw)
      :datetime -> datetime(raw) || binding["fallback"] || ""
      type when type in [:richtext, :html] -> rich(raw, field, binding, prop)
      _text -> text(raw, field, binding)
    end
  end

  defp text(raw, field, binding) do
    case display(raw, field, binding) do
      "" -> binding["fallback"] || ""
      text -> (binding["before"] || "") <> text <> (binding["after"] || "")
    end
  end

  defp rich(raw, field, binding, prop) do
    inline? = prop.type == :richtext and prop.policy == :inline
    html? = field != nil and field.type == :html and binding["format"] in [nil, "upper", "lower"]

    case display(raw, field, binding) do
      "" ->
        escape_text(binding["fallback"] || "", inline?)

      html when html? ->
        before = Sanitizer.text_to_html(binding["before"] || "")
        after_text = Sanitizer.text_to_html(binding["after"] || "")
        if inline?, do: before <> html <> after_text, else: wrap(before, html, after_text)

      text ->
        escape_text((binding["before"] || "") <> text <> (binding["after"] || ""), inline?)
    end
  end

  # HTML values (paragraphs) with text around them: the text goes in
  # paragraphs of its own.
  defp wrap(before, html, after_text), do: paragraph(before) <> html <> paragraph(after_text)

  defp paragraph(""), do: ""
  defp paragraph(text), do: "<p>#{text}</p>"

  defp escape_text("", _inline?), do: ""

  defp escape_text(text, true) do
    text |> String.replace(~r/\s*\r?\n\s*/, " ") |> Sanitizer.text_to_html()
  end

  defp escape_text(text, false) do
    text
    |> String.split(~r/\r?\n\s*\r?\n/, trim: true)
    |> Enum.map_join(&"<p>#{Sanitizer.text_to_html(String.trim(&1))}</p>")
  end

  @doc """
  The text of a value for a binding: formatted per its `"format"` and the
  current locale, `""` for no value.
  """
  @spec display(term(), Field.t() | nil, map()) :: String.t()
  def display(nil, _field, _binding), do: ""

  def display(raw, field, binding) do
    case binding["format"] do
      "number" -> format_number(raw, binding["decimals"])
      "date" -> format_date(raw, :date)
      "datetime" -> format_date(raw, :datetime)
      "time" -> format_date(raw, :time)
      "excerpt" -> excerpt(raw, field, binding["length"] || 160)
      "upper" -> raw |> plain() |> String.upcase()
      "lower" -> raw |> plain() |> String.downcase()
      _as_is -> plain(raw)
    end
  end

  defp plain(nil), do: ""
  defp plain(value) when is_binary(value), do: if(String.valid?(value), do: value, else: "")
  defp plain(true), do: I18n.t("Yes")
  defp plain(false), do: I18n.t("No")
  defp plain(value) when is_integer(value), do: Integer.to_string(value)
  defp plain(value) when is_float(value), do: :erlang.float_to_binary(value, [:short])
  defp plain(%{__struct__: Decimal} = value), do: to_string(value)
  defp plain(%Date{} = value), do: format_date(value, :date)

  defp plain(%struct{} = value) when struct in [DateTime, NaiveDateTime],
    do: format_date(value, :datetime)

  defp plain(%Time{} = value), do: format_date(value, :time)
  defp plain(value) when is_atom(value), do: Atom.to_string(value)

  defp plain(values) when is_list(values),
    do: values |> Enum.map(&plain/1) |> Enum.reject(&(&1 == "")) |> Enum.join(", ")

  defp plain(_value), do: ""

  defp excerpt(raw, field, length) do
    text =
      if field != nil and field.type == :html,
        do: Sanitizer.text(plain(raw)),
        else: raw |> plain() |> String.replace(~r/\s+/u, " ") |> String.trim()

    if String.length(text) <= length do
      text
    else
      cut = String.slice(text, 0, length)

      case Regex.run(~r/\A(.+)\s\S*\z/su, cut) do
        [_, words] -> String.trim_trailing(words, ",.;: ") <> "…"
        _ -> cut <> "…"
      end
    end
  end

  ## Numbers

  @doc """
  A number with the thousands and decimal separators of the current locale.
  `decimals` fixes the decimal places (rounding); `nil` keeps them.

      iex> ElementorexCms.Dynamic.format_number(1234567.891, 2)
      "1,234,567.89"
      iex> ElementorexCms.I18n.with_locale("es", fn -> ElementorexCms.Dynamic.format_number(19990, 0) end)
      "19.990"
  """
  @spec format_number(term(), non_neg_integer() | nil) :: String.t()
  def format_number(value, decimals \\ nil) do
    case number(value) do
      nil ->
        plain(value)

      number ->
        {thousands, separator} = separators(I18n.locale())

        string =
          cond do
            is_integer(decimals) -> :erlang.float_to_binary(number * 1.0, decimals: decimals)
            is_integer(number) -> Integer.to_string(number)
            number == trunc(number) -> Integer.to_string(trunc(number))
            true -> :erlang.float_to_binary(number, [:short])
          end

        {sign, digits} =
          case string do
            "-" <> digits -> {"-", digits}
            digits -> {"", digits}
          end

        case String.split(digits, ".", parts: 2) do
          [int] -> sign <> group(int, thousands)
          [int, frac] -> sign <> group(int, thousands) <> separator <> frac
        end
    end
  end

  defp group(int, separator) do
    int
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(3)
    |> Enum.join(String.reverse(separator))
    |> String.reverse()
  end

  defp separators(locale) do
    case locale |> to_string() |> String.split(["-", "_"]) |> hd() do
      language when language in ~w(es pt de it nl id tr da) -> {".", ","}
      language when language in ~w(fr ru pl cs sv nb fi uk) -> {"\u202F", ","}
      _ -> {",", "."}
    end
  end

  defp number(value) when is_integer(value) or is_float(value), do: value

  defp number(%{__struct__: Decimal} = value), do: value |> to_string() |> number()

  defp number(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {number, ""} ->
        if number == trunc(number) and not String.contains?(value, [".", "e", "E"]),
          do: trunc(number),
          else: number

      _ ->
        nil
    end
  end

  defp number(_value), do: nil

  defp truthy?(value), do: value not in [nil, false, "", 0, "0", "false", "off", []]

  ## Dates

  @date_formats %{
    "en" => {"%b %-d, %Y", "%b %-d, %Y %H:%M"},
    "es" => {"%d/%m/%Y", "%d/%m/%Y %H:%M"},
    "pt" => {"%d/%m/%Y", "%d/%m/%Y %H:%M"},
    "fr" => {"%d/%m/%Y", "%d/%m/%Y %H:%M"},
    "it" => {"%d/%m/%Y", "%d/%m/%Y %H:%M"},
    "de" => {"%d.%m.%Y", "%d.%m.%Y %H:%M"},
    "ja" => {"%Y/%m/%d", "%Y/%m/%d %H:%M"}
  }

  @doc """
  A date, date-time or time in the format of the current locale (`kind` is
  `:date`, `:datetime` or `:time`). Times of a `DateTime` are shown in the
  configured `:time_zone` when there is a time zone database.
  """
  @spec format_date(term(), :date | :datetime | :time) :: String.t()
  def format_date(value, kind) do
    language = I18n.locale() |> to_string() |> String.split(["-", "_"]) |> hd()
    {date, datetime} = Map.get(@date_formats, language, @date_formats["en"])

    case {kind, temporal(value)} do
      {_kind, nil} -> plain_unless_temporal(value)
      {:time, %Date{}} -> ""
      {:time, value} -> Calendar.strftime(value, "%H:%M")
      {:datetime, %Date{} = value} -> Calendar.strftime(value, date)
      {:datetime, %Time{}} -> ""
      {:datetime, value} -> Calendar.strftime(value, datetime)
      {:date, %Time{}} -> ""
      {:date, value} -> Calendar.strftime(value, date)
    end
  end

  defp plain_unless_temporal(value) when is_binary(value), do: value
  defp plain_unless_temporal(_value), do: ""

  defp temporal(%DateTime{} = value), do: local(value)
  defp temporal(%struct{} = value) when struct in [Date, NaiveDateTime, Time], do: value

  defp temporal(value) when is_binary(value) do
    with {:error, _} <- DateTime.from_iso8601(value) |> ok_datetime(),
         {:error, _} <- NaiveDateTime.from_iso8601(value),
         {:error, _} <- Date.from_iso8601(value) do
      nil
    else
      {:ok, value} -> temporal(value)
    end
  end

  defp temporal(_value), do: nil

  defp ok_datetime({:ok, datetime, _offset}), do: {:ok, datetime}
  defp ok_datetime(error), do: error

  defp local(datetime) do
    case Application.get_env(:elementorex_cms, :time_zone) do
      nil ->
        datetime

      zone ->
        case DateTime.shift_zone(datetime, zone) do
          {:ok, shifted} -> shifted
          {:error, _} -> datetime
        end
    end
  end

  # The value of `:datetime` props: "2026-12-31T23:59:00" (local time).
  defp datetime(value) do
    case temporal(value) do
      %Date{} = date -> Date.to_iso8601(date)
      %DateTime{} = dt -> dt |> DateTime.to_naive() |> datetime()
      %NaiveDateTime{} = dt -> dt |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()
      _ -> nil
    end
  end

  ## Scope in the editor

  @doc """
  The source of the items a node is rendered with: the source of its nearest
  enclosing loop, or `document_source` (the source of a template for single
  records) when it is in no loop. `nil` when there is none.
  """
  @spec item_source(
          Document.t(),
          String.t() | nil,
          Sources.t(),
          String.t() | nil,
          ElementorexCms.Registry.t() | nil
        ) :: Source.t() | nil
  def item_source(doc, node_id, sources, document_source, registry \\ nil) do
    loop =
      doc
      |> Document.path(node_id || "")
      |> Enum.drop(-1)
      |> Enum.reverse()
      |> Enum.find(&loop?(&1, registry))

    case loop do
      nil -> Sources.fetch(sources, document_source)
      loop -> Sources.fetch(sources, get_in(loop, ["props", "source"]))
    end
  end

  @doc """
  The source whose fields the `:field` props of a node choose from: its own
  `source` prop (a loop) or, for a node in a filter form (a block with a
  `:loop` prop, or inside one), the source of the loop grid it filters.
  """
  @spec field_source(
          Document.t(),
          String.t() | nil,
          Sources.t(),
          ElementorexCms.Registry.t() | nil
        ) ::
          Source.t() | nil
  def field_source(doc, node_id, sources, registry \\ nil) do
    doc
    |> Document.path(node_id || "")
    |> Enum.reverse()
    |> Enum.find_value(fn node ->
      case ElementorexCms.Registry.fetch(registry, node["type"]) do
        nil ->
          nil

        block ->
          cond do
            match?(%Prop{type: :source}, Block.find_prop(block, :source)) ->
              {:ok, Sources.fetch(sources, get_in(node, ["props", "source"]))}

            prop = Enum.find(block.props(), &(&1.type == :loop)) ->
              target = get_in(node, ["props", prop.key])
              ctx = %{doc: doc, registry: registry, sources: sources}

              case ElementorexCms.Filters.target(ctx, target) do
                nil -> {:ok, nil}
                target -> {:ok, target.source}
              end

            true ->
              nil
          end
      end
    end)
    |> case do
      {:ok, source} -> source
      nil -> nil
    end
  end

  @doc "Whether a node repeats its children for the items of a source (a loop block)."
  @spec loop?(map(), ElementorexCms.Registry.t() | nil) :: boolean()
  def loop?(%{"type" => type}, registry) do
    case ElementorexCms.Registry.fetch(registry, type) do
      nil -> false
      block -> Map.get(block.meta(), :loop, false) == true
    end
  end

  def loop?(_node, _registry), do: false
end
