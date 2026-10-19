defmodule Mix.Tasks.Elementorex.Gen.Cms do
  @shortdoc "Generates a CMS: pages edited with the visual editor"

  @moduledoc """
  Generates everything to manage pages built with the visual editor: migration,
  schema, context, an admin list, the editor page and the public page.

      $ mix elementorex.gen.cms Pages Page pages

  The three arguments are the context, the schema and the table, like
  `mix phx.gen.live`. It creates:

    * `priv/repo/migrations/*_create_pages.exs` - `title`, unique `slug`,
      `body` (the document, `jsonb`), `status` and `published_at`
    * `lib/my_app/pages/page.ex` and `lib/my_app/pages.ex`
    * `lib/my_app_web/live/page_live/index.ex` (+ `.html.heex`) - list and
      creation, for your admin
    * `lib/my_app_web/live/page_live/editor.ex` (+ `.html.heex`) - the editor,
      with save and publish
    * `lib/my_app_web/live/page_live/show.ex` (+ `.html.heex`) - the public
      page at `/p/:slug` (only published pages)

  Then add the routes it prints (the admin ones inside your authenticated admin
  `live_session`) and run the migration.

  ## Options

    * `--binary-id` - use UUID primary keys (default: your app's
      `:generators` config)
    * `--public-path` - public prefix (default `/p`)
    * `--admin-path` - admin prefix (default `/admin/<table>`)
    * `--force` - overwrite existing files
  """

  use Mix.Task

  alias Mix.Elementorex

  @switches [
    binary_id: :boolean,
    public_path: :string,
    admin_path: :string,
    force: :boolean,
    dry_run: :boolean
  ]

  @impl true
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: @switches)

    [context, schema, table] =
      case argv do
        [_, _, _] = parts ->
          parts

        _ ->
          Mix.raise(
            "expected: mix elementorex.gen.cms Context Schema table (e.g. Pages Page pages)"
          )
      end

    unless table =~ ~r/\A[a-z][a-z0-9_]*\z/, do: Mix.raise("invalid table name #{inspect(table)}")
    Elementorex.module_parts!(context)
    Elementorex.module_parts!(schema)

    host = Elementorex.host()
    singular = Macro.underscore(schema)

    binary_id =
      Keyword.get_lazy(opts, :binary_id, fn ->
        Application.get_env(host.app, :generators, []) |> Keyword.get(:binary_id, false)
      end)

    assigns = %{
      base: host.base,
      web: host.web,
      repo: "#{host.base}.Repo",
      context: "#{host.base}.#{context}",
      context_name: context,
      schema: "#{host.base}.#{context}.#{schema}",
      schema_name: schema,
      live: "#{host.web}.#{schema}Live",
      table: table,
      singular: singular,
      plural: table,
      binary_id: binary_id,
      public_path: opts[:public_path] || "/p",
      admin_path: opts[:admin_path] || "/admin/#{table}"
    }

    gen = [force: opts[:force] || false, dry_run: opts[:dry_run] || false]
    context_path = Macro.underscore(context)
    live_dir = Path.join(["lib", host.web_path, "live", "#{singular}_live"])
    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")

    files = [
      {"priv/repo/migrations/#{timestamp}_create_#{table}.exs", migration()},
      {"lib/#{host.app_path}/#{context_path}/#{singular}.ex", schema_template()},
      {"lib/#{host.app_path}/#{context_path}.ex", context_template()},
      {Path.join(live_dir, "index.ex"), index_ex()},
      {Path.join(live_dir, "index.html.heex"), index_heex()},
      {Path.join(live_dir, "editor.ex"), editor_ex()},
      {Path.join(live_dir, "editor.html.heex"), editor_heex()},
      {Path.join(live_dir, "show.ex"), show_ex()},
      {Path.join(live_dir, "show.html.heex"), show_heex()}
    ]

    for {path, template} <- files, do: Elementorex.create(path, template, assigns, gen)

    Mix.shell().info("""

    Add the routes to lib/#{host.web_path}/router.ex:

        # inside your authenticated admin scope and live_session
        live "#{assigns.admin_path}", #{schema}Live.Index, :index
        live "#{assigns.admin_path}/:id/edit", #{schema}Live.Editor, :edit

        # public, inside a browser scope
        live "#{assigns.public_path}/:slug", #{schema}Live.Show, :show

    Then run `mix ecto.migrate`. `mix elementorex.install` checks the JS and CSS setup.
    """)
  end

  defp migration do
    ~S'''
    defmodule <%= @repo %>.Migrations.Create<%= Macro.camelize(@table) %> do
      use Ecto.Migration

      def change do
        create table(:<%= @table %><%= if @binary_id do %>, primary_key: false<% end %>) do<%= if @binary_id do %>
          add :id, :binary_id, primary_key: true<% end %>
          add :title, :string, null: false
          add :slug, :string, null: false
          add :body, :map, null: false, default: %{}
          add :status, :string, null: false, default: "draft"
          add :published_at, :utc_datetime

          timestamps(type: :utc_datetime)
        end

        create unique_index(:<%= @table %>, [:slug])
      end
    end
    '''
  end

  defp schema_template do
    ~S'''
    defmodule <%= @schema %> do
      @moduledoc """
      A page built with the visual editor (ElementorexCms). `body` is the document.
      """

      use Ecto.Schema
      import Ecto.Changeset
    <%= if @binary_id do %>
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
    <% end %>
      schema "<%= @table %>" do
        field :title, :string
        field :slug, :string
        field :body, ElementorexCms.Ecto.Document, default: ElementorexCms.Document.new()
        field :status, Ecto.Enum, values: [:draft, :published], default: :draft
        field :published_at, :utc_datetime

        timestamps(type: :utc_datetime)
      end

      @doc false
      def changeset(<%= @singular %>, attrs) do
        <%= @singular %>
        |> cast(attrs, [:title, :slug, :status])
        |> validate_required([:title])
        |> put_slug()
        |> validate_required([:slug])
        |> validate_format(:slug, ~r/\A[a-z0-9]+(-[a-z0-9]+)*\z/, message: "use lowercase letters, digits and hyphens")
        |> unique_constraint(:slug)
        |> put_published_at()
      end

      @doc false
      def body_changeset(<%= @singular %>, body), do: cast(<%= @singular %>, %{body: body}, [:body])

      defp put_slug(changeset) do
        case {get_field(changeset, :slug), get_field(changeset, :title)} do
          {slug, title} when slug in [nil, ""] and is_binary(title) -> put_change(changeset, :slug, slugify(title))
          _ -> changeset
        end
      end

      defp slugify(text) do
        text
        |> :unicode.characters_to_nfd_binary()
        |> String.replace(~r/\p{Mn}/u, "")
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.trim("-")
      end

      defp put_published_at(changeset) do
        if get_change(changeset, :status) == :published,
          do: put_change(changeset, :published_at, DateTime.utc_now(:second)),
          else: changeset
      end
    end
    '''
  end

  defp context_template do
    ~S'''
    defmodule <%= @context %> do
      @moduledoc """
      Pages built with the visual editor.
      """

      import Ecto.Query, warn: false

      alias <%= @repo %>
      alias <%= @schema %>

      @doc "All <%= @plural %>, newest first."
      def list_<%= @plural %> do
        <%= @schema_name %> |> order_by(desc: :updated_at) |> Repo.all()
      end

      @doc "Gets a <%= @singular %>. Raises if it does not exist."
      def get_<%= @singular %>!(id), do: Repo.get!(<%= @schema_name %>, id)

      @doc "The published <%= @singular %> with `slug`, or `nil`."
      def get_published_<%= @singular %>(slug) do
        Repo.get_by(<%= @schema_name %>, slug: slug, status: :published)
      end

      def create_<%= @singular %>(attrs) do
        %<%= @schema_name %>{} |> <%= @schema_name %>.changeset(attrs) |> Repo.insert()
      end

      def update_<%= @singular %>(%<%= @schema_name %>{} = <%= @singular %>, attrs) do
        <%= @singular %> |> <%= @schema_name %>.changeset(attrs) |> Repo.update()
      end

      @doc "Saves the document edited in the visual editor."
      def update_<%= @singular %>_body(%<%= @schema_name %>{} = <%= @singular %>, body) do
        <%= @singular %> |> <%= @schema_name %>.body_changeset(body) |> Repo.update()
      end

      def delete_<%= @singular %>(%<%= @schema_name %>{} = <%= @singular %>), do: Repo.delete(<%= @singular %>)

      def change_<%= @singular %>(%<%= @schema_name %>{} = <%= @singular %>, attrs \\ %{}) do
        <%= @schema_name %>.changeset(<%= @singular %>, attrs)
      end
    end
    '''
  end

  defp index_ex do
    ~S'''
    defmodule <%= @live %>.Index do
      @moduledoc "Admin list of <%= @plural %>, with creation."
      use <%= @web %>, :live_view

      alias <%= @context %>
      alias <%= @schema %>

      @impl true
      def mount(_params, _session, socket) do
        {:ok,
         socket
         |> assign(:page_title, "<%= Macro.camelize(@plural) %>")
         |> assign(:form, to_form(<%= @context_name %>.change_<%= @singular %>(%<%= @schema_name %>{})))
         |> stream(:<%= @plural %>, <%= @context_name %>.list_<%= @plural %>())}
      end

      @impl true
      def handle_event("validate", %{"<%= @singular %>" => params}, socket) do
        changeset = <%= @context_name %>.change_<%= @singular %>(%<%= @schema_name %>{}, params)
        {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
      end

      def handle_event("create", %{"<%= @singular %>" => params}, socket) do
        case <%= @context_name %>.create_<%= @singular %>(params) do
          {:ok, <%= @singular %>} ->
            {:noreply, push_navigate(socket, to: "<%= @admin_path %>/#{<%= @singular %>.id}/edit")}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
      end

      def handle_event("delete", %{"id" => id}, socket) do
        <%= @singular %> = <%= @context_name %>.get_<%= @singular %>!(id)
        {:ok, _} = <%= @context_name %>.delete_<%= @singular %>(<%= @singular %>)
        {:noreply, stream_delete(socket, :<%= @plural %>, <%= @singular %>)}
      end
    end
    '''
  end

  defp index_heex do
    ~S'''
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <div class="mx-auto flex max-w-4xl flex-col gap-6">
        <h1 class="text-2xl font-semibold"><%= Macro.camelize(@plural) %></h1>

        <.form for={@form} id="<%= @singular %>-form" phx-change="validate" phx-submit="create" class="flex flex-wrap items-end gap-3">
          <div class="min-w-64 flex-1"><.input field={@form[:title]} type="text" label="Title" /></div>
          <div class="min-w-48"><.input field={@form[:slug]} type="text" label="Slug (optional)" /></div>
          <.button phx-disable-with="Creating…">New <%= @singular %></.button>
        </.form>

        <div id="<%= @plural %>" phx-update="stream" class="divide-base-200 flex flex-col divide-y">
          <p id="<%= @plural %>-empty" class="hidden py-8 text-center opacity-60 only:block">No <%= @plural %> yet.</p>
          <div :for={{id, <%= @singular %>} <- @streams.<%= @plural %>} id={id} class="flex items-center gap-3 py-3">
            <div class="min-w-0 flex-1">
              <p class="font-medium">{<%= @singular %>.title}</p>
              <p class="text-sm opacity-60"><%= @public_path %>/{<%= @singular %>.slug} · {<%= @singular %>.status}</p>
            </div>
            <.link navigate={"<%= @admin_path %>/#{<%= @singular %>.id}/edit"} class="btn btn-sm">Edit</.link>
            <.link :if={<%= @singular %>.status == :published} href={"<%= @public_path %>/#{<%= @singular %>.slug}"} target="_blank" class="btn btn-sm btn-ghost">View</.link>
            <button type="button" class="btn btn-sm btn-ghost text-error" phx-click="delete" phx-value-id={<%= @singular %>.id} data-confirm="Delete this <%= @singular %>?">
              Delete
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    '''
  end

  defp editor_ex do
    ~S'''
    defmodule <%= @live %>.Editor do
      @moduledoc "Visual editor of a <%= @singular %> (ElementorexCms)."
      use <%= @web %>, :live_view

      alias ElementorexCms.Editor
      alias <%= @context %>

      @editor "<%= @singular %>-editor"

      @impl true
      def mount(%{"id" => id}, _session, socket) do
        <%= @singular %> = <%= @context_name %>.get_<%= @singular %>!(id)

        {:ok,
         socket
         |> assign(:page_title, <%= @singular %>.title)
         |> assign(:<%= @singular %>, <%= @singular %>)
         |> assign(:editor, @editor)
         |> assign(:canvas, ElementorexCms.Canvas.new(stylesheets: [~p"/assets/css/app.css"], body_class: "p-6"))}
      end

      @impl true
      def handle_event("toggle_publish", _params, socket) do
        <%= @singular %> = socket.assigns.<%= @singular %>
        status = if <%= @singular %>.status == :published, do: :draft, else: :published
        {:ok, <%= @singular %>} = <%= @context_name %>.update_<%= @singular %>(<%= @singular %>, %{status: status})
        {:noreply, assign(socket, :<%= @singular %>, <%= @singular %>)}
      end

      @impl true
      def handle_info({Editor, @editor, {:save, document}}, socket) do
        case <%= @context_name %>.update_<%= @singular %>_body(socket.assigns.<%= @singular %>, document) do
          {:ok, <%= @singular %>} ->
            Editor.saved(@editor)
            {:noreply, assign(socket, :<%= @singular %>, <%= @singular %>)}

          {:error, _changeset} ->
            Editor.save_failed(@editor, "Could not save")
            {:noreply, socket}
        end
      end
    end
    '''
  end

  defp editor_heex do
    ~S'''
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <.live_component
        module={ElementorexCms.Editor}
        id={@editor}
        document={@<%= @singular %>.body}
        title={@<%= @singular %>.title}
        subtitle={"<%= @public_path %>/#{@<%= @singular %>.slug}"}
        back="<%= @admin_path %>"
        canvas={@canvas}
      >
        <:status>
          <span class={["exr-pill", @<%= @singular %>.status == :draft && "exr-pill-warn"]}>{@<%= @singular %>.status}</span>
        </:status>
        <:actions>
          <button type="button" class="exr-btn exr-ghost" phx-click="toggle_publish">
            {if @<%= @singular %>.status == :published, do: "Unpublish", else: "Publish"}
          </button>
        </:actions>
      </.live_component>
    </Layouts.app>
    '''
  end

  defp show_ex do
    ~S'''
    defmodule <%= @live %>.Show do
      @moduledoc "Public page of a published <%= @singular %>."
      use <%= @web %>, :live_view

      alias <%= @context %>

      @impl true
      def mount(%{"slug" => slug}, _session, socket) do
        case <%= @context_name %>.get_published_<%= @singular %>(slug) do
          nil -> raise Ecto.NoResultsError, queryable: <%= @schema %>
          <%= @singular %> -> {:ok, socket |> assign(:page_title, <%= @singular %>.title) |> assign(:<%= @singular %>, <%= @singular %>)}
        end
      end
    end
    '''
  end

  defp show_heex do
    ~S'''
    <Layouts.app flash={@flash} current_scope={assigns[:current_scope]}>
      <article id="<%= @singular %>-content" phx-hook="ElementorexRuntime" class="mx-auto max-w-5xl">
        <ElementorexCms.Components.document document={@<%= @singular %>.body} />
      </article>
    </Layouts.app>
    '''
  end
end
