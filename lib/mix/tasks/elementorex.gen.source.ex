defmodule Mix.Tasks.Elementorex.Gen.Source do
  @shortdoc "Makes an Ecto schema a source of dynamic content for the editor"

  @moduledoc """
  Generates a source of dynamic content (`ElementorexCms.Source.Ecto`) for an
  Ecto schema, so the editor can list its records in loops and bind blocks to
  their fields. The schema can come from `mix phx.gen.live`, `mix phx.gen.schema`
  or a migration written by hand.

      $ mix elementorex.gen.source Catalog.Product
      $ mix elementorex.gen.source MyApp.Catalog.Product --path "/products/:slug"

  The name is the schema module, with or without your app's prefix. It creates
  `lib/my_app_web/sources/products.ex` (module `MyAppWeb.Sources.Products`):
  the fields are read from the schema at runtime, so a field you add to the
  schema later (with its migration) shows up in the editor on its own. When the schema has a `published`-like boolean
  (or a `status` with `:published`), the source only gives published records
  to your pages.

  Then register it:

      config :elementorex_cms, sources: [MyAppWeb.Sources.Products]

  ## Options

    * `--path` - the page of each record, like `/products/:slug` (offered as
      *Link to the item*)
    * `--key`, `--label`, `--icon` - stored key (default: the table), name and
      Heroicon in the editor
    * `--repo` - default: the first of your app's `:ecto_repos`
    * `--namespace` - default `MyAppWeb.Sources`
    * `--force` - overwrite an existing file
  """

  use Mix.Task

  alias ElementorexCms.Source.Field
  alias Mix.Elementorex

  @switches [
    path: :string,
    key: :string,
    label: :string,
    icon: :string,
    repo: :string,
    namespace: :string,
    force: :boolean,
    dry_run: :boolean
  ]

  @published ~w(published is_published active is_active visible enabled public listed)a

  @impl true
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: @switches)

    name =
      case argv do
        [name | _] -> name
        [] -> Mix.raise("expected a schema, e.g. mix elementorex.gen.source Catalog.Product")
      end

    Elementorex.module_parts!(name)
    Mix.Task.run("compile")

    host = Elementorex.host()
    schema = schema!(name, host)
    table = schema.__schema__(:source)
    key = opts[:key] || table |> String.downcase() |> String.replace(~r/[^a-z0-9_]+/, "_")

    unless key =~ ~r/\A[a-z][a-z0-9_]{0,39}\z/ do
      Mix.raise("invalid key #{inspect(key)}: use lowercase letters, digits and `_` (--key)")
    end

    namespace = opts[:namespace] || "#{host.web}.Sources"
    Elementorex.module_parts!(namespace)
    module = "#{namespace}.#{Macro.camelize(key)}"
    path = Path.join(["lib", Macro.underscore(namespace), "#{key}.ex"])
    fields = schema.__schema__(:fields)

    assigns = %{
      module: module,
      schema: inspect(schema),
      repo: opts[:repo] || repo(schema, host),
      label: opts[:label] || Field.humanize(key),
      icon: opts[:icon] || "circle-stack",
      path: opts[:path],
      suggested_path: if(:slug in fields, do: "/#{key}/:slug", else: "/#{key}/:id"),
      prices: Enum.filter(fields, &price?(schema, &1)),
      scope: scope(schema, fields),
      table: table
    }

    assigns =
      Map.merge(assigns, %{
        options: options(assigns),
        more: more_options(assigns),
        scope_code: scope_code(assigns)
      })

    Elementorex.create(path, template(), assigns,
      force: opts[:force] || false,
      dry_run: opts[:dry_run] || false
    )

    Mix.shell().info("""

    Register the source (config/config.exs):

        config :elementorex_cms, sources: [#{module}]

    In the editor, the *Loop grid* lists its records and any block inside can
    show their fields. For a page per record, make a template in the editor
    (pass `source="#{key}"` to it) and render it with the record:

        <ElementorexCms.Components.document document={@template.body} record={@record} />
    """)
  end

  defp schema!(name, host) do
    candidates = [Module.concat([name]), Module.concat([host.base, name])]

    Enum.find(candidates, fn module ->
      Code.ensure_loaded?(module) and function_exported?(module, :__schema__, 1)
    end) ||
      Mix.raise(
        "#{name} is not an Ecto schema of this project (tried " <>
          Enum.map_join(candidates, " and ", &inspect/1) <> ")"
      )
  end

  defp repo(schema, host) do
    app = Application.get_application(schema) || host.app

    case Application.get_env(app, :ecto_repos, []) do
      [repo | _] -> inspect(repo)
      [] -> "#{host.base}.Repo"
    end
  end

  defp price?(schema, field) do
    name = Atom.to_string(field)

    schema.__schema__(:type, field) in [:decimal, :float, :integer] and
      (name in ~w(price amount cost total) or String.ends_with?(name, "_price"))
  end

  # Only published records on your pages (the editor shows them all).
  defp scope(schema, fields) do
    cond do
      flag = Enum.find(@published, &(&1 in fields and schema.__schema__(:type, &1) == :boolean)) ->
        "r.#{flag}"

      :status in fields and published_status?(schema.__schema__(:type, :status)) ->
        "r.status == :published"

      true ->
        nil
    end
  end

  defp published_status?(type) do
    case type do
      {:parameterized, {Ecto.Enum, %{mappings: mappings}}} ->
        Keyword.has_key?(mappings, :published)

      {:parameterized, Ecto.Enum, %{mappings: mappings}} ->
        Keyword.has_key?(mappings, :published)

      _ ->
        false
    end
  end

  defp template do
    ~S'''
    defmodule <%= @module %> do
      @moduledoc """
      <%= @label %> as dynamic content of the visual editor (ElementorexCms): the
      *Loop grid* lists them and blocks can show their fields.

      The fields are read from `<%= @schema %>` when they are needed:
      a field added to the schema shows up in the editor on its own.
      """

      use ElementorexCms.Source.Ecto,
    <%= @options %>

      # More options (see ElementorexCms.Source.Ecto):
      #
    <%= @more %>

    <%= @scope_code %>
    end
    '''
  end

  defp options(assigns) do
    [
      "schema: #{assigns.schema}",
      "repo: #{assigns.repo}",
      ~s(label: "#{assigns.label}"),
      ~s(icon: "#{assigns.icon}"),
      assigns.path &&
        ~s(# The page of each record, offered as "Link to the item"\npath: "#{assigns.path}"),
      assigns.prices != [] &&
        "# Settings of new bindings to these fields (see ElementorexCms.Dynamic)\nfields: [" <>
          Enum.map_join(assigns.prices, ", ", &~s(#{&1}: [defaults: %{"format" => "number"}])) <>
          "]"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(",\n")
    |> indent("    ")
  end

  defp more_options(assigns) do
    [
      !assigns.path && ~s(path: "#{assigns.suggested_path}",),
      "except: [:internal_notes],",
      "preload: [:category],",
      ~s(fields: [image_url: [label: "Photo"]])
    ]
    |> Enum.filter(& &1)
    |> Enum.map_join("\n", &"  #     #{&1}")
  end

  defp scope_code(%{scope: nil}) do
    """
      # Every list and lookup starts here. To restrict what pages can show:
      #
      #     @impl true
      #     def scope(query, _context), do: where(query, [r], r.published)\
    """
  end

  defp scope_code(%{scope: scope}) do
    """
      # Every list and lookup starts here: your pages only get published
      # records, the editor shows them all.
      @impl true
      def scope(query, %{mode: :public}), do: where(query, [r], #{scope})
      def scope(query, _context), do: query\
    """
  end

  defp indent(text, prefix) do
    text |> String.split("\n") |> Enum.map_join("\n", &(prefix <> &1))
  end
end
