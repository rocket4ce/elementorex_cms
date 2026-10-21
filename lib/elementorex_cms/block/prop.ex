defmodule ElementorexCms.Block.Prop do
  @moduledoc """
  A property of a block: its type, default, label and editor control.

  Props are declared with `ElementorexCms.Block.prop/3`. The type decides how a
  value is cast and sanitized when it reaches the document (from the editor or
  from stored JSON) and which control the inspector shows:

  | Type        | Value                                   | Control                    |
  | ----------- | --------------------------------------- | -------------------------- |
  | `:string`   | one line of text                        | text input                 |
  | `:text`     | multi-line plain text                   | textarea                   |
  | `:richtext` | sanitized HTML (`:rich` policy)         | inline editing + textarea  |
  | `:html`     | sanitized HTML (`:html` policy)         | code editor                |
  | `:select`   | one of `:options`                       | select, segmented, swatches|
  | `:boolean`  | `true` / `false`                        | toggle                     |
  | `:integer`  | integer within `:min`..`:max`           | number or range            |
  | `:number`   | number within `:min`..`:max`            | number or range            |
  | `:url`      | sanitized link URL                      | URL input                  |
  | `:image`    | sanitized image URL                     | image picker / upload      |
  | `:icon`     | Heroicons name                          | icon picker                |
  | `:color`    | CSS color or theme variable             | swatches + color input     |
  | `:datetime` | `"2026-12-31T23:59"`                     | date and time input        |
  | `:list`     | list of items, each with its `:fields`  | repeater                   |
  | `:source`   | key of an `ElementorexCms.Source`       | collection select          |
  | `:field`    | key of a field of the block's source    | field select               |
  | `:loop`     | node id of a loop grid of the document  | loop select                |

  ## Options

    * `:default` - value for new blocks and for missing or invalid values
    * `:label`, `:help`, `:placeholder` - texts of the control (translated with
      `ElementorexCms.I18n`)
    * `:group` - heading of the inspector section the control goes in
    * `:control` - overrides the default control (`:textarea`, `:segmented`,
      `:swatches`, `:range`, `:code`...)
    * `:options` - for `:select`: `[{"Label", "value"}]` or a list of values
    * `:min`, `:max`, `:step`, `:unit` - for numbers
    * `:max_length` - for text types
    * `:policy` - for `:richtext`: `:rich` (default) or `:inline` (only
      formatting inside a line, see `ElementorexCms.HTML.Sanitizer`)
    * `:inline` - the prop can be edited by typing on the canvas
    * `:show_if` - only show the control when another prop matches:
      `{:icon, :present}`, `{:variant, "outline"}` or `{:size, ["lg", "xl"]}`
    * `:fields`, `:item_label`, `:max_items` - for `:list` (`fields` takes
      `{name, type, opts}` tuples)
    * `:only` - for `:field`: `:sortable` or `:filterable` fields only. The
      fields are those of the source chosen in the block's `source` prop or,
      inside a filter form, those of the loop it filters (its `:loop` prop)
  """

  alias ElementorexCms.CSS
  alias ElementorexCms.Heroicons
  alias ElementorexCms.HTML.Sanitizer
  alias ElementorexCms.Id
  alias ElementorexCms.URL

  @types ~w(string text richtext html select boolean integer number url image icon color datetime list source field loop)a

  defstruct [
    :name,
    :key,
    :type,
    :default,
    :label,
    :help,
    :placeholder,
    :control,
    :group,
    :min,
    :max,
    :step,
    :unit,
    :max_length,
    :show_if,
    :item_label,
    :max_items,
    :policy,
    :only,
    options: [],
    fields: [],
    inline: false
  ]

  @type t :: %__MODULE__{}

  @doc "Builds a prop. Raises `ArgumentError` on an unknown type."
  @spec new(atom(), atom(), keyword()) :: t()
  def new(name, type, opts \\ []) when is_atom(name) and is_atom(type) do
    unless type in @types do
      raise ArgumentError,
            "unknown prop type #{inspect(type)} for #{inspect(name)}, expected one of: " <>
              Enum.map_join(@types, ", ", &inspect/1)
    end

    fields =
      opts
      |> Keyword.get(:fields, [])
      |> Enum.map(fn
        {field, field_type} -> new(field, field_type, [])
        {field, field_type, field_opts} -> new(field, field_type, field_opts)
        %__MODULE__{} = prop -> prop
      end)

    prop = %__MODULE__{
      name: name,
      key: Atom.to_string(name),
      type: type,
      label: Keyword.get(opts, :label, humanize(name)),
      help: opts[:help],
      placeholder: opts[:placeholder],
      control: Keyword.get(opts, :control, default_control(type)),
      group: opts[:group],
      options: normalize_options(Keyword.get(opts, :options, [])),
      min: opts[:min],
      max: opts[:max],
      step: opts[:step],
      unit: opts[:unit],
      max_length: Keyword.get(opts, :max_length, default_max_length(type)),
      inline: Keyword.get(opts, :inline, false),
      show_if: opts[:show_if],
      fields: fields,
      item_label: opts[:item_label] && to_string(opts[:item_label]),
      max_items: Keyword.get(opts, :max_items, 50),
      policy: Keyword.get(opts, :policy, :rich),
      only: opts[:only]
    }

    %{prop | default: Keyword.get(opts, :default, empty(prop))}
  end

  @doc "Types a prop can have."
  @spec types() :: [atom()]
  def types, do: @types

  defp default_control(:string), do: :text
  defp default_control(:text), do: :textarea
  defp default_control(:richtext), do: :richtext
  defp default_control(:html), do: :code
  defp default_control(:select), do: :select
  defp default_control(:boolean), do: :toggle
  defp default_control(:integer), do: :number
  defp default_control(:number), do: :number
  defp default_control(:url), do: :url
  defp default_control(:image), do: :image
  defp default_control(:icon), do: :icon
  defp default_control(:color), do: :color
  defp default_control(:datetime), do: :datetime
  defp default_control(:list), do: :repeater
  defp default_control(:source), do: :source
  defp default_control(:field), do: :field
  defp default_control(:loop), do: :loop

  defp default_max_length(:string), do: 500
  defp default_max_length(:text), do: 10_000
  defp default_max_length(:richtext), do: 50_000
  defp default_max_length(:html), do: 100_000
  defp default_max_length(_type), do: nil

  defp empty(%{type: :boolean}), do: false
  defp empty(%{type: :list}), do: []
  defp empty(%{type: type}) when type in [:integer, :number], do: nil
  defp empty(%{type: :select, options: [{_, value} | _]}), do: value
  defp empty(_prop), do: ""

  defp normalize_options(options) do
    Enum.map(options, fn
      {label, value} -> {to_string(label), to_string(value)}
      value -> {to_string(value), to_string(value)}
    end)
  end

  defp humanize(name) do
    name
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  @doc "Values allowed by a `:select` prop."
  @spec values(t()) :: [String.t()]
  def values(%__MODULE__{options: options}), do: Enum.map(options, &elem(&1, 1))

  @doc """
  The default value, with fresh ids for the items of a `:list` (every item
  carries an `"id"` so the editor can reorder it).
  """
  @spec default(t()) :: term()
  def default(%__MODULE__{type: :list, default: items} = prop) when is_list(items) do
    cast(prop, items)
  end

  def default(%__MODULE__{default: default}), do: default

  @doc """
  Casts and sanitizes a value. Invalid values fall back to the default (or to an
  empty value when the default would be misleading, like an unsafe URL).
  """
  @spec cast(t(), term()) :: term()
  def cast(prop, value)

  def cast(%__MODULE__{} = prop, nil), do: if(prop.type == :list, do: [], else: prop.default)

  def cast(%__MODULE__{type: :string} = prop, value) do
    value
    |> to_text()
    |> String.replace(~r/[\r\n\t]+/, " ")
    |> limit(prop)
  end

  def cast(%__MODULE__{type: :text} = prop, value) do
    value |> to_text() |> String.replace("\r\n", "\n") |> limit(prop)
  end

  def cast(%__MODULE__{type: :richtext} = prop, value) do
    value |> to_text() |> limit(prop) |> Sanitizer.sanitize(prop.policy || :rich)
  end

  def cast(%__MODULE__{type: :html} = prop, value) do
    value |> to_text() |> limit(prop) |> Sanitizer.sanitize(:html)
  end

  def cast(%__MODULE__{type: :select} = prop, value) do
    value = to_string(value)
    if value in values(prop), do: value, else: prop.default
  end

  def cast(%__MODULE__{type: :boolean}, value) when is_boolean(value), do: value
  def cast(%__MODULE__{type: :boolean}, value) when value in ["true", "on", "1", 1], do: true

  def cast(%__MODULE__{type: :boolean}, value) when value in ["false", "off", "0", 0, ""],
    do: false

  def cast(%__MODULE__{type: :boolean} = prop, _value), do: prop.default

  def cast(%__MODULE__{type: :integer} = prop, value) do
    case parse_number(value) do
      nil -> prop.default
      number -> number |> round() |> clamp(prop)
    end
  end

  def cast(%__MODULE__{type: :number} = prop, value) do
    case parse_number(value) do
      nil -> prop.default
      number -> clamp(number, prop)
    end
  end

  def cast(%__MODULE__{type: :url}, value), do: URL.sanitize(to_text(value)) || ""
  def cast(%__MODULE__{type: :image}, value), do: URL.sanitize_media(to_text(value)) || ""

  def cast(%__MODULE__{type: :icon} = prop, value) do
    value = to_text(value)

    cond do
      value == "" -> ""
      Heroicons.exists?(value) -> value
      true -> prop.default
    end
  end

  def cast(%__MODULE__{type: :color}, value) do
    value = String.trim(to_text(value))
    if value != "" and CSS.color?(value), do: value, else: ""
  end

  def cast(%__MODULE__{type: :datetime} = prop, value) do
    value = String.trim(to_text(value))

    if value =~ ~r/\A\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}(:\d{2})?)?\z/, do: value, else: prop.default
  end

  def cast(%__MODULE__{type: :source}, value) do
    value = String.trim(to_text(value))
    if value =~ ~r/\A[a-z][a-z0-9_]{0,39}\z/, do: value, else: ""
  end

  def cast(%__MODULE__{type: :field}, value) do
    value = String.trim(to_text(value))

    if value =~ ~r/\A[a-z_][a-z0-9_]{0,63}(\.[a-z_][a-z0-9_]{0,63}){0,3}\z/,
      do: value,
      else: ""
  end

  def cast(%__MODULE__{type: :loop}, value) do
    value = String.trim(to_text(value))
    if Id.valid?(value), do: value, else: ""
  end

  def cast(%__MODULE__{type: :list} = prop, items) when is_list(items) do
    items
    |> Enum.filter(&is_map/1)
    |> Enum.take(prop.max_items)
    |> Enum.map(&cast_item(prop, &1))
  end

  def cast(%__MODULE__{type: :list} = prop, items) when is_map(items) do
    # Forms send repeaters as %{"0" => item, "1" => item}.
    items
    |> Enum.sort_by(fn {index, _} -> parse_number(index) || 0 end)
    |> Enum.map(&elem(&1, 1))
    |> then(&cast(prop, &1))
  end

  def cast(%__MODULE__{type: :list}, _items), do: []

  defp cast_item(prop, item) do
    item = Map.new(item, fn {key, value} -> {to_string(key), value} end)

    id =
      case item["id"] do
        id when is_binary(id) -> if Id.valid?(id), do: id, else: Id.generate()
        _ -> Id.generate()
      end

    Enum.reduce(prop.fields, %{"id" => id}, fn field, acc ->
      value =
        if Map.has_key?(item, field.key), do: cast(field, item[field.key]), else: field.default

      Map.put(acc, field.key, value)
    end)
  end

  @doc "A blank item for a `:list` prop, with the defaults of its fields (translated)."
  @spec new_item(t()) :: map()
  def new_item(%__MODULE__{type: :list} = prop) do
    prop |> cast_item(%{}) |> localize_item(prop)
  end

  @doc """
  The default value with its texts translated to the current locale (see
  `ElementorexCms.I18n`): plain and rich text props, and the text fields of
  list items. Other values are returned as they are.
  """
  @spec localized_default(t()) :: term()
  def localized_default(%__MODULE__{type: type} = prop)
      when type in [:string, :text, :richtext] do
    case default(prop) do
      text when is_binary(text) and text != "" -> ElementorexCms.I18n.t(text)
      other -> other
    end
  end

  def localized_default(%__MODULE__{type: :list} = prop) do
    prop |> default() |> Enum.map(&localize_item(&1, prop))
  end

  def localized_default(prop), do: default(prop)

  defp localize_item(item, prop) do
    Enum.reduce(prop.fields, item, fn
      %{type: type, key: key}, acc when type in [:string, :text, :richtext] ->
        case acc[key] do
          text when is_binary(text) and text != "" ->
            Map.put(acc, key, ElementorexCms.I18n.t(text))

          _ ->
            acc
        end

      _field, acc ->
        acc
    end)
  end

  @doc """
  Whether the control of `prop` should be shown given the other values, per
  its `:show_if` option.
  """
  @spec visible?(t(), map()) :: boolean()
  def visible?(%__MODULE__{show_if: nil}, _values), do: true

  def visible?(%__MODULE__{show_if: {field, :present}}, values) do
    value = Map.get(values, field)
    value not in [nil, "", false, []]
  end

  def visible?(%__MODULE__{show_if: {field, expected}}, values) when is_list(expected) do
    to_string(Map.get(values, field)) in Enum.map(expected, &to_string/1)
  end

  def visible?(%__MODULE__{show_if: {field, expected}}, values) do
    to_string(Map.get(values, field)) == to_string(expected)
  end

  defp to_text(value) when is_binary(value) do
    if String.valid?(value), do: value, else: ""
  end

  defp to_text(value) when is_number(value) or is_atom(value), do: to_string(value)
  defp to_text(_value), do: ""

  defp limit(text, %{max_length: nil}), do: text
  defp limit(text, %{max_length: max}), do: String.slice(text, 0, max)

  defp parse_number(value) when is_integer(value), do: value
  defp parse_number(value) when is_float(value), do: value

  defp parse_number(value) when is_binary(value) do
    value = value |> String.trim() |> String.replace(",", ".")

    case Float.parse(value) do
      {number, ""} ->
        if trunc(number) == number and not String.contains?(value, "."),
          do: trunc(number),
          else: number

      _ ->
        nil
    end
  end

  defp parse_number(_value), do: nil

  defp clamp(number, %{min: min, max: max}) do
    number
    |> then(&if(is_number(min) and &1 < min, do: min, else: &1))
    |> then(&if(is_number(max) and &1 > max, do: max, else: &1))
  end
end
