defmodule ElementorexCms.Source.Field do
  @moduledoc """
  A field of a source (`ElementorexCms.Source`): what the editor offers when a
  prop of a block is bound to the data of an item.

    * `key` - the path of the value in a record (`"name"`, `"category.name"`)
    * `label` - shown in the editor (translated with `ElementorexCms.I18n`)
    * `type` - what the value is, so the editor can suggest it for the right
      props: `:string`, `:text` (several lines), `:html` (rich text),
      `:integer`, `:number`, `:boolean`, `:date`, `:datetime`, `:image` (an
      image URL), `:url`, `:color`, `:icon` or `:list`
    * `sortable` / `filterable` - whether loops can order and filter by it
    * `searchable` - whether the text search of the visitors' filters looks
      in it (default: text fields, `:string`, `:text` and `:html`)
    * `custom` - a filter of the source with logic of its own (`in_stock`)
      rather than a value of the records: it can filter but not be shown
    * `role` - what the field means for templates generated from the source:
      `:title`, `:image`, `:description`, `:price` (or `nil`)
    * `defaults` - settings of new bindings to the field (`"before"`,
      `"after"`, `"format"`, `"decimals"`, `"length"`, `"fallback"`), e.g. a
      price that starts with `"$"`. See `ElementorexCms.Dynamic`
  """

  @types ~w(string text html integer number boolean date datetime image url color icon list)a
  @roles [:title, :image, :description, :price]

  defstruct [
    :key,
    :label,
    type: :string,
    sortable: false,
    filterable: false,
    searchable: false,
    custom: false,
    role: nil,
    defaults: %{}
  ]

  @type t :: %__MODULE__{
          key: String.t(),
          label: String.t(),
          type: atom(),
          sortable: boolean(),
          filterable: boolean(),
          searchable: boolean(),
          custom: boolean(),
          role: atom() | nil,
          defaults: map()
        }

  @doc "Types a field can have."
  @spec types() :: [atom()]
  def types, do: @types

  @doc "Roles a field can have (see the module docs)."
  @spec roles() :: [atom()]
  def roles, do: @roles

  @doc """
  Builds a field. `key` is a string or an atom; options are the keys of the
  struct (`:label`, `:type`, `:sortable`, `:filterable`, `:searchable`,
  `:custom`, `:role`, `:defaults`).
  The label defaults to the key in words (`image_url` → `"Image URL"`).

      Field.new(:price, type: :number, sortable: true, defaults: %{"before" => "$"})
  """
  @spec new(atom() | String.t(), keyword()) :: t()
  def new(key, opts \\ []) do
    key = to_string(key)
    type = Keyword.get(opts, :type, :string)

    unless type in @types do
      raise ArgumentError,
            "unknown field type #{inspect(type)} for #{inspect(key)}, expected one of: " <>
              Enum.map_join(@types, ", ", &inspect/1)
    end

    %__MODULE__{
      key: key,
      label: Keyword.get_lazy(opts, :label, fn -> humanize(key) end),
      type: type,
      sortable: Keyword.get(opts, :sortable, false),
      filterable: Keyword.get(opts, :filterable, false),
      searchable: Keyword.get(opts, :searchable, type in [:string, :text, :html]),
      custom: Keyword.get(opts, :custom, false),
      role: Keyword.get(opts, :role),
      defaults: opts |> Keyword.get(:defaults, %{}) |> ElementorexCms.Dynamic.normalize_settings()
    }
  end

  @html ~r/(^|_)html$/
  @image ~r/(^|_)(image|images|img|photo|picture|pic|thumbnail|thumb|avatar|cover|logo|banner|poster)(_url|_path|_src)?$/
  @url ~r/(^|_)(url|link|website|homepage|href)$/
  @text ~r/^(description|body|content|summary|excerpt|intro|bio|about|notes|details|text|overview|abstract)$|_(description|body|content|summary|excerpt|notes|text)$/
  @color ~r/(^|_)colou?r$/

  @doc """
  The type of a text field guessed from its name: `image`, `photo`,
  `*_image_url`… are `:image`; `url`, `link`, `website`, `*_url` are `:url`;
  `description`, `body`, `summary`… are `:text`; `*_html` is `:html`; `color`
  is `:color`; anything else `:string`.

      iex> ElementorexCms.Source.Field.string_type("cover_image_url")
      :image
      iex> ElementorexCms.Source.Field.string_type("short_description")
      :text
  """
  @spec string_type(String.t()) :: atom()
  def string_type(key) do
    name = key |> to_string() |> String.split(".") |> List.last()

    cond do
      name =~ @html -> :html
      name =~ @image -> :image
      name =~ @url -> :url
      name =~ @text -> :text
      name =~ @color -> :color
      true -> :string
    end
  end

  @acronyms ~w(id url uri sku html css seo api faq pdf iso uuid ip sms gps vat)

  @doc """
  A field name in words: `"image_url"` → `"Image URL"`, `"category.name"` →
  `"Category · Name"`.
  """
  @spec humanize(String.t() | atom()) :: String.t()
  def humanize(key) do
    key
    |> to_string()
    |> String.split(".")
    |> Enum.map_join(" · ", &humanize_segment/1)
  end

  defp humanize_segment("inserted_at"), do: "Created at"
  defp humanize_segment("updated_at"), do: "Updated at"

  defp humanize_segment(segment) do
    segment
    |> String.trim_trailing("_id")
    |> String.split("_", trim: true)
    |> Enum.with_index()
    |> Enum.map_join(" ", fn
      {word, _index} when word in @acronyms -> String.upcase(word)
      {word, 0} -> String.capitalize(word)
      {word, _index} -> word
    end)
  end
end
