defmodule ElementorexCms.Editor.UI do
  @moduledoc false
  # Markup of the editor (`ElementorexCms.Editor` renders `editor/1`). Classes
  # are prefixed `exr-` and styled by priv/static/elementorex.css, so the editor
  # looks the same in any host app, with or without Tailwind.

  use Phoenix.Component

  import ElementorexCms.Editor.Controls, only: [i: 1, prop: 1, style_field: 1]

  alias ElementorexCms.Block
  alias ElementorexCms.Block.Prop
  alias ElementorexCms.Canvas
  alias ElementorexCms.Document
  alias ElementorexCms.Dynamic
  alias ElementorexCms.Editor
  alias ElementorexCms.Editor.Code
  alias ElementorexCms.Editor.History
  alias ElementorexCms.Editor.StyleFields
  alias ElementorexCms.Heroicons
  alias ElementorexCms.I18n
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer
  alias ElementorexCms.Source
  alias ElementorexCms.Sources
  alias ElementorexCms.Style
  alias Phoenix.LiveView.JS

  @categories %{
    layout: "Structure",
    basic: "Basic",
    components: "daisyUI",
    charts: "Charts",
    media: "Media",
    dynamic: "Dynamic",
    advanced: "Advanced"
  }

  @device_icons [
    {"desktop", "computer-desktop", "Desktop"},
    {"tablet", "device-tablet", "Tablet"},
    {"mobile", "device-phone-mobile", "Mobile"}
  ]

  defp t(text, bindings \\ []), do: I18n.t(text, bindings)

  ## Root

  def editor(assigns) do
    doc = assigns.doc
    node = Document.get(doc, assigns.selected)
    block = node && Registry.fetch(assigns.registry, node["type"])

    assigns =
      assigns
      |> assign(:root, Document.root(doc))
      |> assign(:node, node)
      |> assign(:block, block)
      |> assign(:path, if(node, do: Document.path(doc, node["id"]), else: []))
      |> assign(:width, Map.get(assigns.canvas.widths, assigns.device))
      |> assign(:dyn, dynamic_info(assigns, node))

    ~H"""
    <div
      id={@id}
      class={[
        "exr-editor",
        @fullscreen && "exr-fullscreen",
        @preview && "exr-is-preview",
        @code_open && "exr-has-code"
      ]}
      phx-hook="ElementorexEditor"
      phx-target={@myself}
      data-canvas={Canvas.to_json(@canvas)}
      data-blocks={blocks_json(@registry)}
      data-labels={labels_json()}
      data-selected={@selected}
      data-device={@device}
      data-zoom={@zoom}
      data-width={@width}
      data-preview={to_string(@preview)}
      data-dirty={to_string(@dirty)}
      data-root={@root["id"]}
    >
      <style :if={@inline_css}>
        <%= Phoenix.HTML.raw(Editor.css()) %>
      </style>
      <.topbar {top_assigns(assigns)} />
      <div class="exr-body">
        <.rail panel={@panel} target={@myself} />
        <aside class="exr-left" aria-label={t("Components and structure")}>
          <%= case @panel do %>
            <% "templates" -> %>
              <.templates_panel templates={@templates} target={@myself} />
            <% "history" -> %>
              <.history_panel history={@history} target={@myself} />
            <% "shortcuts" -> %>
              <.shortcuts_panel />
            <% _add -> %>
              <.palette
                id={@id}
                registry={@registry}
                query={@palette_query}
                dynamic?={not Sources.empty?(@sources)}
                target={@myself}
              />
              <div class="exr-resizer" data-exr-resizer title={t("Drag to resize")}></div>
              <.tree
                root={@root}
                selected={@selected}
                collapsed={@collapsed}
                registry={@registry}
                sources={@sources}
                target={@myself}
              />
          <% end %>
        </aside>
        <section class="exr-stage" aria-label={t("Canvas")}>
          <div class="exr-viewport" data-exr-viewport>
            <div id={"#{@id}-frame"} class="exr-frame" phx-update="ignore" data-exr-frame></div>
            <.empty_canvas
              :if={Document.empty?(@doc) and not @preview}
              templates={@templates}
              target={@myself}
            />
          </div>
          <.pathbar
            :if={@path != [] and not @preview}
            path={@path}
            registry={@registry}
            target={@myself}
          />
          <.notice :if={@notice || @save_error} notice={@notice} error={@save_error} target={@myself} />
          <.codebar
            :if={@code_open}
            id={@id}
            tab={@code_tab}
            doc={@doc}
            node={@node}
            block={@block}
            registry={@registry}
            ctx={Editor.render_context(assigns, :public)}
            target={@myself}
          />
        </section>
        <aside class="exr-inspector" aria-label={t("Inspector")}>
          <.inspector
            id={@id}
            node={@node}
            block={@block}
            root={@root}
            tab={@tab}
            device={@device}
            style_state={@style_state}
            linked={@linked}
            media={@media}
            uploads={@uploads}
            target={@myself}
            doc={@doc}
            dyn={@dyn}
          />
        </aside>
      </div>
      <.icon_picker :if={@picker} picker={@picker} target={@myself} />
      <.library :if={@library} library={@library} target={@myself} />
      <.field_picker
        :if={@field_picker && @block}
        picker={@field_picker}
        block={@block}
        dyn={@dyn}
        target={@myself}
      />
    </div>
    """
  end

  # What the inspector needs for dynamic content: the sources, the source of
  # the items the selected node is rendered with and the site values of `data`.
  defp dynamic_info(assigns, node) do
    item_source =
      node &&
        Dynamic.item_source(
          assigns.doc,
          node["id"],
          assigns.sources,
          assigns.doc_source,
          assigns.registry
        )

    own_source =
      node && Dynamic.field_source(assigns.doc, node["id"], assigns.sources, assigns.registry)

    %{
      sources: Sources.list(assigns.sources),
      item_source: item_source,
      own_source: own_source,
      site_fields: Dynamic.site_fields(assigns.render_data),
      bindings: (node && node["dynamic"]) || %{},
      loops: ElementorexCms.Filters.loop_choices(assigns.doc, assigns.registry, assigns.sources)
    }
  end

  defp top_assigns(assigns) do
    assigns
    |> Map.take([
      :id,
      :title,
      :subtitle,
      :back,
      :status,
      :actions,
      :dirty,
      :saving,
      :device,
      :zoom,
      :width,
      :history,
      :preview,
      :code_open,
      :myself,
      :preview_records,
      :preview_record
    ])
    |> Map.put(:preview_source, Sources.fetch(assigns.sources, assigns.doc_source))
  end

  defp blocks_json(registry) do
    registry
    |> Registry.list()
    |> Map.new(fn block ->
      meta = block.meta()

      {meta.type,
       %{
         label: t(meta.label),
         icon: Heroicons.svg(meta.icon, "outline"),
         container: meta.container
       }}
    end)
    |> Jason.encode!()
  end

  defp labels_json do
    Jason.encode!(%{
      drop: t("Drop: %{block}"),
      dropHere: t("Drop here"),
      parent: t("Select parent"),
      duplicate: t("Duplicate"),
      delete: t("Delete"),
      move: t("Drag to move"),
      bold: t("Bold"),
      italic: t("Italic"),
      underline: t("Underline"),
      strike: t("Strikethrough"),
      link: t("Link"),
      linkPrompt: t("Link URL (empty to remove it)"),
      clear: t("Clear formatting"),
      unsaved: t("There are unsaved changes. Leave anyway?"),
      copied: t("Copied")
    })
  end

  ## Top bar

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :back, :string, default: nil
  attr :status, :list, default: []
  attr :actions, :list, default: []
  attr :dirty, :boolean, required: true
  attr :saving, :boolean, required: true
  attr :device, :string, required: true
  attr :zoom, :string, required: true
  attr :width, :integer, required: true
  attr :history, History, required: true
  attr :preview, :boolean, required: true
  attr :code_open, :boolean, required: true
  attr :myself, :any, required: true
  attr :preview_source, :any, default: nil
  attr :preview_records, :list, default: []
  attr :preview_record, :any, default: nil

  defp topbar(assigns) do
    ~H"""
    <header class="exr-top">
      <div class="exr-top-left">
        <.link
          :if={@back}
          navigate={@back}
          class="exr-icon-btn exr-icon-btn-lg"
          title={t("Back")}
          data-exr-leave
        >
          <.i name="arrow-left" />
        </.link>
        <div class="exr-doc-title">
          <b>{@title}</b>
          <small :if={@subtitle}>{@subtitle}</small>
        </div>
        <div class="exr-top-status">
          {render_slot(@status)}
          <span :if={@dirty} class="exr-pill exr-pill-warn">{t("Unsaved changes")}</span>
        </div>
      </div>

      <div class="exr-top-center">
        <div class="exr-seg exr-devices" role="radiogroup" aria-label={t("Device")}>
          <button
            :for={{device, icon, label} <- device_icons()}
            type="button"
            class={["exr-seg-item", @device == device && "is-on"]}
            phx-click="device"
            phx-value-device={device}
            phx-target={@myself}
            title={t(label)}
            aria-pressed={to_string(@device == device)}
          >
            <.i name={icon} />
          </button>
        </div>
        <span class="exr-readout" title={t("Canvas width")}><em>W</em>{@width}<em>px</em></span>
        <div class="exr-zoom">
          <button
            type="button"
            class="exr-icon-btn"
            phx-click="zoom_step"
            phx-value-dir="out"
            phx-target={@myself}
            title={t("Zoom out")}
          >
            <.i name="minus" />
          </button>
          <form id={"#{@id}-zoom"} phx-change="zoom" phx-target={@myself}>
            <select name="zoom" class="exr-zoom-select" aria-label={t("Zoom")}>
              <option :for={zoom <- ~w(fit 50 75 100 125 150)} value={zoom} selected={@zoom == zoom}>
                {if(zoom == "fit", do: t("Fit"), else: "#{zoom}%")}
              </option>
            </select>
          </form>
          <button
            type="button"
            class="exr-icon-btn"
            phx-click="zoom_step"
            phx-value-dir="in"
            phx-target={@myself}
            title={t("Zoom in")}
          >
            <.i name="plus" />
          </button>
        </div>
        <form
          :if={@preview_source}
          id={"#{@id}-preview-record"}
          class="exr-preview-pick"
          phx-change="preview_record"
          phx-target={@myself}
          title={t("Item shown on the canvas")}
        >
          <.i name={@preview_source.icon} />
          <select
            name="record"
            aria-label={t("Item shown on the canvas")}
            disabled={@preview_records == []}
          >
            <option :if={@preview_records == []} value="">
              {t("%{collection} has no items yet", collection: t(@preview_source.label))}
            </option>
            <option
              :for={record <- @preview_records}
              value={to_string(Source.id(@preview_source, record))}
              selected={@preview_record == record}
            >
              {Source.title(@preview_source, record)}
            </option>
          </select>
        </form>
      </div>

      <div class="exr-top-right">
        <button
          type="button"
          class="exr-icon-btn"
          phx-click="undo"
          phx-target={@myself}
          disabled={!History.can_undo?(@history)}
          title={t("Undo (⌘Z)")}
        >
          <.i name="arrow-uturn-left" />
        </button>
        <button
          type="button"
          class="exr-icon-btn"
          phx-click="redo"
          phx-target={@myself}
          disabled={!History.can_redo?(@history)}
          title={t("Redo (⇧⌘Z)")}
        >
          <.i name="arrow-uturn-right" />
        </button>
        <span class="exr-sep"></span>
        <button
          type="button"
          class={["exr-btn exr-ghost", @code_open && "is-on"]}
          phx-click="toggle_code"
          phx-target={@myself}
          title={t("HTML, CSS and JSON")}
        >
          <.i name="code-bracket" /><span class="exr-hide-sm">{t("Code")}</span>
        </button>
        <button
          id={"#{@id}-preview"}
          type="button"
          class={["exr-btn exr-ghost", @preview && "is-on"]}
          phx-click="toggle_preview"
          phx-target={@myself}
          title={t("Preview")}
        >
          <.i name={if(@preview, do: "eye-slash", else: "eye")} />
          <span :if={@preview} class="exr-hide-sm">{t("Exit preview")}</span>
          <span :if={!@preview} class="exr-hide-sm">{t("Preview")}</span>
        </button>
        {render_slot(@actions)}
        <button
          type="button"
          class="exr-btn exr-primary"
          phx-click="save"
          phx-target={@myself}
          disabled={@saving}
          data-exr-save
        >
          <.i
            name={if(@saving, do: "arrow-path", else: "cloud-arrow-up")}
            class={@saving && "exr-spin"}
          />
          {if(@saving, do: t("Saving…"), else: t("Save"))}
        </button>
      </div>
    </header>
    """
  end

  defp device_icons, do: @device_icons

  ## Rail

  attr :panel, :string, required: true
  attr :target, :any, required: true

  defp rail(assigns) do
    ~H"""
    <nav class="exr-rail" aria-label={t("Panels")}>
      <button
        :for={
          {panel, icon, label} <- [
            {"add", "plus", "Add"},
            {"templates", "rectangle-group", "Templates"},
            {"history", "clock", "History"}
          ]
        }
        type="button"
        class={["exr-rail-btn", @panel == panel && "is-on"]}
        phx-click="panel"
        phx-value-panel={panel}
        phx-target={@target}
        title={t(label)}
      >
        <.i name={icon} class="exr-i-lg" />
      </button>
      <span class="exr-grow"></span>
      <button
        type="button"
        class={["exr-rail-btn", @panel == "shortcuts" && "is-on"]}
        phx-click="panel"
        phx-value-panel="shortcuts"
        phx-target={@target}
        title={t("Keyboard shortcuts")}
      >
        <.i name="command-line" class="exr-i-lg" />
      </button>
    </nav>
    """
  end

  ## Palette

  attr :id, :string, required: true
  attr :registry, Registry, required: true
  attr :query, :string, required: true
  attr :dynamic?, :boolean, default: false
  attr :target, :any, required: true

  defp palette(assigns) do
    groups =
      assigns.registry
      |> palette_groups(assigns.query)
      |> Enum.reject(fn {category, _blocks} -> category == :dynamic and not assigns.dynamic? end)

    assigns = assign(assigns, :groups, groups)

    ~H"""
    <div class="exr-palette" data-exr-palette>
      <div class="exr-panel-head">
        <h4>{t("Add")}</h4>
        <span class="exr-kbd" title={t("Search")}>/</span>
      </div>
      <form
        id={"#{@id}-palette-search"}
        class="exr-search"
        phx-change="palette_search"
        phx-submit="palette_search"
        phx-target={@target}
      >
        <.i name="magnifying-glass" />
        <input
          type="search"
          name="q"
          value={@query}
          placeholder={t("Search component…")}
          autocomplete="off"
          phx-debounce="120"
          data-exr-palette-search
        />
      </form>
      <div class="exr-palette-scroll">
        <p :if={@groups == []} class="exr-muted exr-pad">
          {t("No component matches “%{query}”", query: @query)}
        </p>
        <div :for={{category, blocks} <- @groups} class="exr-cat is-open" id={"exr-cat-#{category}"}>
          <button
            type="button"
            class="exr-cat-head"
            phx-click={JS.toggle_class("is-open", to: "#exr-cat-#{category}")}
          >
            <.i name="chevron-down" class="exr-cat-caret" />
            {t(category_label(category))}
            <span class="exr-count">{length(blocks)}</span>
          </button>
          <div class="exr-tiles">
            <button
              :for={block <- blocks}
              type="button"
              class="exr-tile"
              data-exr-block={block.type()}
              title={block.meta().description && t(block.meta().description)}
            >
              <.i name={block.meta().icon} class="exr-i-lg" />
              <span>{t(block.meta().label)}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp palette_groups(registry, query) do
    query = query |> to_string() |> String.trim() |> String.downcase()

    registry
    |> Registry.palette()
    |> Enum.map(fn {category, blocks} ->
      {category, Enum.filter(blocks, &matches?(&1, query))}
    end)
    |> Enum.reject(fn {_category, blocks} -> blocks == [] end)
  end

  defp matches?(_block, ""), do: true

  defp matches?(block, query) do
    meta = block.meta()

    [meta.type, meta.label, t(meta.label), meta.description || "" | meta.keywords]
    |> Enum.any?(&String.contains?(String.downcase(to_string(&1)), query))
  end

  defp category_label(category),
    do: Map.get(@categories, category, category |> to_string() |> String.capitalize())

  ## Tree

  attr :root, :map, required: true
  attr :selected, :string, default: nil
  attr :collapsed, :any, required: true
  attr :registry, Registry, required: true
  attr :sources, :any, default: nil
  attr :target, :any, required: true

  defp tree(assigns) do
    ~H"""
    <div class="exr-tree-wrap">
      <div class="exr-panel-head">
        <h4>{t("Structure")}</h4>
        <button
          type="button"
          class="exr-icon-btn"
          phx-click="tree_collapse_all"
          phx-target={@target}
          title={t("Collapse or expand all")}
        >
          <.i name="chevron-up-down" />
        </button>
      </div>
      <div class="exr-tree" role="tree" data-exr-tree>
        <.tree_node
          node={@root}
          index={0}
          depth={0}
          selected={@selected}
          collapsed={@collapsed}
          registry={@registry}
          sources={@sources}
          target={@target}
        />
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :parent, :any, default: nil
  attr :index, :integer, required: true
  attr :depth, :integer, required: true
  attr :selected, :string, default: nil
  attr :collapsed, :any, required: true
  attr :registry, Registry, required: true
  attr :sources, :any, default: nil
  attr :target, :any, required: true

  defp tree_node(assigns) do
    block = Registry.fetch(assigns.registry, assigns.node["type"])

    meta =
      (block && block.meta()) ||
        %{label: assigns.node["type"], icon: "question-mark-circle", container: false}

    children = assigns.node["children"] || []

    assigns =
      assigns
      |> assign(:meta, meta)
      |> assign(:children, children)
      |> assign(:open?, not MapSet.member?(assigns.collapsed, assigns.node["id"]))
      |> assign(:label, tree_label(assigns.node, meta))
      |> assign(:root?, assigns.node["type"] == "root")
      |> assign(:hint, tag_hint(assigns.node, assigns.sources))

    ~H"""
    <div
      class="exr-tree-item"
      role="treeitem"
      aria-expanded={@children != [] && to_string(@open?)}
      aria-selected={to_string(@selected == @node["id"])}
    >
      <div
        class={["exr-tree-row", @selected == @node["id"] && "is-selected", @root? && "is-root"]}
        style={"--depth:#{@depth}"}
        data-exr-tree-id={@node["id"]}
        data-exr-tree-parent={@parent}
        data-exr-tree-index={@index}
        data-exr-tree-container={to_string(@meta.container == true)}
        data-exr-tree-open={to_string(@open? and @children != [])}
      >
        <button
          :if={@children != [] and not @root?}
          type="button"
          class={["exr-caret", @open? && "is-open"]}
          phx-click="tree_toggle"
          phx-value-id={@node["id"]}
          phx-target={@target}
          aria-label={t("Expand or collapse")}
        >
          <.i name="chevron-right" />
        </button>
        <span :if={@children == [] or @root?} class="exr-caret"></span>
        <.i name={@meta.icon} class="exr-tree-icon" />
        <span class="exr-tree-label">{@label}</span>
        <span
          :if={@node["dynamic"] || get_in(@node, ["attrs", "condition"])}
          class="exr-tree-dyn"
          title={t("Dynamic content")}
        >
          <.i name="circle-stack" />
        </span>
        <span :if={@hint} class="exr-tree-tag">{@hint}</span>
        <span :if={!@root?} class="exr-tree-acts">
          <button
            type="button"
            phx-click="duplicate"
            phx-value-id={@node["id"]}
            phx-target={@target}
            title={t("Duplicate")}
          >
            <.i name="document-duplicate" />
          </button>
          <button
            type="button"
            phx-click="delete"
            phx-value-id={@node["id"]}
            phx-target={@target}
            title={t("Delete")}
          >
            <.i name="trash" />
          </button>
        </span>
      </div>
      <div :if={@children != [] and @open?} class="exr-tree-children" role="group">
        <.tree_node
          :for={{child, index} <- Enum.with_index(@children)}
          node={child}
          parent={@node["id"]}
          index={index}
          depth={@depth + 1}
          selected={@selected}
          collapsed={@collapsed}
          registry={@registry}
          sources={@sources}
          target={@target}
        />
      </div>
    </div>
    """
  end

  defp tree_label(node, meta) do
    case get_in(node, ["attrs", "label"]) do
      label when is_binary(label) and label != "" -> label
      _ -> preview_text(node) || t(meta.label)
    end
  end

  # A short hint of the content, so three headings can be told apart.
  defp preview_text(%{"type" => type, "props" => props})
       when type in ~w(heading text button badge link) do
    text = props["text"] || props["label"]

    case text && ElementorexCms.HTML.Sanitizer.text(text) do
      text when is_binary(text) and text != "" -> String.slice(text, 0, 28)
      _ -> nil
    end
  end

  defp preview_text(_node), do: nil

  defp tag_hint(%{"type" => "loop", "props" => props}, sources) do
    case Sources.fetch(sources, props["source"]) do
      nil -> props["source"]
      source -> t(source.label)
    end
  end

  defp tag_hint(%{"type" => "heading", "props" => props}, _sources), do: props["level"] || "h2"

  defp tag_hint(%{"type" => "container", "props" => props}, _sources),
    do: if(props["direction"] == "row", do: "row", else: "column")

  defp tag_hint(%{"type" => "grid", "props" => props}, _sources),
    do: "#{props["columns"] || 2} col"

  defp tag_hint(%{"type" => "section"}, _sources), do: "section"
  defp tag_hint(_node, _sources), do: nil

  ## Side panels

  attr :templates, :list, required: true
  attr :target, :any, required: true

  defp templates_panel(assigns) do
    {dynamic, sections} = Enum.split_with(assigns.templates, &(&1[:group] == :dynamic))

    groups =
      [{"Dynamic content", "circle-stack", dynamic}, {"Sections", "rectangle-group", sections}]
      |> Enum.reject(fn {_label, _icon, templates} -> templates == [] end)

    assigns = assign(assigns, groups: groups, headings?: dynamic != [])

    ~H"""
    <div class="exr-side-panel">
      <div class="exr-panel-head">
        <h4>{t("Templates")}</h4>
      </div>
      <p class="exr-muted exr-pad">
        {t("Ready-made sections. They are added after the selected block.")}
      </p>
      <div class="exr-template-list">
        <%= for {label, icon, templates} <- @groups do %>
          <h5 :if={@headings?} class="exr-template-group"><.i name={icon} />{t(label)}</h5>
          <button
            :for={template <- templates}
            type="button"
            class={["exr-template", template[:group] == :dynamic && "is-dynamic"]}
            phx-click="apply_template"
            phx-value-key={template.key}
            phx-target={@target}
          >
            <span class="exr-template-icon"><.i
              name={template[:icon] || "rectangle-group"}
              class="exr-i-lg"
            /></span>
            <span class="exr-template-text">
              <b>{t(template.label)}</b>
              <small :if={template[:description]}>{t(template.description)}</small>
            </span>
            <.i name="plus" />
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :history, History, required: true
  attr :target, :any, required: true

  defp history_panel(assigns) do
    ~H"""
    <div class="exr-side-panel">
      <div class="exr-panel-head">
        <h4>{t("History")}</h4>
      </div>
      <p :if={@history.past == []} class="exr-muted exr-pad">
        {t("Changes will appear here. Undo with ⌘Z.")}
      </p>
      <ol class="exr-history">
        <li class="exr-history-item is-current"><.i name="map-pin" />{t("Current version")}</li>
        <li :for={{entry, index} <- Enum.with_index(@history.past)} class="exr-history-item">
          <button
            type="button"
            phx-click="restore"
            phx-value-index={index}
            phx-target={@target}
            title={t("Go back to before this change")}
          >
            <.i name="arrow-uturn-left" />
            <span>{entry.label}</span>
          </button>
        </li>
      </ol>
    </div>
    """
  end

  defp shortcuts_panel(assigns) do
    ~H"""
    <div class="exr-side-panel">
      <div class="exr-panel-head">
        <h4>{t("Keyboard shortcuts")}</h4>
      </div>
      <dl class="exr-shortcuts">
        <div :for={{keys, label} <- shortcuts()}>
          <dt><span :for={key <- keys} class="exr-kbd">{key}</span></dt>
          <dd>{t(label)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  defp shortcuts do
    [
      {["⌘", "S"], "Save"},
      {["⌘", "Z"], "Undo"},
      {["⇧", "⌘", "Z"], "Redo"},
      {["⌘", "D"], "Duplicate"},
      {["⌘", "C"], "Copy block"},
      {["⌘", "V"], "Paste block"},
      {["⌫"], "Delete"},
      {["↑", "↓"], "Select previous or next block"},
      {["⌥", "↑"], "Move block up"},
      {["⌥", "↓"], "Move block down"},
      {["Esc"], "Select parent / stop editing"},
      {["Double-click"], "Edit text on the canvas"},
      {["/"], "Search components"}
    ]
  end

  ## Canvas extras

  attr :templates, :list, required: true
  attr :target, :any, required: true

  defp empty_canvas(assigns) do
    ~H"""
    <div class="exr-empty-canvas">
      <div class="exr-empty-card">
        <span class="exr-empty-icon"><.i name="squares-plus" class="exr-i-xl" /></span>
        <h3>{t("Start building")}</h3>
        <p>{t("Drag components from the left panel onto the canvas, or start from a template.")}</p>
        <div class="exr-empty-templates">
          <button
            :for={template <- Enum.take(@templates, 4)}
            type="button"
            class="exr-btn exr-btn-sm"
            phx-click="apply_template"
            phx-value-key={template.key}
            phx-target={@target}
          >
            <.i name={template[:icon] || "rectangle-group"} />{t(template.label)}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :path, :list, required: true
  attr :registry, Registry, required: true
  attr :target, :any, required: true

  defp pathbar(assigns) do
    ~H"""
    <nav class="exr-pathbar" aria-label={t("Path of the selection")}>
      <%= for {node, index} <- Enum.with_index(@path) do %>
        <.i :if={index > 0} name="chevron-right" class="exr-path-sep" />
        <button
          type="button"
          class={["exr-path-item", index == length(@path) - 1 && "is-on"]}
          phx-click="select"
          phx-value-id={node["id"]}
          phx-target={@target}
        >
          {block_label(@registry, node)}
        </button>
      <% end %>
    </nav>
    """
  end

  defp block_label(registry, node) do
    case get_in(node, ["attrs", "label"]) do
      label when is_binary(label) and label != "" ->
        label

      _ ->
        case Registry.fetch(registry, node["type"]) do
          nil -> node["type"]
          block -> t(block.meta().label)
        end
    end
  end

  attr :notice, :any, default: nil
  attr :error, :string, default: nil
  attr :target, :any, required: true

  defp notice(assigns) do
    {kind, message} =
      cond do
        assigns.error -> {:error, assigns.error}
        match?({_, _}, assigns.notice) -> assigns.notice
        true -> {:ok, ""}
      end

    assigns = assign(assigns, kind: kind, message: message)

    ~H"""
    <div class={["exr-notice", @kind == :error && "is-error"]} role="status" data-exr-notice={@kind}>
      <.i name={if(@kind == :error, do: "exclamation-circle", else: "check-circle")} />
      <span>{t(@message)}</span>
      <button
        type="button"
        class="exr-icon-btn"
        phx-click="dismiss_notice"
        phx-target={@target}
        aria-label={t("Close")}
      >
        <.i name="x-mark" />
      </button>
    </div>
    """
  end

  ## Code drawer

  attr :id, :string, required: true
  attr :tab, :string, required: true
  attr :doc, :map, required: true
  attr :node, :map, default: nil
  attr :block, :any, default: nil
  attr :registry, Registry, required: true
  attr :ctx, :any, required: true
  attr :target, :any, required: true

  defp codebar(assigns) do
    subject = assigns.node || Document.root(assigns.doc)
    assigns = assign(assigns, :lines, code_lines(assigns.tab, subject, assigns))

    ~H"""
    <div class="exr-code" data-exr-code>
      <div class="exr-code-tabs">
        <button
          :for={
            {tab, icon, label} <- [
              {"html", "code-bracket", "HTML"},
              {"css", "paint-brush", "CSS"},
              {"json", "variable", "JSON"}
            ]
          }
          type="button"
          class={["exr-code-tab", @tab == tab && "is-on"]}
          phx-click="code_tab"
          phx-value-tab={tab}
          phx-target={@target}
        >
          <.i name={icon} />{label}
        </button>
        <span class="exr-grow"></span>
        <span class="exr-muted exr-hide-sm">
          <.i name="cursor-arrow-rays" />
          {if(@node && @node["type"] != "root",
            do: t("Selection: %{block}", block: block_label(@registry, @node)),
            else: t("Whole document")
          )}
        </span>
        <button type="button" class="exr-btn exr-btn-sm exr-ghost" data-exr-copy={"#{@id}-code-body"}>
          <.i name="clipboard-document" />{t("Copy")}
        </button>
        <button
          type="button"
          class="exr-icon-btn"
          phx-click="toggle_code"
          phx-target={@target}
          title={t("Close")}
        >
          <.i name="chevron-down" />
        </button>
      </div>
      <div class="exr-code-body" id={"#{@id}-code-body"}>
        <p :if={@lines == []} class="exr-muted exr-pad">{t("Nothing to show yet.")}</p>
        <pre :if={@lines != []}><code><%= for line <- @lines do %><span class="exr-code-line">{line}</span><% end %></code></pre>
      </div>
    </div>
    """
  end

  defp code_lines("html", node, assigns) do
    node |> Renderer.render_node(assigns.ctx) |> Renderer.to_string_html() |> Code.html_lines()
  end

  defp code_lines("css", node, assigns) do
    css =
      if node["type"] == "root",
        do: Style.css(assigns.doc),
        else: Style.node_css(node)

    Code.css_lines(css)
  end

  defp code_lines("json", node, _assigns), do: Code.json_lines(node)

  ## Inspector

  attr :id, :string, required: true
  attr :node, :map, default: nil
  attr :block, :any, default: nil
  attr :root, :map, required: true
  attr :doc, :map, required: true
  attr :tab, :string, required: true
  attr :device, :string, required: true
  attr :style_state, :string, required: true
  attr :linked, :any, required: true
  attr :media, :any, default: nil
  attr :uploads, :any, default: nil
  attr :target, :any, required: true
  attr :dyn, :map, default: nil

  defp inspector(%{node: nil} = assigns) do
    assigns = assign(assigns, :count, Document.count(assigns.doc) - 1)

    ~H"""
    <div class="exr-insp exr-insp-empty">
      <span class="exr-empty-icon"><.i name="cursor-arrow-rays" class="exr-i-xl" /></span>
      <h3>{t("Nothing selected")}</h3>
      <p>
        {t(
          "Click a block on the canvas or in the structure to edit its content, style and advanced settings."
        )}
      </p>
      <p class="exr-muted">{t("%{count} blocks in the document", count: @count)}</p>
      <button
        type="button"
        class="exr-btn exr-btn-sm"
        phx-click="select"
        phx-value-id={@root["id"]}
        phx-target={@target}
      >
        <.i name="document" />{t("Document settings")}
      </button>
    </div>
    """
  end

  defp inspector(assigns) do
    meta =
      (assigns.block && assigns.block.meta()) ||
        %{label: assigns.node["type"], icon: "question-mark-circle", type: assigns.node["type"]}

    root? = assigns.node["type"] == "root"
    tab = if root? and assigns.tab == "content", do: "style", else: assigns.tab

    assigns = assign(assigns, meta: meta, root?: root?, active_tab: tab)

    ~H"""
    <div class="exr-insp">
      <div class="exr-insp-head">
        <span class="exr-insp-icon"><.i name={@meta.icon} /></span>
        <div class="exr-insp-title">
          <b>{if(@root?, do: t("Document"), else: t(@meta.label))}</b>
          <small class="exr-mono">{@meta[:type] || @node["type"]} · {@node["id"]}</small>
        </div>
        <button
          :if={!@root?}
          type="button"
          class="exr-icon-btn"
          phx-click="select_parent"
          phx-target={@target}
          title={t("Select parent")}
        >
          <.i name="arrow-up" />
        </button>
        <button
          :if={!@root?}
          type="button"
          class="exr-icon-btn"
          phx-click="duplicate"
          phx-target={@target}
          title={t("Duplicate")}
        >
          <.i name="document-duplicate" />
        </button>
        <button
          :if={!@root?}
          type="button"
          class="exr-icon-btn is-danger"
          phx-click="delete"
          phx-target={@target}
          title={t("Delete")}
        >
          <.i name="trash" />
        </button>
        <button
          type="button"
          class="exr-icon-btn"
          phx-click="deselect"
          phx-target={@target}
          title={t("Close")}
        >
          <.i name="x-mark" />
        </button>
      </div>
      <nav class="exr-tabs" role="tablist">
        <button
          :for={
            {tab, icon, label} <- [
              {"content", "pencil", "Content"},
              {"style", "paint-brush", "Style"},
              {"advanced", "cog-6-tooth", "Advanced"}
            ]
          }
          :if={tab != "content" or not @root?}
          type="button"
          role="tab"
          class={["exr-tab", @active_tab == tab && "is-on"]}
          aria-selected={to_string(@active_tab == tab)}
          phx-click="tab"
          phx-value-tab={tab}
          phx-target={@target}
        >
          <.i name={icon} />{t(label)}
        </button>
      </nav>
      <div class="exr-insp-body">
        <%= case @active_tab do %>
          <% "content" -> %>
            <.content_form
              id={@id}
              node={@node}
              block={@block}
              media={@media}
              uploads={@uploads}
              target={@target}
              dyn={@dyn}
            />
          <% "style" -> %>
            <.style_form
              id={@id}
              node={@node}
              device={@device}
              style_state={@style_state}
              linked={@linked}
              media={@media}
              uploads={@uploads}
              target={@target}
            />
          <% _advanced -> %>
            <.advanced_form id={@id} node={@node} root?={@root?} target={@target} dyn={@dyn} />
        <% end %>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :node, :map, required: true
  attr :block, :any, required: true
  attr :media, :any, default: nil
  attr :uploads, :any, default: nil
  attr :target, :any, required: true
  attr :dyn, :map, default: nil

  defp content_form(%{block: nil} = assigns) do
    ~H"""
    <p class="exr-muted exr-pad">
      {t("This block type is not available. It is kept in the document but not shown.")}
    </p>
    """
  end

  defp content_form(assigns) do
    values = Block.assigns(assigns.block, assigns.node["props"] || %{})

    groups =
      assigns.block.props()
      |> Enum.filter(&Prop.visible?(&1, values))
      |> Enum.chunk_by(& &1.group)
      |> Enum.map(&{hd(&1).group, &1})

    assigns = assign(assigns, values: values, groups: groups)

    ~H"""
    <div :if={@dyn && @dyn.item_source} class="exr-dyn-scope">
      <span class="exr-dyn-scope-icon"><.i name={@dyn.item_source.icon} /></span>
      <span class="exr-dyn-scope-text">
        <b>{t("Item of %{collection}", collection: t(@dyn.item_source.label))}</b>
        <small>
          {t("Show one of its fields in a setting with")} <.i name="circle-stack" />
        </small>
      </span>
    </div>
    <p :if={@groups == []} class="exr-muted exr-pad">
      {t("This block has no content settings. Use the Style tab.")}
    </p>
    <form
      :if={@groups != []}
      id={"#{@id}-props-#{@node["id"]}"}
      class="exr-form"
      phx-change="props"
      phx-submit="props_submit"
      phx-target={@target}
      autocomplete="off"
    >
      <input type="hidden" name="node" value={@node["id"]} />
      <section :for={{group, props} <- @groups} class="exr-group">
        <h5 :if={group} class="exr-group-title">{t(group)}</h5>
        <.prop
          :for={prop <- props}
          prop={prop}
          value={Map.get(@values, prop.name)}
          name={"props[#{prop.key}]"}
          id={"#{@id}-p-#{@node["id"]}-#{prop.key}"}
          target={@target}
          uploads={@uploads}
          media={@media}
          dyn={@dyn}
        />
      </section>
    </form>
    """
  end

  attr :id, :string, required: true
  attr :node, :map, required: true
  attr :device, :string, required: true
  attr :style_state, :string, required: true
  attr :linked, :any, required: true
  attr :media, :any, default: nil
  attr :uploads, :any, default: nil
  attr :target, :any, required: true

  defp style_form(assigns) do
    style = assigns.node["style"] || %{}
    state = assigns.style_state
    hover? = state == "hover"

    inherited =
      case state do
        "tablet" -> style["desktop"] || %{}
        "mobile" -> Map.merge(style["desktop"] || %{}, style["tablet"] || %{})
        "hover" -> style["desktop"] || %{}
        _ -> %{}
      end

    sections =
      if hover? do
        hover = StyleFields.hover_properties()

        StyleFields.sections()
        |> Enum.map(fn section ->
          %{section | fields: Enum.filter(section.fields, &(&1.property in hover))}
        end)
        |> Enum.reject(&(&1.fields == []))
      else
        StyleFields.sections()
      end

    assigns =
      assign(assigns,
        values: style[state] || %{},
        inherited: inherited,
        sections: sections,
        hover?: hover?,
        state_count: map_size(style[state] || %{})
      )

    ~H"""
    <div class="exr-state-bar">
      <div class="exr-seg">
        <button
          :for={{device, icon, label} <- device_icons()}
          type="button"
          class={["exr-seg-item", (!@hover? and @device == device) && "is-on"]}
          phx-click="device"
          phx-value-device={device}
          phx-target={@target}
          title={t("Edit the %{device} styles", device: String.downcase(t(label)))}
        >
          <.i name={icon} />
        </button>
      </div>
      <div class="exr-seg">
        <button
          type="button"
          class={["exr-seg-item", !@hover? && "is-on"]}
          phx-click="style_state"
          phx-value-state="normal"
          phx-target={@target}
        >{t("Normal")}</button>
        <button
          type="button"
          class={["exr-seg-item", @hover? && "is-on"]}
          phx-click="style_state"
          phx-value-state="hover"
          phx-target={@target}
        >{t("Hover")}</button>
      </div>
      <button
        type="button"
        class="exr-icon-btn"
        phx-click="clear_style"
        phx-target={@target}
        disabled={@state_count == 0}
        title={t("Reset these styles")}
      >
        <.i name="arrow-path" />
      </button>
    </div>
    <p class="exr-state-hint">
      <.i name={if(@hover?, do: "cursor-arrow-rays", else: device_icon(@device))} />
      {state_hint(@style_state)}
    </p>
    <form
      id={"#{@id}-style-#{@node["id"]}-#{@style_state}"}
      class="exr-form"
      phx-change="style"
      phx-submit="style_submit"
      phx-target={@target}
      autocomplete="off"
    >
      <input type="hidden" name="node" value={@node["id"]} />
      <div
        :for={section <- @sections}
        id={"#{@id}-sec-#{section.key}"}
        class={["exr-acc", section.key in ["typography", "spacing"] && "is-open"]}
      >
        <button
          type="button"
          class="exr-acc-head"
          phx-click={JS.toggle_class("is-open", to: "##{@id}-sec-#{section.key}")}
        >
          <.i name={section.icon} />
          <span>{t(section.label)}</span>
          <span :if={section_has_values?(section, @values)} class="exr-dot"></span>
          <.i name="chevron-down" class="exr-acc-caret" />
        </button>
        <div class="exr-acc-body">
          <.style_field
            :for={field <- section.fields}
            field={field}
            values={@values}
            inherited={@inherited}
            id={"#{@id}-s-#{@node["id"]}"}
            linked={@linked}
            target={@target}
            media={@media}
            uploads={@uploads}
          />
        </div>
      </div>
    </form>
    """
  end

  defp section_has_values?(section, values) do
    Enum.any?(section.fields, fn field ->
      properties = Map.get(StyleFields.groups(), field.property, [field.property])
      Enum.any?(properties, &Map.has_key?(values, &1))
    end)
  end

  defp device_icon(device) do
    Enum.find_value(@device_icons, "computer-desktop", fn {d, icon, _} ->
      if d == device, do: icon
    end)
  end

  defp state_hint("desktop"),
    do: t("Desktop styles apply everywhere unless tablet or mobile override them.")

  defp state_hint("tablet"),
    do: t("Tablet styles (below 1024px). Empty fields inherit from desktop.")

  defp state_hint("mobile"),
    do: t("Mobile styles (below 768px). Empty fields inherit from tablet and desktop.")

  defp state_hint("hover"), do: t("Styles while the pointer is over the element.")

  attr :id, :string, required: true
  attr :node, :map, required: true
  attr :root?, :boolean, required: true
  attr :target, :any, required: true
  attr :dyn, :map, default: nil

  defp advanced_form(assigns) do
    attrs = assigns.node["attrs"] || %{}
    source = assigns.dyn && assigns.dyn.item_source

    assigns =
      assign(assigns,
        attrs: attrs,
        condition: attrs["condition"],
        condition_fields: (source && Enum.reject(source.fields, & &1.custom)) || [],
        condition_ops: Enum.reject(ElementorexCms.Blocks.Loop.ops(), &(elem(&1, 1) == "same"))
      )

    ~H"""
    <form
      id={"#{@id}-attrs-#{@node["id"]}"}
      class="exr-form"
      phx-change="attrs"
      phx-submit="attrs_submit"
      phx-target={@target}
      autocomplete="off"
    >
      <input type="hidden" name="node" value={@node["id"]} />
      <section :if={!@root?} class="exr-group">
        <div class="exr-field">
          <label class="exr-label" for={"#{@id}-a-label"}>{t("Name in the structure")}</label>
          <input
            id={"#{@id}-a-label"}
            type="text"
            name="attrs[label]"
            value={@attrs["label"]}
            class="exr-input"
            phx-debounce="300"
            placeholder={t("Optional")}
          />
        </div>
        <div class="exr-field">
          <label class="exr-label" for={"#{@id}-a-id"}>{t("CSS ID")}</label>
          <input
            id={"#{@id}-a-id"}
            type="text"
            name="attrs[id]"
            value={@attrs["id"]}
            class="exr-input exr-mono"
            phx-debounce="300"
            placeholder="contacto"
            spellcheck="false"
          />
          <p class="exr-help">{t("Letters, digits and hyphens. Useful for #anchor links.")}</p>
        </div>
      </section>
      <section class="exr-group">
        <div class="exr-field">
          <label class="exr-label" for={"#{@id}-a-class"}>{t("CSS classes")}</label>
          <input
            id={"#{@id}-a-class"}
            type="text"
            name="attrs[class]"
            value={@attrs["class"]}
            class="exr-input exr-mono"
            phx-debounce="400"
            placeholder="shadow-lg md:p-10"
            spellcheck="false"
          />
          <p class="exr-help">
            {t("Tailwind and daisyUI classes work if your site's CSS includes them.")}
          </p>
        </div>
      </section>
      <section :if={!@root?} class="exr-group">
        <h5 class="exr-group-title">{t("Hide on")}</h5>
        <input type="hidden" name="attrs[hide_on][]" value="" />
        <div class="exr-checks">
          <label
            :for={{device, icon, label} <- device_icons()}
            class={["exr-check", device in (@attrs["hide_on"] || []) && "is-on"]}
          >
            <input
              type="checkbox"
              name="attrs[hide_on][]"
              value={device}
              checked={device in (@attrs["hide_on"] || [])}
            />
            <.i name={icon} />{t(label)}
          </label>
        </div>
        <p class="exr-help">
          {t("Hidden blocks are dimmed on the canvas and removed on your site.")}
        </p>
      </section>
      <section
        :if={!@root? and (@condition_fields != [] or @condition)}
        class="exr-group"
        id={"#{@id}-a-condition"}
      >
        <h5 class="exr-group-title">{t("Display condition")}</h5>
        <div class="exr-field">
          <label class="exr-label" for={"#{@id}-a-cond-field"}>{t("Show it only when")}</label>
          <select
            id={"#{@id}-a-cond-field"}
            name="attrs[condition][field]"
            class="exr-input exr-select"
          >
            <option value="">{t("Always")}</option>
            <option
              :for={field <- @condition_fields}
              value={field.key}
              selected={@condition && @condition["field"] == field.key}
            >
              {t(field.label)}
            </option>
            <option
              :if={@condition && !Enum.any?(@condition_fields, &(&1.key == @condition["field"]))}
              value={@condition["field"]}
              selected
            >
              {@condition["field"]}
            </option>
          </select>
        </div>
        <div :if={@condition} class="exr-grid-2">
          <div class="exr-field">
            <label class="exr-label" for={"#{@id}-a-cond-op"}>{t("Condition")}</label>
            <select id={"#{@id}-a-cond-op"} name="attrs[condition][op]" class="exr-input exr-select">
              <option
                :for={{label, op} <- @condition_ops}
                value={op}
                selected={@condition["op"] == op}
              >
                {t(label)}
              </option>
            </select>
          </div>
          <div :if={@condition["op"] not in ~w(set unset)} class="exr-field">
            <label class="exr-label" for={"#{@id}-a-cond-value"}>{t("Value")}</label>
            <input
              id={"#{@id}-a-cond-value"}
              type="text"
              name="attrs[condition][value]"
              value={@condition["value"]}
              class="exr-input"
              phx-debounce="300"
            />
          </div>
        </div>
        <p class="exr-help">
          {t(
            "The block only shows for the items that match. On the canvas it is dimmed for the others."
          )}
        </p>
      </section>
      <section :if={!@root?} class="exr-group">
        <h5 class="exr-group-title">{t("Entrance animation")}</h5>
        <div class="exr-grid-2">
          <div class="exr-field">
            <label class="exr-label" for={"#{@id}-a-anim"}>{t("Animation")}</label>
            <select id={"#{@id}-a-anim"} name="attrs[animation]" class="exr-input exr-select">
              <option value="">{t("None")}</option>
              <option
                :for={animation <- Document.animations()}
                value={animation}
                selected={@attrs["animation"] == animation}
              >
                {t(animation_label(animation))}
              </option>
            </select>
          </div>
          <div class="exr-field">
            <label class="exr-label" for={"#{@id}-a-delay"}>{t("Delay")}</label>
            <div class="exr-input exr-input-unit">
              <input
                id={"#{@id}-a-delay"}
                type="number"
                name="attrs[animation_delay]"
                value={@attrs["animation_delay"]}
                min="0"
                max="5000"
                step="100"
                phx-debounce="300"
              />
              <span>ms</span>
            </div>
          </div>
        </div>
      </section>
      <section class="exr-group">
        <h5 class="exr-group-title">{if(@root?, do: t("Document CSS"), else: t("Custom CSS"))}</h5>
        <textarea
          name="attrs[css]"
          class="exr-input exr-textarea exr-mono"
          rows="8"
          phx-debounce="500"
          spellcheck="false"
          placeholder="selector {\n  box-shadow: none;\n}\nselector a:hover {\n  text-decoration: underline;\n}"
        >{@attrs["css"]}</textarea>
        <p class="exr-help">{t("Use “selector” for this element. Rules only apply inside it.")}</p>
      </section>
    </form>
    """
  end

  defp animation_label("fade-in"), do: "Fade in"
  defp animation_label("fade-up"), do: "Fade in up"
  defp animation_label("fade-down"), do: "Fade in down"
  defp animation_label("fade-left"), do: "Fade in from the right"
  defp animation_label("fade-right"), do: "Fade in from the left"
  defp animation_label("zoom-in"), do: "Zoom in"
  defp animation_label(other), do: other

  ## Modals

  attr :picker, :map, required: true
  attr :block, :any, required: true
  attr :dyn, :map, required: true
  attr :target, :any, required: true

  defp field_picker(assigns) do
    prop = Block.find_prop(assigns.block, assigns.picker.prop)
    query = assigns.picker.query |> to_string() |> String.trim() |> String.downcase()
    dyn = assigns.dyn

    groups =
      [
        dyn.item_source &&
          {t("Item of %{collection}", collection: t(dyn.item_source.label)), dyn.item_source.icon,
           "item", Source.fields(dyn.item_source)},
        dyn.site_fields != [] && {t("Site"), "globe-alt", "site", dyn.site_fields}
      ]
      |> Enum.filter(& &1)
      |> Enum.map(fn {label, icon, from, fields} ->
        fields =
          fields
          |> Enum.filter(&field_matches?(&1, query))
          |> Enum.sort_by(&if(suggested?(prop, &1), do: 0, else: 1))

        {label, icon, from, fields}
      end)
      |> Enum.reject(fn {_label, _icon, _from, fields} -> fields == [] end)

    assigns = assign(assigns, prop: prop, groups: groups)

    ~H"""
    <div class="exr-modal" phx-window-keydown="dynamic_close" phx-key="Escape" phx-target={@target}>
      <div class="exr-modal-backdrop" phx-click="dynamic_close" phx-target={@target}></div>
      <div
        class="exr-modal-panel"
        role="dialog"
        aria-modal="true"
        aria-label={t("Show a field")}
        id="exr-field-picker"
      >
        <div class="exr-modal-head">
          <h3>{t("Show a field")}</h3>
          <span :if={@prop} class="exr-muted">{t(@prop.label)}</span>
          <button
            type="button"
            class="exr-icon-btn"
            phx-click="dynamic_close"
            phx-target={@target}
            aria-label={t("Close")}
          >
            <.i name="x-mark" />
          </button>
        </div>
        <form
          id="exr-field-search"
          class="exr-search"
          phx-change="dynamic_search"
          phx-submit="dynamic_search"
          phx-target={@target}
        >
          <.i name="magnifying-glass" />
          <input
            type="search"
            name="q"
            value={@picker.query}
            placeholder={t("Search fields…")}
            autocomplete="off"
            phx-debounce="120"
            phx-mounted={JS.focus()}
          />
        </form>
        <div class="exr-field-list">
          <section :for={{label, icon, from, fields} <- @groups} class="exr-field-section">
            <h5 class="exr-field-group"><.i name={icon} />{label}</h5>
            <button
              :for={field <- fields}
              type="button"
              class={["exr-field-item", suggested?(@prop, field) && "is-suggested"]}
              phx-click="dynamic_pick"
              phx-value-field={field.key}
              phx-value-from={from}
              phx-target={@target}
              data-exr-field={field.key}
            >
              <span class="exr-field-icon"><.i name={type_icon(field.type)} /></span>
              <span class="exr-field-name">
                <b>{t(field.label)}</b>
                <small class="exr-mono">{field.key}</small>
              </span>
              <span class="exr-field-type">{t(type_label(field.type))}</span>
            </button>
          </section>
          <p :if={@groups == []} class="exr-muted exr-pad">{t("No field matches.")}</p>
        </div>
      </div>
    </div>
    """
  end

  defp field_matches?(_field, ""), do: true

  defp field_matches?(field, query) do
    [field.key, field.label, t(field.label)]
    |> Enum.any?(&String.contains?(String.downcase(&1), query))
  end

  # Fields whose values suit the prop go first and are highlighted.
  defp suggested?(nil, _field), do: false
  defp suggested?(%Prop{type: :image}, field), do: field.type in [:image, :url]

  defp suggested?(%Prop{type: :url}, field),
    do: field.type in [:url, :image] or field.key == "@url"

  defp suggested?(%Prop{type: type}, field) when type in [:integer, :number],
    do: field.type in [:integer, :number]

  defp suggested?(%Prop{type: :boolean}, field), do: field.type == :boolean
  defp suggested?(%Prop{type: :datetime}, field), do: field.type in [:date, :datetime]
  defp suggested?(%Prop{type: :color}, field), do: field.type == :color
  defp suggested?(%Prop{type: :icon}, field), do: field.type == :icon

  defp suggested?(%Prop{}, field),
    do: field.type in [:string, :text, :html, :integer, :number, :date, :datetime]

  @doc false
  def type_icon(:string), do: "bars-2"
  def type_icon(:text), do: "bars-3-bottom-left"
  def type_icon(:html), do: "code-bracket"
  def type_icon(type) when type in [:integer, :number], do: "hashtag"
  def type_icon(:boolean), do: "check-circle"
  def type_icon(type) when type in [:date, :datetime], do: "calendar"
  def type_icon(:image), do: "photo"
  def type_icon(:url), do: "link"
  def type_icon(:color), do: "swatch"
  def type_icon(:icon), do: "star"
  def type_icon(:list), do: "list-bullet"
  def type_icon(_type), do: "variable"

  @doc false
  def type_label(:string), do: "Text"
  def type_label(:text), do: "Long text"
  def type_label(:html), do: "Rich text"
  def type_label(type) when type in [:integer, :number], do: "Number"
  def type_label(:boolean), do: "Yes / No"
  def type_label(:date), do: "Date"
  def type_label(:datetime), do: "Date and time"
  def type_label(:image), do: "Image"
  def type_label(:url), do: "Link"
  def type_label(:color), do: "Color"
  def type_label(:icon), do: "Icon"
  def type_label(:list), do: "List"
  def type_label(_type), do: "Value"

  attr :picker, :map, required: true
  attr :target, :any, required: true

  defp icon_picker(assigns) do
    assigns = assign(assigns, :icons, Heroicons.search(assigns.picker.query, 160))

    ~H"""
    <div class="exr-modal" phx-window-keydown="picker_close" phx-key="Escape" phx-target={@target}>
      <div class="exr-modal-backdrop" phx-click="picker_close" phx-target={@target}></div>
      <div class="exr-modal-panel" role="dialog" aria-modal="true" aria-label={t("Choose an icon")}>
        <div class="exr-modal-head">
          <h3>{t("Choose an icon")}</h3>
          <span class="exr-muted">Heroicons · {length(Heroicons.names())}</span>
          <button
            type="button"
            class="exr-icon-btn"
            phx-click="picker_close"
            phx-target={@target}
            aria-label={t("Close")}
          >
            <.i name="x-mark" />
          </button>
        </div>
        <form
          id="exr-picker-search"
          class="exr-search"
          phx-change="picker_search"
          phx-submit="picker_search"
          phx-target={@target}
        >
          <.i name="magnifying-glass" />
          <input
            type="search"
            name="q"
            value={@picker.query}
            placeholder={t("Search icons (gift, arrow, regalo…)")}
            autocomplete="off"
            phx-debounce="120"
            phx-mounted={JS.focus()}
          />
        </form>
        <div class="exr-icon-grid">
          <button
            :for={name <- @icons}
            type="button"
            class="exr-icon-cell"
            phx-click="picker_pick"
            phx-value-name={name}
            phx-target={@target}
            title={name}
          >
            <Heroicons.icon name={name} class="exr-i-lg" />
            <span>{name}</span>
          </button>
          <p :if={@icons == []} class="exr-muted exr-pad">{t("No icon matches.")}</p>
        </div>
      </div>
    </div>
    """
  end

  attr :library, :map, required: true
  attr :target, :any, required: true

  defp library(assigns) do
    ~H"""
    <div class="exr-modal" phx-window-keydown="library_close" phx-key="Escape" phx-target={@target}>
      <div class="exr-modal-backdrop" phx-click="library_close" phx-target={@target}></div>
      <div
        class="exr-modal-panel exr-modal-wide"
        role="dialog"
        aria-modal="true"
        aria-label={t("Media library")}
      >
        <div class="exr-modal-head">
          <h3>{t("Media library")}</h3>
          <button
            type="button"
            class="exr-icon-btn"
            phx-click="library_close"
            phx-target={@target}
            aria-label={t("Close")}
          >
            <.i name="x-mark" />
          </button>
        </div>
        <form
          id="exr-library-search"
          class="exr-search"
          phx-change="library_search"
          phx-submit="library_search"
          phx-target={@target}
        >
          <.i name="magnifying-glass" />
          <input
            type="search"
            name="q"
            value={@library.query}
            placeholder={t("Search images…")}
            autocomplete="off"
            phx-debounce="250"
          />
        </form>
        <div class="exr-media-grid">
          <button
            :for={item <- @library.items}
            type="button"
            class="exr-media-cell"
            phx-click="library_pick"
            phx-value-url={item.url}
            phx-target={@target}
            title={item[:name] || item[:alt]}
          >
            <img src={item[:thumb] || item.url} alt={item[:alt] || ""} loading="lazy" />
            <span :if={item[:name]}>{item[:name]}</span>
          </button>
          <p :if={@library.items == []} class="exr-muted exr-pad">{t("No images found.")}</p>
        </div>
      </div>
    </div>
    """
  end
end
