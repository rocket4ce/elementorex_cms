defmodule ElementorexCms.Source do
  @moduledoc """
  A collection of records that documents can show: products, posts, events,
  team members… (*dynamic content*).

  A source tells the editor which fields its records have, and gives the
  records to the blocks that need them: a *Loop grid* repeats its content for
  each record of a source, and any prop of a block can be bound to a field of
  the current record (see `ElementorexCms.Dynamic`).

  ## From an Ecto schema

  The quickest way: list your schema in the config. Its fields are read from
  the schema (see `ElementorexCms.Source.Ecto`), so a table made with
  `mix phx.gen.live` or by hand works as it is:

      config :elementorex_cms, sources: [MyApp.Catalog.Product]

  Or a module, to choose the fields, restrict the records and give each one a
  link (`mix elementorex.gen.source Catalog.Product` writes it):

      defmodule MyAppWeb.Sources.Products do
        use ElementorexCms.Source.Ecto,
          schema: MyApp.Catalog.Product,
          repo: MyApp.Repo,
          path: "/products/:slug",
          fields: [price: [defaults: %{"before" => "$", "format" => "number"}]]

        @impl true
        def scope(query, _context), do: where(query, [p], p.published)
      end

  ## Any other data

  Implement this behaviour: `key/0`, `label/0`, `fields/0` and `list/2` are
  required; `get/2`, `value/2`, `url/1`, `id/1`, `title/1`, `count/2`,
  `values/2` and `icon/0` are optional. `list/2` gets the filters, search and
  order of the loop and of the visitors' filters in its query (`"custom"`
  filters are the source's own, see `ElementorexCms.Source.Field`).

      defmodule MyAppWeb.Sources.Team do
        @behaviour ElementorexCms.Source

        alias ElementorexCms.Source.{Field, Query}

        @impl true
        def key, do: "team"
        @impl true
        def label, do: "Team"
        @impl true
        def fields, do: [Field.new(:name, role: :title), Field.new(:photo, type: :image)]
        @impl true
        def list(query, _context), do: Query.run(query, MyApp.Team.members(), &Map.get(&1, String.to_existing_atom(&2)))
      end

  `context` is `%{mode: :public | :editor, data: map}`: where the document is
  rendered and the `data` the host passed (the current user, a tenant…).

  The functions of this module work on the `%ElementorexCms.Source{}` built by
  `new/1` (see `ElementorexCms.Sources` for the configured ones).
  """

  alias ElementorexCms.Source.Field
  alias ElementorexCms.Source.Query

  defstruct [:key, :label, :icon, :impl, fields: []]

  @type t :: %__MODULE__{
          key: String.t(),
          label: String.t(),
          icon: String.t(),
          impl: module() | {module(), keyword()},
          fields: [Field.t()]
        }

  @type record :: term()
  @type context :: %{mode: :public | :editor, data: map()}

  @doc "Stable id of the source, stored in documents (`\"products\"`)."
  @callback key() :: String.t()

  @doc "Name of the collection in the editor (`\"Products\"`)."
  @callback label() :: String.t()

  @doc "Heroicons name shown next to the collection."
  @callback icon() :: String.t()

  @doc "Fields of the records (`ElementorexCms.Source.Field`)."
  @callback fields() :: [Field.t()]

  @doc "The records a loop shows (see `ElementorexCms.Source.Query`)."
  @callback list(Query.t(), context()) :: [record()]

  @doc "A record by its id (as returned by `id/1`), or `nil`."
  @callback get(id :: String.t(), context()) :: record() | nil

  @doc "The value of a field of a record (default: map and struct keys, `a.b` paths)."
  @callback value(record(), key :: String.t()) :: term()

  @doc "The page of a record, if it has one (offered as *Link to the item*)."
  @callback url(record()) :: String.t() | nil

  @doc "The id of a record (default: its `id` key)."
  @callback id(record()) :: term()

  @doc "A short name of a record, for the editor's preview picker."
  @callback title(record()) :: String.t()

  @doc """
  How many records match the filters and exclusions of the query (its limit and
  offset aside). Loops with numbered pages need it; without it they show
  *Previous* and *Next* only.
  """
  @callback count(Query.t(), context()) :: non_neg_integer()

  @doc """
  The distinct values of a field, for the options of the visitors' filters:
  values or `{value, count}` tuples. Without it they come from the first 500
  records of `list/2` (`ElementorexCms.Source.Query.values/3`).
  """
  @callback values(key :: String.t(), context()) :: [term() | {term(), non_neg_integer()}]

  @optional_callbacks icon: 0,
                      get: 2,
                      value: 2,
                      url: 1,
                      id: 1,
                      title: 1,
                      count: 2,
                      values: 2

  @key ~r/\A[a-z][a-z0-9_]{0,39}\z/

  @doc """
  Builds a source from a module of this behaviour, an Ecto schema or an
  `{ElementorexCms.Source.Ecto, opts}` tuple.
  """
  @spec new(module() | {module(), keyword()} | t()) :: t()
  def new(%__MODULE__{} = source), do: source

  def new({adapter, opts}) when is_atom(adapter) and is_list(opts), do: build({adapter, opts})

  def new(module) when is_atom(module) do
    cond do
      source_module?(module) ->
        build(module)

      ecto_schema?(module) ->
        build({ElementorexCms.Source.Ecto, [schema: module]})

      true ->
        raise ArgumentError,
              "#{inspect(module)} is not a source: implement ElementorexCms.Source, " <>
                "use ElementorexCms.Source.Ecto or pass an Ecto schema"
    end
  end

  defp build(impl) do
    key = to_string(call(impl, :key, []))

    unless key =~ @key do
      raise ArgumentError,
            "invalid source key #{inspect(key)} in #{inspect(impl)}: use lowercase letters, " <>
              "digits and `_`"
    end

    %__MODULE__{
      key: key,
      label: call(impl, :label, []),
      icon: if(implemented?(impl, :icon, 0), do: call(impl, :icon, []), else: "circle-stack"),
      fields: call(impl, :fields, []),
      impl: impl
    }
  end

  @doc "Whether `module` implements this behaviour (or `use`s `ElementorexCms.Source.Ecto`)."
  @spec source_module?(module()) :: boolean()
  def source_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :key, 0) and
      function_exported?(module, :fields, 0) and function_exported?(module, :list, 2)
  end

  defp ecto_schema?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
  end

  @doc "Whether a source key is valid (`\"products\"`, `\"blog_posts\"`)."
  @spec valid_key?(term()) :: boolean()
  def valid_key?(key), do: is_binary(key) and key =~ @key

  @doc "The Ecto schema of a source made with `ElementorexCms.Source.Ecto`, or `nil`."
  @spec schema(t()) :: module() | nil
  def schema(%__MODULE__{impl: {ElementorexCms.Source.Ecto, opts}}), do: opts[:schema]

  def schema(%__MODULE__{impl: module}) when is_atom(module) do
    if function_exported?(module, :__source_opts__, 0), do: module.__source_opts__()[:schema]
  end

  def schema(_source), do: nil

  ## Fields

  @doc """
  The fields of a source whose values can be shown. `@url` (*Link to the item*)
  is added when the source gives its records a page (`url/1`); custom filters
  (`custom: true`) are left out: they filter, they have no value.
  """
  @spec fields(t()) :: [Field.t()]
  def fields(%__MODULE__{} = source) do
    fields = Enum.reject(source.fields, & &1.custom)

    if url?(source),
      do: fields ++ [Field.new("@url", label: "Link to the item", type: :url)],
      else: fields
  end

  @doc "The fields loops and the visitors' filters can filter by, custom filters included."
  @spec filter_fields(t()) :: [Field.t()]
  def filter_fields(%__MODULE__{fields: fields}), do: Enum.filter(fields, & &1.filterable)

  @doc "The keys of the fields the visitors' text search looks in."
  @spec searchable(t()) :: [String.t()]
  def searchable(%__MODULE__{fields: fields}) do
    for field <- fields, field.searchable, not field.custom, do: field.key
  end

  @doc "The field with `key` (`@url` included), or `nil`."
  @spec field(t(), String.t()) :: Field.t() | nil
  def field(%__MODULE__{} = source, key), do: Enum.find(fields(source), &(&1.key == key))

  @doc """
  The field with a role (`:title`, `:image`, `:description`, `:price`), or
  `nil`. Fields marked with `role:` win; otherwise it is guessed from the
  names and types (`name`/`title`, the first image, `description`/`summary`…).
  """
  @spec role(t(), atom()) :: Field.t() | nil
  def role(%__MODULE__{fields: fields}, role) do
    fields = Enum.reject(fields, & &1.custom)
    Enum.find(fields, &(&1.role == role)) || guess_role(fields, role)
  end

  @title_names ~w(name title label headline heading)
  @description_names ~w(description summary excerpt intro body content text details about bio)
  @price_names ~w(price amount cost total)

  defp guess_role(fields, :title) do
    Enum.find(fields, &(&1.key in @title_names)) || Enum.find(fields, &(&1.type == :string))
  end

  defp guess_role(fields, :image), do: Enum.find(fields, &(&1.type == :image))

  defp guess_role(fields, :description) do
    Enum.find(fields, &(&1.key in @description_names and &1.type in [:text, :html, :string])) ||
      Enum.find(fields, &(&1.type in [:text, :html]))
  end

  defp guess_role(fields, :price) do
    Enum.find(fields, fn field ->
      field.type in [:number, :integer] and
        (field.key in @price_names or String.ends_with?(field.key, "_price"))
    end)
  end

  defp guess_role(_fields, _role), do: nil

  ## Records

  @doc "The records of `query` (see `c:list/2`)."
  @spec list(t(), Query.t(), context()) :: [record()]
  def list(%__MODULE__{impl: impl}, %Query{} = query, context) do
    impl |> call(:list, [query, context]) |> List.wrap()
  end

  @doc """
  How many records match `query` (see `c:count/2`), or `nil` when the source
  cannot tell.
  """
  @spec count(t(), Query.t(), context()) :: non_neg_integer() | nil
  def count(%__MODULE__{impl: impl}, %Query{} = query, context) do
    if implemented?(impl, :count, 2), do: call(impl, :count, [query, context])
  end

  @doc """
  The distinct values of a field as `{value, count}` (`count` may be `nil`), in
  order: the options of a filter (see `c:values/2`).
  """
  @spec values(t(), String.t(), context()) :: [{term(), non_neg_integer() | nil}]
  def values(%__MODULE__{impl: impl} = source, key, context) do
    if implemented?(impl, :values, 2) do
      impl
      |> call(:values, [key, context])
      |> Enum.map(fn
        {value, count} -> {value, count}
        value -> {value, nil}
      end)
    else
      source
      |> list(%Query{limit: 500}, context)
      |> Query.values(key, &value(source, &1, &2))
    end
  end

  @doc """
  A record by id. Sources without `get/2` are searched with `list/3` (the first
  200 records).
  """
  @spec get(t(), String.t(), context()) :: record() | nil
  def get(%__MODULE__{impl: impl} = source, id, context) do
    if implemented?(impl, :get, 2) do
      call(impl, :get, [to_string(id), context])
    else
      source
      |> list(%Query{limit: 200}, context)
      |> Enum.find(&(to_string(id(source, &1)) == to_string(id)))
    end
  end

  @doc "The value of field `key` of a record (`@url` gives `url/2`)."
  @spec value(t(), record(), String.t()) :: term()
  def value(%__MODULE__{} = source, record, "@url"), do: url(source, record)

  def value(%__MODULE__{impl: impl}, record, key) do
    if implemented?(impl, :value, 2),
      do: call(impl, :value, [record, key]),
      else: read(record, key)
  end

  @doc "Whether the records of the source have a page (`url/1`)."
  @spec url?(t()) :: boolean()
  def url?(%__MODULE__{impl: impl}) do
    case impl do
      {adapter, opts} ->
        implemented?(impl, :url, 1) and
          (not function_exported?(adapter, :url?, 1) or adapter.url?(opts))

      module ->
        implemented?(module, :url, 1)
    end
  end

  @doc "The page of a record, or `nil`."
  @spec url(t(), record()) :: String.t() | nil
  def url(%__MODULE__{impl: impl} = source, record) do
    if url?(source), do: call(impl, :url, [record])
  end

  @doc "The id of a record."
  @spec id(t(), record()) :: term()
  def id(%__MODULE__{impl: impl}, record) do
    if implemented?(impl, :id, 1), do: call(impl, :id, [record]), else: read(record, "id")
  end

  @doc "A short name of a record (its title field, or its id)."
  @spec title(t(), record()) :: String.t()
  def title(%__MODULE__{impl: impl} = source, record) do
    title =
      cond do
        implemented?(impl, :title, 1) -> call(impl, :title, [record])
        field = role(source, :title) -> value(source, record, field.key)
        true -> nil
      end

    case title do
      text when is_binary(text) and text != "" -> text
      _ -> "##{id(source, record)}"
    end
  end

  @doc """
  Reads `path` (`"name"`, `"category.name"`) from maps and structs, with
  string or atom keys. Atoms are never created: a key whose atom does not exist
  cannot be in the record anyway.
  """
  @spec read(term(), String.t()) :: term()
  def read(record, path) when is_binary(path) do
    path
    |> String.split(".")
    |> Enum.reduce_while(record, fn segment, current ->
      case fetch_key(current, segment) do
        {:ok, value} -> {:cont, value}
        :error -> {:halt, nil}
      end
    end)
  end

  defp fetch_key(%{} = map, key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        {:ok, loaded(value)}

      :error ->
        try do
          case Map.fetch(map, String.to_existing_atom(key)) do
            {:ok, value} -> {:ok, loaded(value)}
            :error -> :error
          end
        rescue
          ArgumentError -> :error
        end
    end
  end

  defp fetch_key(_value, _key), do: :error

  # An association that was not preloaded has no value.
  defp loaded(%{__struct__: struct}) when struct == Ecto.Association.NotLoaded, do: nil
  defp loaded(value), do: value

  ## Dispatch

  defp call({adapter, opts}, fun, args), do: apply(adapter, fun, [opts | args])
  defp call(module, fun, args), do: apply(module, fun, args)

  defp implemented?({adapter, _opts}, fun, arity),
    do: Code.ensure_loaded?(adapter) and function_exported?(adapter, fun, arity + 1)

  defp implemented?(module, fun, arity),
    do: Code.ensure_loaded?(module) and function_exported?(module, fun, arity)
end
