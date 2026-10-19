defmodule ElementorexCms.Editor do
  @moduledoc """
  The visual editor, as a LiveComponent.

      <.live_component
        module={ElementorexCms.Editor}
        id="page-editor"
        document={@page.body}
        title={@page.title}
        back={~p"/admin/pages"}
        canvas={ElementorexCms.Canvas.new(stylesheets: [~p"/assets/css/app.css"])}
        locale="es"
      >
        <:status><span class="badge">Draft</span></:status>
        <:actions><button phx-click="publish">Publish</button></:actions>
      </.live_component>

  It takes the whole screen (like Elementor): blocks palette and DOM tree on the
  left, the canvas (an iframe with your site's CSS) in the middle, the inspector
  (*Content*, *Style* and *Advanced*) on the right, and a drawer with the HTML,
  CSS and JSON of the selection. Blocks are dragged from the palette into the
  canvas or the tree, moved the same way, and text is edited by double-clicking
  it on the canvas.

  ## Saving

  The editor keeps its own copy of the document; saving is up to the LiveView
  that hosts it. *Save* (or ⌘S) sends

      {ElementorexCms.Editor, editor_id, {:save, document}}

  Persist it and confirm with `saved/1` (or report a problem with
  `save_failed/2`):

      def handle_info({ElementorexCms.Editor, "page-editor", {:save, doc}}, socket) do
        case Pages.update_page(socket.assigns.page, %{body: doc}) do
          {:ok, page} ->
            ElementorexCms.Editor.saved("page-editor")
            {:noreply, assign(socket, :page, page)}

          {:error, _changeset} ->
            ElementorexCms.Editor.save_failed("page-editor", "Could not save")
            {:noreply, socket}
        end
      end

  With `notify_changes`, every change also sends `{:change, document}`.

  ## Attributes

    * `id` (required), `document` (the initial document; later values are
      ignored unless `remount_key` changes)
    * `title`, `subtitle`, `back` (path of the back link)
    * `canvas` - `ElementorexCms.Canvas` configuration
    * `registry` - `ElementorexCms.Registry` (default: `ElementorexCms.Registry.default/0`)
    * `templates` - template modules (default: the configured ones)
    * `media`, `media_context` - see `ElementorexCms.Media`
    * `data` - passed to the blocks as `@ctx.data`
    * `locale` - language of the interface (`"en"`, `"es"`)
    * `notify_changes` - also send `{:change, document}` on every change
    * `fullscreen` - cover the screen (default `true`)
    * `inline_css` - include the editor stylesheet (default `true`; set it to
      `false` if you import `priv/static/elementorex.css` in your bundle)

  Slots: `:status` (next to the title) and `:actions` (before *Save*).

  ## JavaScript

  Register the hook (see the README):

      import {hooks as Elementorex} from "elementorex_cms"
      new LiveSocket("/live", Socket, {hooks: {...Elementorex}})
  """

  use Phoenix.LiveComponent

  alias ElementorexCms.Block
  alias ElementorexCms.Block.Prop
  alias ElementorexCms.Canvas
  alias ElementorexCms.Document
  alias ElementorexCms.Editor.History
  alias ElementorexCms.Editor.StyleFields
  alias ElementorexCms.Editor.UI
  alias ElementorexCms.Heroicons
  alias ElementorexCms.I18n
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer
  alias ElementorexCms.Style
  alias ElementorexCms.Templates

  @css_path Path.expand("../../priv/static/elementorex.css", __DIR__)
  @external_resource @css_path
  @css File.read!(@css_path)

  @devices ~w(desktop tablet mobile)
  @zooms ~w(fit 50 75 100 125 150)

  @doc "The editor stylesheet (inlined by default, see `inline_css`)."
  def css, do: @css

  @doc "Confirms that the document sent with `{:save, doc}` was saved."
  @spec saved(String.t()) :: :ok
  def saved(id), do: send_update(__MODULE__, id: id, __saved__: true)

  @doc "Reports that saving failed, with a message for the user."
  @spec save_failed(String.t(), String.t()) :: :ok
  def save_failed(id, message), do: send_update(__MODULE__, id: id, __save_error__: message)

  @doc "Replaces the document being edited (it becomes a step that can be undone)."
  @spec replace_document(String.t(), map()) :: :ok
  def replace_document(id, document), do: send_update(__MODULE__, id: id, __replace__: document)

  ## Lifecycle

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       doc: nil,
       remount_key: nil,
       selected: nil,
       device: "desktop",
       zoom: "fit",
       tab: "content",
       style_state: "desktop",
       panel: "add",
       code_open: false,
       code_tab: "html",
       preview: false,
       collapsed: MapSet.new(),
       linked: MapSet.new(Map.keys(StyleFields.groups())),
       palette_query: "",
       history: History.new(),
       dirty: false,
       saved_doc: nil,
       pending_save: nil,
       saving: false,
       save_error: nil,
       notice: nil,
       clipboard: nil,
       picker: nil,
       library: nil,
       upload_target: nil
     )
     |> allow_upload(:exr_image,
       accept: ~w(.jpg .jpeg .png .gif .webp .svg .avif),
       max_entries: 1,
       max_file_size: 15_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def update(%{__saved__: true}, socket) do
    saved = socket.assigns.pending_save || socket.assigns.doc

    {:ok,
     assign(socket,
       saved_doc: saved,
       pending_save: nil,
       dirty: socket.assigns.doc != saved,
       saving: false,
       save_error: nil,
       notice: {:ok, "Saved"}
     )}
  end

  def update(%{__save_error__: message}, socket) do
    {:ok, assign(socket, saving: false, pending_save: nil, save_error: message)}
  end

  def update(%{__replace__: document}, socket) do
    doc = Document.normalize(document, socket.assigns.registry)
    {:ok, commit(socket, socket.assigns.doc, doc, "Replace document")}
  end

  def update(assigns, socket) do
    I18n.put_locale(assigns[:locale] || I18n.locale())

    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:title, assigns[:title] || "")
      |> assign(:subtitle, assigns[:subtitle])
      |> assign(:back, assigns[:back])
      |> assign(:status, assigns[:status] || [])
      |> assign(:actions, assigns[:actions] || [])
      |> assign(:canvas, assigns[:canvas] || Canvas.new())
      |> assign(:media, assigns[:media])
      |> assign(:media_context, assigns[:media_context] || %{})
      |> assign(:render_data, assigns[:data] || %{})
      |> assign(:templates, Templates.all(assigns[:templates]))
      |> assign(:notify_changes, assigns[:notify_changes] || false)
      |> assign(:fullscreen, Map.get(assigns, :fullscreen, true))
      |> assign(:inline_css, Map.get(assigns, :inline_css, true))
      |> assign(:locale, I18n.locale())
      |> assign_new(:registry, fn -> assigns[:registry] || Registry.default() end)

    remount? = socket.assigns.doc == nil or assigns[:remount_key] != socket.assigns.remount_key

    socket =
      if remount? do
        socket
        |> assign(
          :doc,
          Document.normalize(assigns[:document] || Document.new(), socket.assigns.registry)
        )
        |> assign(:remount_key, assigns[:remount_key])
        |> assign(:history, History.new())
        |> assign(:selected, nil)
        |> then(&assign(&1, :saved_doc, &1.assigns.doc))
        |> assign(:dirty, false)
        |> then(&if(connected?(&1), do: push_canvas(&1), else: &1))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    I18n.put_locale(assigns.locale)
    UI.editor(assigns)
  end

  ## Canvas and selection

  @impl true
  def handle_event("canvas_ready", _params, socket), do: {:noreply, push_canvas(socket)}

  def handle_event("select", %{"id" => id}, socket) do
    selected = if Document.get(socket.assigns.doc, id), do: id

    {:noreply,
     socket
     |> assign(:selected, selected)
     |> assign(:picker, nil)
     |> assign(:tab, if(selected == root_id(socket), do: "style", else: socket.assigns.tab))
     |> expand_to(selected)}
  end

  def handle_event("deselect", _params, socket),
    do: {:noreply, assign(socket, selected: nil, picker: nil)}

  def handle_event("select_parent", _params, socket) do
    case Document.parent(socket.assigns.doc, socket.assigns.selected || "") do
      {:ok, parent, _index} -> {:noreply, assign(socket, :selected, parent["id"])}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("select_sibling", %{"dir" => dir}, socket) do
    with id when is_binary(id) <- socket.assigns.selected,
         {:ok, parent, index} <- Document.parent(socket.assigns.doc, id),
         sibling when not is_nil(sibling) <-
           Enum.at(parent["children"], if(dir == "up", do: max(index - 1, 0), else: index + 1)) do
      {:noreply, assign(socket, :selected, sibling["id"])}
    else
      _ -> {:noreply, socket}
    end
  end

  ## Structure

  def handle_event("add", %{"type" => type}, socket) do
    doc = socket.assigns.doc
    node = new_node(socket, type)
    {parent_id, index} = insertion_point(socket, type)

    change(socket, label("Add %{block}", type, socket), fn _doc ->
      with {:ok, doc} <- Document.insert(doc, node, parent_id, index, socket.assigns.registry),
           do: {:ok, doc, node["id"]}
    end)
  end

  def handle_event("insert", %{"type" => type, "parent" => parent_id, "index" => index}, socket) do
    node = new_node(socket, type)

    change(socket, label("Add %{block}", type, socket), fn doc ->
      with {:ok, doc} <-
             Document.insert(doc, node, parent_id, to_int(index), socket.assigns.registry),
           do: {:ok, doc, node["id"]}
    end)
  end

  def handle_event("move", %{"id" => id, "parent" => parent_id, "index" => index}, socket) do
    node = Document.get(socket.assigns.doc, id)

    change(socket, label("Move %{block}", node && node["type"], socket), fn doc ->
      with {:ok, doc} <- Document.move(doc, id, parent_id, to_int(index), socket.assigns.registry),
           do: {:ok, doc, id}
    end)
  end

  def handle_event("move_selected", %{"dir" => dir}, socket) do
    with id when is_binary(id) <- socket.assigns.selected,
         {:ok, parent, index} <- Document.parent(socket.assigns.doc, id) do
      target = if dir == "up", do: index - 1, else: index + 2

      if target < 0 or target > length(parent["children"]) do
        {:noreply, socket}
      else
        handle_event("move", %{"id" => id, "parent" => parent["id"], "index" => target}, socket)
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("delete", params, socket) do
    id = params["id"] || socket.assigns.selected
    node = id && Document.get(socket.assigns.doc, id)

    case node && Document.parent(socket.assigns.doc, id) do
      {:ok, parent, index} ->
        next = Enum.at(parent["children"], index + 1) || Enum.at(parent["children"], index - 1)
        next = if next && next["id"] != id, do: next["id"], else: parent["id"]

        change(socket, label("Delete %{block}", node["type"], socket), fn doc ->
          with {:ok, doc} <- Document.remove(doc, id), do: {:ok, doc, next}
        end)

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("duplicate", params, socket) do
    id = params["id"] || socket.assigns.selected
    node = id && Document.get(socket.assigns.doc, id)

    if node && node["type"] != "root" do
      change(socket, label("Duplicate %{block}", node["type"], socket), fn doc ->
        Document.duplicate(doc, id, socket.assigns.registry)
      end)
    else
      {:noreply, socket}
    end
  end

  def handle_event("copy", _params, socket) do
    case Document.get(socket.assigns.doc, socket.assigns.selected) do
      %{"type" => "root"} -> {:noreply, socket}
      nil -> {:noreply, socket}
      node -> {:noreply, assign(socket, clipboard: node, notice: {:ok, "Copied"})}
    end
  end

  def handle_event("paste", _params, socket) do
    case socket.assigns.clipboard do
      nil ->
        {:noreply, socket}

      node ->
        copy = Document.regenerate_ids(node)
        {parent_id, index} = insertion_point(socket, copy["type"])

        change(socket, label("Paste %{block}", copy["type"], socket), fn doc ->
          with {:ok, doc} <- Document.insert(doc, copy, parent_id, index, socket.assigns.registry),
               do: {:ok, doc, copy["id"]}
        end)
    end
  end

  def handle_event("apply_template", %{"key" => key}, socket) do
    case Enum.find(socket.assigns.templates, &(&1.key == key)) do
      nil ->
        {:noreply, socket}

      template ->
        registry = socket.assigns.registry
        nodes = template.nodes.() |> Enum.map(&normalize_node(&1, registry))
        {parent_id, index} = insertion_point(socket, "section")

        change(
          socket,
          I18n.t("Insert template “%{name}”", name: I18n.t(template.label)),
          fn doc ->
            nodes
            |> Enum.with_index()
            |> Enum.reduce_while({:ok, doc}, fn {node, offset}, {:ok, doc} ->
              case Document.insert(doc, node, parent_id, index + offset, registry) do
                {:ok, doc} -> {:cont, {:ok, doc}}
                error -> {:halt, error}
              end
            end)
            |> case do
              {:ok, doc} -> {:ok, doc, List.first(nodes)["id"]}
              error -> error
            end
          end
        )
    end
  end

  ## Inspector

  def handle_event("props", %{"_target" => ["props", field | _], "node" => id} = params, socket) do
    {key, raw} = suffixed_value(params["props"] || %{}, field)

    with node when not is_nil(node) <- Document.get(socket.assigns.doc, id),
         block when not is_nil(block) <- Registry.fetch(socket.assigns.registry, node["type"]),
         %Prop{} = prop <- Block.find_prop(block, key) do
      value = Prop.cast(prop, raw)

      change(
        socket,
        I18n.t("Edit %{field}", field: I18n.t(prop.label)),
        {:prop, id, key},
        fn doc ->
          with {:ok, doc} <- Document.put_prop(doc, id, key, value), do: {:ok, doc, id}
        end
      )
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("props", _params, socket), do: {:noreply, socket}

  def handle_event("inline", %{"id" => id, "prop" => key, "value" => value}, socket) do
    with node when not is_nil(node) <- Document.get(socket.assigns.doc, id),
         block when not is_nil(block) <- Registry.fetch(socket.assigns.registry, node["type"]),
         %Prop{} = prop <- Block.find_prop(block, key) do
      value = Prop.cast(prop, value)

      change(socket, I18n.t("Edit %{field}", field: I18n.t(prop.label)), fn doc ->
        with {:ok, doc} <- Document.put_prop(doc, id, key, value), do: {:ok, doc, id}
      end)
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("list_add", %{"prop" => key}, socket) do
    update_list(socket, key, fn prop, items -> items ++ [Prop.new_item(prop)] end)
  end

  def handle_event("list_remove", %{"prop" => key, "index" => index}, socket) do
    update_list(socket, key, fn _prop, items -> List.delete_at(items, to_int(index)) end)
  end

  def handle_event("list_duplicate", %{"prop" => key, "index" => index}, socket) do
    update_list(socket, key, fn prop, items ->
      index = to_int(index)

      case Enum.at(items, index) do
        nil ->
          items

        item ->
          List.insert_at(items, index + 1, Prop.cast(prop, [Map.delete(item, "id")]) |> hd())
      end
    end)
  end

  def handle_event("list_move", %{"prop" => key, "index" => index, "dir" => dir}, socket) do
    update_list(socket, key, fn _prop, items ->
      index = to_int(index)
      target = if dir == "up", do: index - 1, else: index + 1

      if target < 0 or target >= length(items) do
        items
      else
        {item, rest} = List.pop_at(items, index)
        List.insert_at(rest, target, item)
      end
    end)
  end

  def handle_event("style", %{"_target" => ["style", field], "node" => id} = params, socket) do
    state = socket.assigns.style_state
    {property, raw} = suffixed_value(params["style"] || %{}, field)
    value = raw |> to_string() |> String.trim() |> with_unit(property)
    properties = Map.get(StyleFields.groups(), property, [property])

    properties =
      case Enum.find(StyleFields.groups(), fn {_group, props} -> property in props end) do
        {group, props} ->
          if MapSet.member?(socket.assigns.linked, group), do: props, else: properties

        nil ->
          properties
      end

    change(socket, I18n.t("Edit style"), {:style, id, state, property}, fn doc ->
      Enum.reduce_while(properties, {:ok, doc}, fn property, {:ok, doc} ->
        case Document.put_style(doc, id, state, property, value) do
          {:ok, doc} -> {:cont, {:ok, doc}}
          {:error, :invalid} -> {:halt, {:error, :invalid_style}}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, doc} -> {:ok, doc, id}
        error -> error
      end
    end)
  end

  def handle_event("style", _params, socket), do: {:noreply, socket}

  def handle_event("style_pick", %{"property" => property, "value" => value}, socket) do
    handle_event(
      "style",
      %{
        "_target" => ["style", property],
        "node" => socket.assigns.selected,
        "style" => %{property => value}
      },
      socket
    )
  end

  def handle_event("toggle_link", %{"group" => group}, socket) do
    linked = socket.assigns.linked

    linked =
      if MapSet.member?(linked, group),
        do: MapSet.delete(linked, group),
        else: MapSet.put(linked, group)

    {:noreply, assign(socket, :linked, linked)}
  end

  def handle_event("clear_style", _params, socket) do
    id = socket.assigns.selected
    state = socket.assigns.style_state

    change(socket, I18n.t("Reset style"), fn doc ->
      with {:ok, doc} <-
             Document.update(doc, id, fn node ->
               Map.update(node, "style", %{}, &Map.delete(&1 || %{}, state))
             end),
           do: {:ok, doc, id}
    end)
  end

  def handle_event("attrs", %{"_target" => ["attrs", key | _], "node" => id} = params, socket) do
    value =
      case {key, get_in(params, ["attrs", key])} do
        {"hide_on", values} -> values |> List.wrap() |> Enum.reject(&(&1 == ""))
        {"animation_delay", value} -> to_int(value)
        {_key, value} -> value
      end

    change(socket, I18n.t("Edit advanced settings"), {:attrs, id, key}, fn doc ->
      with {:ok, doc} <- Document.put_attr(doc, id, key, value), do: {:ok, doc, id}
    end)
  end

  def handle_event("attrs", _params, socket), do: {:noreply, socket}

  def handle_event("value_set", %{"prop" => key, "value" => value} = params, socket) do
    set_value(socket, %{prop: key, index: params["index"], field: params["field"]}, value)
  end

  ## Icon picker

  def handle_event("picker_open", %{"prop" => key} = params, socket) do
    {:noreply,
     assign(socket, :picker, %{
       prop: key,
       index: params["index"],
       field: params["field"],
       query: ""
     })}
  end

  def handle_event("picker_search", %{"q" => query}, socket) do
    {:noreply, update(socket, :picker, &(&1 && %{&1 | query: query}))}
  end

  def handle_event("picker_close", _params, socket), do: {:noreply, assign(socket, :picker, nil)}

  def handle_event("picker_pick", %{"name" => name}, socket) do
    case socket.assigns.picker do
      nil -> {:noreply, socket}
      picker -> socket |> assign(:picker, nil) |> set_value(picker, name)
    end
  end

  ## Media

  def handle_event("upload_target", %{"prop" => key} = params, socket) do
    {:noreply,
     assign(socket, :upload_target, %{
       prop: key,
       index: params["index"],
       field: params["field"],
       style: params["style"]
     })}
  end

  def handle_event("upload_validate", _params, socket), do: {:noreply, socket}

  def handle_event("library_open", %{"prop" => key} = params, socket) do
    target = %{prop: key, index: params["index"], field: params["field"], style: params["style"]}

    {:noreply,
     assign(socket, :library, %{target: target, query: "", items: library_items(socket, nil)})}
  end

  def handle_event("library_search", %{"q" => query}, socket) do
    {:noreply,
     update(socket, :library, &(&1 && %{&1 | query: query, items: library_items(socket, query)}))}
  end

  def handle_event("library_close", _params, socket),
    do: {:noreply, assign(socket, :library, nil)}

  def handle_event("library_pick", %{"url" => url}, socket) do
    case socket.assigns.library do
      nil -> {:noreply, socket}
      %{target: target} -> socket |> assign(:library, nil) |> set_value(target, url)
    end
  end

  ## View

  def handle_event("device", %{"device" => device}, socket) when device in @devices do
    style_state = if socket.assigns.style_state == "hover", do: "hover", else: device
    {:noreply, assign(socket, device: device, style_state: style_state)}
  end

  def handle_event("zoom", %{"zoom" => zoom}, socket) when zoom in @zooms,
    do: {:noreply, assign(socket, :zoom, zoom)}

  def handle_event("zoom_step", %{"dir" => dir}, socket) do
    steps = ~w(50 75 100 125 150)
    current = if socket.assigns.zoom == "fit", do: "100", else: socket.assigns.zoom
    index = Enum.find_index(steps, &(&1 == current)) || 2
    index = if dir == "in", do: min(index + 1, 4), else: max(index - 1, 0)
    {:noreply, assign(socket, :zoom, Enum.at(steps, index))}
  end

  def handle_event("tab", %{"tab" => tab}, socket) when tab in ~w(content style advanced),
    do: {:noreply, assign(socket, :tab, tab)}

  def handle_event("style_state", %{"state" => state}, socket) when state in ~w(normal hover) do
    {:noreply,
     assign(socket, :style_state, if(state == "hover", do: "hover", else: socket.assigns.device))}
  end

  def handle_event("panel", %{"panel" => panel}, socket)
      when panel in ~w(add templates history shortcuts),
      do: {:noreply, assign(socket, :panel, panel)}

  def handle_event("toggle_code", _params, socket),
    do: {:noreply, update(socket, :code_open, &(!&1))}

  def handle_event("code_tab", %{"tab" => tab}, socket) when tab in ~w(html css json),
    do: {:noreply, assign(socket, code_tab: tab, code_open: true)}

  def handle_event("toggle_preview", _params, socket),
    do: {:noreply, update(socket, :preview, &(!&1))}

  def handle_event("tree_toggle", %{"id" => id}, socket) do
    collapsed = socket.assigns.collapsed

    collapsed =
      if MapSet.member?(collapsed, id),
        do: MapSet.delete(collapsed, id),
        else: MapSet.put(collapsed, id)

    {:noreply, assign(socket, :collapsed, collapsed)}
  end

  def handle_event("tree_collapse_all", _params, socket) do
    containers =
      socket.assigns.doc
      |> Document.nodes()
      |> Enum.filter(&(&1["children"] != [] and &1["type"] != "root"))
      |> MapSet.new(& &1["id"])

    collapsed = if MapSet.size(socket.assigns.collapsed) > 0, do: MapSet.new(), else: containers
    {:noreply, assign(socket, :collapsed, collapsed)}
  end

  def handle_event("palette_search", %{"q" => query}, socket),
    do: {:noreply, assign(socket, :palette_query, query)}

  def handle_event("dismiss_notice", _params, socket),
    do: {:noreply, assign(socket, :notice, nil)}

  ## History and saving

  def handle_event("undo", _params, socket) do
    case History.undo(socket.assigns.history, socket.assigns.doc) do
      {:ok, doc, history} -> {:noreply, restored(socket, doc, history)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("redo", _params, socket) do
    case History.redo(socket.assigns.history, socket.assigns.doc) do
      {:ok, doc, history} -> {:noreply, restored(socket, doc, history)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("restore", %{"index" => index}, socket) do
    case History.restore(socket.assigns.history, socket.assigns.doc, to_int(index)) do
      {:ok, doc, history} -> {:noreply, restored(socket, doc, history)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("save", _params, socket) do
    send(self(), {__MODULE__, socket.assigns.id, {:save, socket.assigns.doc}})
    {:noreply, assign(socket, saving: true, save_error: nil, pending_save: socket.assigns.doc)}
  end

  # Forms of the inspector submit on Enter; nothing to do.
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  ## Uploads

  @doc false
  def handle_progress(:exr_image, entry, socket) do
    if entry.done? do
      target = socket.assigns.upload_target
      media = socket.assigns.media

      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          upload = %{
            path: path,
            filename: entry.client_name,
            content_type: entry.client_type,
            size: entry.client_size
          }

          case media && media.store(upload, socket.assigns.media_context) do
            {:ok, %{url: url}} -> {:ok, {:ok, url}}
            {:error, reason} -> {:ok, {:error, reason}}
            nil -> {:ok, {:error, :no_media}}
          end
        end)

      case {result, target} do
        {{:ok, url}, %{} = target} ->
          socket |> assign(:upload_target, nil) |> set_value(target, url)

        {{:error, _reason}, _target} ->
          {:noreply, assign(socket, :notice, {:error, "The image could not be uploaded"})}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  ## Helpers

  # Applies `fun` to the document and records the change. `fun` returns
  # `{:ok, doc}`, `{:ok, doc, id_to_select}` or `{:error, reason}`.
  defp change(socket, label, key \\ nil, fun) do
    old = socket.assigns.doc

    case fun.(old) do
      {:ok, doc} ->
        {:noreply, commit(socket, old, doc, label, key)}

      {:ok, doc, select} ->
        {:noreply,
         socket |> commit(old, doc, label, key) |> assign(:selected, select) |> expand_to(select)}

      {:error, reason} ->
        {:noreply, assign(socket, :notice, {:error, error_message(reason)})}
    end
  end

  defp commit(socket, old, doc, label, key \\ nil)
  defp commit(socket, old, old, _label, _key), do: socket

  defp commit(socket, old, doc, label, key) do
    socket
    |> assign(:doc, doc)
    |> assign(:history, History.push(socket.assigns.history, old, label, key))
    |> assign(:dirty, doc != socket.assigns.saved_doc)
    |> assign(:notice, nil)
    |> notify_change()
    |> push_canvas()
  end

  defp restored(socket, doc, history) do
    selected = if Document.get(doc, socket.assigns.selected), do: socket.assigns.selected

    socket
    |> assign(
      doc: doc,
      history: history,
      selected: selected,
      dirty: doc != socket.assigns.saved_doc
    )
    |> notify_change()
    |> push_canvas()
  end

  defp notify_change(%{assigns: %{notify_changes: true}} = socket) do
    send(self(), {__MODULE__, socket.assigns.id, {:change, socket.assigns.doc}})
    socket
  end

  defp notify_change(socket), do: socket

  defp push_canvas(socket) do
    %{doc: doc, registry: registry, id: id, render_data: data} = socket.assigns
    ctx = Renderer.context(mode: :editor, registry: registry, data: data)

    html = doc |> Document.root() |> Renderer.render_node(ctx) |> Renderer.to_string_html()

    push_event(socket, "exr:#{id}:render", %{html: html, css: Style.css(doc, mode: :editor)})
  end

  defp update_list(socket, key, fun) do
    id = socket.assigns.selected

    with node when not is_nil(node) <- Document.get(socket.assigns.doc, id),
         block when not is_nil(block) <- Registry.fetch(socket.assigns.registry, node["type"]),
         %Prop{type: :list} = prop <- Block.find_prop(block, key) do
      items = Prop.cast(prop, Map.get(node["props"] || %{}, key, Prop.default(prop)))
      items = fun.(prop, items) |> Enum.take(prop.max_items)

      change(socket, I18n.t("Edit %{field}", field: I18n.t(prop.label)), fn doc ->
        with {:ok, doc} <- Document.put_prop(doc, id, key, items), do: {:ok, doc, id}
      end)
    else
      _ -> {:noreply, socket}
    end
  end

  # Sets the value chosen in the icon picker, the media library or an upload:
  # a prop, a field of a list item or a style property (background image).
  defp set_value(socket, %{style: property} = target, url)
       when is_binary(property) and property != "" do
    _ = target

    handle_event(
      "style",
      %{
        "_target" => ["style", property],
        "node" => socket.assigns.selected,
        "style" => %{property => "url(#{url})"}
      },
      socket
    )
  end

  defp set_value(socket, target, value) do
    id = socket.assigns.selected

    with node when not is_nil(node) <- Document.get(socket.assigns.doc, id),
         block when not is_nil(block) <- Registry.fetch(socket.assigns.registry, node["type"]),
         %Prop{} = prop <- Block.find_prop(block, target.prop) do
      case {prop.type, target.index} do
        {:list, index} when is_binary(index) ->
          update_list(socket, prop.key, fn prop, items ->
            List.update_at(items, to_int(index), fn item ->
              field = Enum.find(prop.fields, &(&1.key == target.field))
              if field, do: Map.put(item, field.key, Prop.cast(field, value)), else: item
            end)
          end)

        _ ->
          value = Prop.cast(prop, value)

          change(socket, I18n.t("Edit %{field}", field: I18n.t(prop.label)), fn doc ->
            with {:ok, doc} <- Document.put_prop(doc, id, prop.key, value), do: {:ok, doc, id}
          end)
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp new_node(socket, type) do
    Document.node(type, %{}, registry: socket.assigns.registry)
  end

  defp normalize_node(node, registry) do
    %{"version" => 1, "root" => Document.node("root", %{}, children: [node])}
    |> Document.normalize(registry)
    |> Document.root()
    |> Map.fetch!("children")
    |> hd()
  end

  # Where a block added from the palette (click) or pasted goes: inside the
  # selected container, after the selected block, or at the end of the document.
  defp insertion_point(socket, type) do
    %{doc: doc, selected: selected, registry: registry} = socket.assigns
    root = Document.root(doc)
    node = selected && Document.get(doc, selected)

    cond do
      node == nil ->
        {root["id"], length(root["children"])}

      Registry.accepts?(registry, node["type"], type) and
          (node["type"] == "root" or node["children"] == []) ->
        {node["id"], length(node["children"])}

      true ->
        case Document.parent(doc, selected) do
          {:ok, parent, index} ->
            if Registry.accepts?(registry, parent["type"], type),
              do: {parent["id"], index + 1},
              else: {root["id"], length(root["children"])}

          :error ->
            {root["id"], length(root["children"])}
        end
    end
  end

  defp expand_to(socket, nil), do: socket

  defp expand_to(socket, id) do
    ids = socket.assigns.doc |> Document.path(id) |> Enum.map(& &1["id"]) |> Enum.drop(-1)
    update(socket, :collapsed, &Enum.reduce(ids, &1, fn id, acc -> MapSet.delete(acc, id) end))
  end

  defp root_id(socket), do: Document.root(socket.assigns.doc)["id"]

  defp label(text, type, socket) do
    block = Registry.fetch(socket.assigns.registry, type)
    I18n.t(text, block: I18n.t((block && block.meta().label) || to_string(type)))
  end

  # Colors have three inputs (swatches, picker, text) named `key`, `key__swatch`
  # and `key__picker`; the value is the one of the input that changed.
  defp suffixed_value(params, field) do
    key = String.replace(field, ~r/__(swatch|picker)\z/, "")
    {key, Map.get(params, field)}
  end

  defp with_unit(value, property) do
    if property in StyleFields.pixel_properties() and value =~ ~r/\A-?\d+(\.\d+)?\z/ and
         value != "0",
       do: value <> "px",
       else: value
  end

  defp library_items(socket, query) do
    media = socket.assigns.media

    if media && Code.ensure_loaded?(media) && function_exported?(media, :list, 2) do
      media.list([search: query], socket.assigns.media_context)
    else
      []
    end
  end

  defp error_message(:not_allowed), do: "That block cannot go there"
  defp error_message(:into_itself), do: "A block cannot go inside itself"
  defp error_message(:too_many_nodes), do: "The document has too many blocks"
  defp error_message(:too_deep), do: "Too many levels of nesting"
  defp error_message(:invalid_style), do: "That value is not valid"
  defp error_message(:root), do: "The document itself cannot be changed that way"
  defp error_message(_reason), do: "That change could not be made"

  defp to_int(value) when is_integer(value), do: value

  defp to_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp to_int(_value), do: 0

  @doc false
  def heroicon_names, do: Heroicons.names()
end
