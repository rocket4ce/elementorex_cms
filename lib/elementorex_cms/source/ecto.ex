if Code.ensure_loaded?(Ecto.Query) do
  defmodule ElementorexCms.Source.Ecto do
    @moduledoc """
    A source (`ElementorexCms.Source`) from an Ecto schema. Its fields are read
    from the schema when they are needed, so a field added to the schema (with
    its migration) shows up in the editor without touching anything else.

    The shortest form is the schema itself in the config:

        config :elementorex_cms, sources: [MyApp.Catalog.Product]

    A module gives you options and a place to restrict the records
    (`mix elementorex.gen.source Catalog.Product` writes it):

        defmodule MyAppWeb.Sources.Products do
          use ElementorexCms.Source.Ecto,
            schema: MyApp.Catalog.Product,
            repo: MyApp.Repo,
            label: "Products",
            icon: "shopping-bag",
            path: "/products/:slug",
            except: [:stock],
            fields: [
              price: [defaults: %{"before" => "$", "format" => "number", "decimals" => 0}],
              image_url: [label: "Photo"]
            ]

          # Every list and lookup starts here: only published products.
          @impl true
          def scope(query, _context), do: where(query, [p], p.published)
        end

    ## Filters of your own

    Some filters are not a field with a value: *In stock* is `stock > 0`, *On
    sale* compares two prices. Declare them with `filters:` and write their
    query in `c:filter/4`; the editor offers them next to the fields, in loops
    and in the visitors' filters:

        use ElementorexCms.Source.Ecto,
          schema: MyApp.Catalog.Product,
          filters: [in_stock: [label: "In stock", type: :boolean]]

        @impl true
        def filter(query, "in_stock", "true", _context), do: where(query, [p], p.stock > 0)
        def filter(query, _name, _value, _context), do: query

    ## Options

      * `:schema` (required) - the Ecto schema
      * `:repo` - default: `config :elementorex_cms, repo: ...`, else the first
        of the schema's app `:ecto_repos`
      * `:key` - stored in documents (default: the table name, `"products"`)
      * `:label`, `:icon` - shown in the editor (default: the key in words and
        `"circle-stack"`)
      * `:only` / `:except` - the fields to offer. By default every field
        except `:redact` ones and those whose name suggests a secret
        (`password`, `token`, `secret`, `hash`…), which only `:only` brings back
      * `:fields` - per field: `:label`, `:type`, `:role`, `:sortable`,
        `:filterable` and `:defaults` (see `ElementorexCms.Source.Field`)
      * `:preload` - `belongs_to` / `has_one` associations whose fields are
        offered too (`category.name`)
      * `:search` - the fields the visitors' search box looks in (default:
        every text field)
      * `:filters` - filters with logic of their own, for the visitors' filters
        and the loops: `[in_stock: [label: "In stock", type: :boolean]]`.
        Implement them in `c:filter/4`
      * `:path` - the page of each record, with `:field` placeholders
        (`"/products/:slug"`); offered as *Link to the item*
      * `:order_by` - default order, e.g. `[asc: :name]` (default: newest
        first when there is `inserted_at`)

    ## Field types

    Types come from the schema (`:integer`, `:decimal`, `:boolean`, dates…) and,
    for strings, from the name: `image`, `photo`, `thumbnail`, `avatar`,
    `*_image_url`… are images; `url`, `link`, `website`, `*_url` are links;
    `description`, `body`, `summary`, `content`… are text with paragraphs;
    `*_html` is rich text; `color` is a color. Change any with `fields:`.

    `{ElementorexCms.Source.Ecto, opts}` in the config takes the same options
    (except `scope/2`, which needs a module).
    """

    import Ecto.Query

    alias ElementorexCms.Source
    alias ElementorexCms.Source.Field
    alias ElementorexCms.Source.Query

    @doc """
    The query every list and lookup starts from (default: the whole table).
    Override it to restrict what documents can show; `context` has the `mode`
    (`:public` or `:editor`) and the `data` the host passed.
    """
    @callback scope(Ecto.Queryable.t(), Source.context()) :: Ecto.Queryable.t()

    @doc """
    The query of a filter declared with `filters:` for `value` (a string, or a
    list of strings when the visitor picked several). Default: no filter.
    """
    @callback filter(Ecto.Queryable.t(), name :: String.t(), value :: term(), Source.context()) ::
                Ecto.Queryable.t()

    @doc false
    defmacro __using__(opts) do
      quote bind_quoted: [opts: opts] do
        @behaviour ElementorexCms.Source
        @behaviour ElementorexCms.Source.Ecto

        import Ecto.Query, warn: false

        @elementorex_source Keyword.put(opts, :module, __MODULE__)

        @doc false
        def __source_opts__, do: @elementorex_source

        @impl ElementorexCms.Source
        def key, do: ElementorexCms.Source.Ecto.key(@elementorex_source)

        @impl ElementorexCms.Source
        def label, do: ElementorexCms.Source.Ecto.label(@elementorex_source)

        @impl ElementorexCms.Source
        def icon, do: ElementorexCms.Source.Ecto.icon(@elementorex_source)

        @impl ElementorexCms.Source
        def fields, do: ElementorexCms.Source.Ecto.fields(@elementorex_source)

        @impl ElementorexCms.Source
        def list(query, context),
          do: ElementorexCms.Source.Ecto.list(@elementorex_source, query, context)

        @impl ElementorexCms.Source
        def count(query, context),
          do: ElementorexCms.Source.Ecto.count(@elementorex_source, query, context)

        @impl ElementorexCms.Source
        def values(key, context),
          do: ElementorexCms.Source.Ecto.values(@elementorex_source, key, context)

        @impl ElementorexCms.Source
        def get(id, context), do: ElementorexCms.Source.Ecto.get(@elementorex_source, id, context)

        @impl ElementorexCms.Source
        def value(record, key),
          do: ElementorexCms.Source.Ecto.value(@elementorex_source, record, key)

        @impl ElementorexCms.Source
        def id(record), do: ElementorexCms.Source.Ecto.id(@elementorex_source, record)

        @impl ElementorexCms.Source
        def title(record), do: ElementorexCms.Source.Ecto.title(@elementorex_source, record)

        @impl ElementorexCms.Source.Ecto
        def scope(query, _context), do: query

        @impl ElementorexCms.Source.Ecto
        def filter(query, _name, _value, _context), do: query

        # Without `:path` there is no url/1, so you can write your own.
        if opts[:path] do
          @impl ElementorexCms.Source
          def url(record), do: ElementorexCms.Source.Ecto.url(@elementorex_source, record)

          defoverridable url: 1
        end

        defoverridable key: 0,
                       label: 0,
                       icon: 0,
                       fields: 0,
                       list: 2,
                       count: 2,
                       values: 2,
                       filter: 4,
                       get: 2,
                       value: 2,
                       id: 1,
                       title: 1,
                       scope: 2
      end
    end

    ## Adapter (the options come first)

    @doc false
    def key(opts) do
      case opts[:key] do
        nil ->
          opts
          |> schema!()
          |> then(& &1.__schema__(:source))
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9_]+/, "_")
          |> String.trim("_")

        key ->
          to_string(key)
      end
    end

    @doc false
    def label(opts), do: opts[:label] || Field.humanize(key(opts))

    @doc false
    def icon(opts), do: opts[:icon] || "circle-stack"

    @doc false
    def url?(opts), do: is_binary(opts[:path])

    @sensitive ~r/(password|passw|secret|token|hash|salt|api_?key|private|otp|ssn|cvv|card_number|iban)/

    @doc false
    def fields(opts) do
      schema = schema!(opts)
      overrides = Keyword.get(opts, :fields, [])
      only = opts[:only] && Enum.map(opts[:only], &to_string/1)
      except = opts |> Keyword.get(:except, []) |> Enum.map(&to_string/1)
      redacted = redacted(schema)

      search = opts[:search] && Enum.map(opts[:search], &to_string/1)

      own =
        for name <- schema.__schema__(:fields),
            key = Atom.to_string(name),
            allowed?(key, name in redacted, only, except),
            field = build(schema, name, key, override(overrides, key), true),
            field != nil,
            do: %{field | searchable: if(search, do: key in search, else: field.searchable)}

      associated =
        for assoc <- List.wrap(opts[:preload]),
            is_atom(assoc),
            %{cardinality: :one, related: related} <- [schema.__schema__(:association, assoc)],
            redacted_related = redacted(related),
            name <- related.__schema__(:fields),
            key = "#{assoc}.#{name}",
            allowed?(key, name in redacted_related, only, except),
            not sensitive?(Atom.to_string(name)) or (only != nil and key in only),
            field = build(related, name, key, override(overrides, key), false),
            field != nil,
            do: %{field | searchable: false}

      own ++ associated ++ custom_filters(opts)
    end

    # Filters with logic of their own (`filters:`): filterable, not shown.
    defp custom_filters(opts) do
      for filter <- List.wrap(opts[:filters]) do
        {name, filter_opts} = if is_tuple(filter), do: filter, else: {filter, []}

        Field.new(name,
          label: Keyword.get_lazy(filter_opts, :label, fn -> Field.humanize(name) end),
          type: Keyword.get(filter_opts, :type, :boolean),
          filterable: true,
          searchable: false,
          custom: true
        )
      end
    end

    defp allowed?(key, redacted?, only, except) do
      cond do
        key in except -> false
        only != nil -> key in only
        redacted? -> false
        sensitive?(key) -> false
        true -> true
      end
    end

    defp sensitive?(key), do: key =~ @sensitive

    defp redacted(schema) do
      if function_exported?(schema, :__schema__, 1) do
        try do
          schema.__schema__(:redact_fields)
        rescue
          _ -> []
        end
      else
        []
      end
    end

    defp override(overrides, key) do
      Enum.find_value(overrides, [], fn {name, opts} -> if to_string(name) == key, do: opts end)
    end

    @unsortable [:list, :html]

    defp build(schema, name, key, override, own?) do
      case Keyword.get(override, :type) || field_type(key, schema.__schema__(:type, name)) do
        nil ->
          nil

        type ->
          Field.new(key,
            label: Keyword.get_lazy(override, :label, fn -> Field.humanize(key) end),
            type: type,
            sortable: Keyword.get(override, :sortable, own? and type not in @unsortable),
            filterable: Keyword.get(override, :filterable, own? and type != :list),
            # Text columns only: UUIDs are strings too, but not text to search
            searchable:
              Keyword.get(
                override,
                :searchable,
                own? and type in [:string, :text, :html] and
                  text_column?(schema.__schema__(:type, name))
              ),
            role: Keyword.get(override, :role),
            defaults: Keyword.get(override, :defaults, %{})
          )
      end
    end

    @datetimes [:naive_datetime, :naive_datetime_usec, :utc_datetime, :utc_datetime_usec]
    @scalars [:string, :integer, :float, :decimal, :boolean, :date, :binary_id, :uuid, :id]

    defp field_type(key, type) do
      case primitive(type) do
        :string -> Field.string_type(key)
        primitive when primitive in [:binary_id, :uuid] -> :string
        primitive when primitive in [:integer, :id] -> :integer
        primitive when primitive in [:float, :decimal] -> :number
        :boolean -> :boolean
        :date -> :date
        primitive when primitive in @datetimes -> :datetime
        primitive when primitive in [:time, :time_usec] -> :string
        {:array, inner} -> if inner in @scalars, do: :list
        _other -> nil
      end
    end

    defp primitive(type) do
      Ecto.Type.type(type)
    rescue
      _ -> nil
    end

    @doc false
    def list(opts, %Query{} = query, context) do
      schema = schema!(opts)
      fields = fields(opts)
      repo = repo!(opts)

      ecto_query =
        opts
        |> base(context)
        |> filter(query.filters, schema, fields, {opts, context})
        |> search(query.search, schema, fields)
        |> exclude_ids(query.exclude, schema)
        |> order(query, schema, fields, opts)
        |> limit(^query.limit)
        |> offset(^query.offset)

      ecto_query |> repo.all() |> preload_records(opts)
    end

    @doc false
    def count(opts, %Query{} = query, context) do
      schema = schema!(opts)
      fields = fields(opts)
      repo = repo!(opts)

      opts
      |> base(context)
      |> filter(query.filters, schema, fields, {opts, context})
      |> search(query.search, schema, fields)
      |> exclude_ids(query.exclude, schema)
      # A scope may order its query: the count does not need it
      |> Ecto.Query.exclude(:order_by)
      |> Ecto.Query.exclude(:preload)
      |> repo.aggregate(:count)
    end

    @doc false
    def values(opts, key, context) do
      schema = schema!(opts)
      repo = repo!(opts)

      with %Field{filterable: true, custom: false} <- Enum.find(fields(opts), &(&1.key == key)),
           name when not is_nil(name) <- schema_field(schema, key) do
        opts
        |> base(context)
        |> Ecto.Query.exclude(:order_by)
        |> Ecto.Query.exclude(:preload)
        |> Ecto.Query.exclude(:select)
        |> where([r], not is_nil(field(r, ^name)))
        |> group_by([r], field(r, ^name))
        |> order_by([r], asc: field(r, ^name))
        |> select([r], {field(r, ^name), count()})
        |> limit(200)
        |> repo.all()
      else
        _ -> []
      end
    end

    @doc false
    def get(opts, id, context) do
      schema = schema!(opts)
      pk = primary_key(schema)
      repo = repo!(opts)

      with pk when not is_nil(pk) <- pk,
           {:ok, value} when not is_nil(value) <- cast(schema.__schema__(:type, pk), id),
           %{} = record <-
             opts
             |> base(context)
             |> where([r], field(r, ^pk) == ^value)
             |> limit(1)
             |> repo.one() do
        [record] |> preload_records(opts) |> hd()
      else
        _ -> nil
      end
    end

    @doc false
    def value(_opts, record, key), do: Source.read(record, key)

    @doc false
    def url(opts, record) do
      Regex.replace(~r/:([a-z_][a-z0-9_]*)/, opts[:path], fn _match, name ->
        record
        |> Source.read(name)
        |> case do
          nil -> ""
          value -> value |> to_string() |> URI.encode(&URI.char_unreserved?/1)
        end
      end)
    end

    @doc false
    def id(opts, record) do
      case opts |> schema!() |> primary_key() do
        nil -> nil
        pk -> Map.get(record, pk)
      end
    end

    @doc false
    def title(opts, record) do
      source = %Source{fields: fields(opts), impl: {__MODULE__, opts}}

      case Source.role(source, :title) do
        nil -> "##{id(opts, record)}"
        field -> record |> Source.read(field.key) |> to_string()
      end
    end

    ## Query

    defp base(opts, context) do
      query = from(r in schema!(opts))

      case opts[:module] do
        nil -> query
        module -> module.scope(query, context)
      end
    end

    defp filter(query, filters, schema, fields, {opts, context}) do
      Enum.reduce(filters, query, fn filter, query ->
        with %{field: key, op: op} when key not in [nil, ""] and op not in [nil, ""] <- filter,
             %Field{filterable: true} = field <- Enum.find(fields, &(&1.key == key)) do
          cond do
            field.custom ->
              custom(query, key, op, filter[:value], opts, context)

            name = schema_field(schema, key) ->
              condition(query, name, op, filter[:value], field, schema.__schema__(:type, name))

            true ->
              query
          end
        else
          # An unfinished filter (no field yet) or a field that is gone.
          _ -> query
        end
      end)
    end

    # A filter with logic of its own: the source module's filter/4.
    defp custom(query, key, op, value, opts, context) when op in ~w(eq in custom) do
      case opts[:module] do
        nil -> query
        module -> module.filter(query, key, value, context)
      end
    end

    defp custom(query, _key, _op, _value, _opts, _context), do: query

    # The visitors' search box: the text in any of the searchable columns.
    defp search(query, nil, _schema, _fields), do: query

    defp search(query, %{text: text, fields: keys}, schema, fields) do
      text = text |> to_string() |> String.trim() |> String.downcase()

      names =
        for key <- keys,
            %Field{searchable: true, custom: false} <- [Enum.find(fields, &(&1.key == key))],
            name = schema_field(schema, key),
            name != nil,
            do: name

      if text == "" or names == [] do
        query
      else
        pattern = "%" <> text <> "%"
        [first | rest] = names

        conditions =
          Enum.reduce(
            rest,
            dynamic([r], like(fragment("lower(?)", field(r, ^first)), ^pattern)),
            fn name, conditions ->
              dynamic([r], ^conditions or like(fragment("lower(?)", field(r, ^name)), ^pattern))
            end
          )

        where(query, ^conditions)
      end
    end

    @texts [:string, :text, :html, :url, :image, :color]

    defp condition(query, name, "set", _value, _field, _type),
      do: where(query, [r], not is_nil(field(r, ^name)))

    defp condition(query, name, "unset", _value, _field, _type),
      do: where(query, [r], is_nil(field(r, ^name)))

    defp condition(query, name, "contains", value, %Field{type: type}, ecto_type)
         when type in @texts and is_binary(value) do
      if text_column?(ecto_type),
        do: contains(query, name, value),
        else: where(query, false)
    end

    defp condition(query, name, op, value, %Field{type: type}, ecto_type)
         when op in ~w(eq neq gt gte lt lte) do
      case cast(ecto_type, if(is_binary(value), do: String.trim(value), else: value)) do
        {:ok, cast} when is_binary(cast) and type in @texts ->
          if text_column?(ecto_type),
            do: compare_text(query, name, op, String.downcase(cast)),
            else: compare(query, name, op, cast)

        {:ok, cast} when not is_nil(cast) ->
          compare(query, name, op, cast)

        # A value that is not of the field's type matches nothing.
        _ ->
          where(query, false)
      end
    end

    defp condition(query, name, "in", values, %Field{type: type}, ecto_type) do
      values =
        values
        |> List.wrap()
        |> Enum.take(50)
        |> Enum.flat_map(fn value ->
          case cast(ecto_type, if(is_binary(value), do: String.trim(value), else: value)) do
            {:ok, cast} when not is_nil(cast) -> [cast]
            _ -> []
          end
        end)

      cond do
        values == [] ->
          where(query, false)

        type in @texts and text_column?(ecto_type) and Enum.all?(values, &is_binary/1) ->
          lowered = Enum.map(values, &String.downcase/1)
          where(query, [r], fragment("lower(?)", field(r, ^name)) in ^lowered)

        true ->
          where(query, [r], field(r, ^name) in ^values)
      end
    end

    defp condition(query, _name, _op, _value, _field, _type), do: where(query, false)

    defp contains(query, name, value) do
      pattern = "%" <> String.downcase(to_string(value)) <> "%"
      where(query, [r], like(fragment("lower(?)", field(r, ^name)), ^pattern))
    end

    defp compare(query, name, "eq", value), do: where(query, [r], field(r, ^name) == ^value)

    defp compare(query, name, "neq", value),
      do: where(query, [r], field(r, ^name) != ^value or is_nil(field(r, ^name)))

    defp compare(query, name, "gt", value), do: where(query, [r], field(r, ^name) > ^value)
    defp compare(query, name, "gte", value), do: where(query, [r], field(r, ^name) >= ^value)
    defp compare(query, name, "lt", value), do: where(query, [r], field(r, ^name) < ^value)
    defp compare(query, name, "lte", value), do: where(query, [r], field(r, ^name) <= ^value)

    defp compare_text(query, name, "eq", value),
      do: where(query, [r], fragment("lower(?)", field(r, ^name)) == ^value)

    defp compare_text(query, name, "neq", value) do
      where(
        query,
        [r],
        fragment("lower(?)", field(r, ^name)) != ^value or is_nil(field(r, ^name))
      )
    end

    defp compare_text(query, name, op, value), do: compare(query, name, op, value)

    defp exclude_ids(query, [], _schema), do: query

    defp exclude_ids(query, ids, schema) do
      with pk when not is_nil(pk) <- primary_key(schema),
           [_ | _] = ids <- Enum.flat_map(ids, &cast_id(schema.__schema__(:type, pk), &1)) do
        where(query, [r], field(r, ^pk) not in ^ids)
      else
        _ -> query
      end
    end

    defp cast_id(type, id) do
      case cast(type, id) do
        {:ok, value} when not is_nil(value) -> [value]
        _ -> []
      end
    end

    # Columns of text in the database (lower() and LIKE work on them); UUIDs and
    # enums backed by integers are strings in Elixir but not text there.
    defp text_column?(ecto_type), do: primitive(ecto_type) == :string

    # `:binary_id` takes any binary when cast, but only UUIDs reach the database.
    defp cast(:binary_id, value), do: Ecto.UUID.cast(value)
    defp cast(type, value), do: Ecto.Type.cast(type, value)

    defp order(query, %Query{order_by: key, order: direction}, schema, fields, opts) do
      pk = primary_key(schema)

      with key when is_binary(key) <- key,
           %Field{sortable: true} <- Enum.find(fields, &(&1.key == key)),
           name when not is_nil(name) <- schema_field(schema, key) do
        direction = if direction == :desc, do: :desc, else: :asc
        order_by(query, ^[{direction, name} | tie_breaker(pk)])
      else
        _ -> default_order(query, schema, pk, opts)
      end
    end

    defp default_order(query, schema, pk, opts) do
      cond do
        is_list(opts[:order_by]) ->
          order_by(query, ^opts[:order_by])

        :inserted_at in schema.__schema__(:fields) ->
          order_by(query, ^[{:desc, :inserted_at} | tie_breaker(pk)])

        pk != nil ->
          order_by(query, ^[asc: pk])

        true ->
          query
      end
    end

    # The primary key keeps the order stable between pages of equal values.
    defp tie_breaker(nil), do: []
    defp tie_breaker(pk), do: [asc: pk]

    defp preload_records(records, opts) do
      case opts[:preload] do
        preload when preload in [nil, []] -> records
        preload -> repo!(opts).preload(records, preload)
      end
    end

    ## Schema

    defp schema!(opts) do
      schema = Keyword.fetch!(opts, :schema)

      unless Code.ensure_loaded?(schema) and function_exported?(schema, :__schema__, 1) do
        raise ArgumentError, "#{inspect(schema)} is not an Ecto schema"
      end

      schema
    end

    # The atom of a field of the schema, never creating atoms.
    defp schema_field(schema, key) do
      Enum.find(schema.__schema__(:fields), &(Atom.to_string(&1) == key))
    end

    defp primary_key(schema) do
      case schema.__schema__(:primary_key) do
        [pk | _] -> pk
        [] -> nil
      end
    end

    defp repo!(opts) do
      opts[:repo] || Application.get_env(:elementorex_cms, :repo) || app_repo(opts[:schema]) ||
        raise ArgumentError,
              "no repo for the source of #{inspect(opts[:schema])}: pass `repo:` or " <>
                "`config :elementorex_cms, repo: MyApp.Repo`"
    end

    defp app_repo(schema) do
      case Application.get_application(schema) do
        nil -> nil
        app -> app |> Application.get_env(:ecto_repos, []) |> List.first()
      end
    end
  end
end
