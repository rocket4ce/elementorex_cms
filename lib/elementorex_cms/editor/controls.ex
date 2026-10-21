defmodule ElementorexCms.Editor.Controls do
  @moduledoc false
  # Form controls of the inspector: one per prop type (Content tab) and per
  # style field (Style tab). Names follow the form params the editor expects:
  # `props[key]`, `props[list][index][field]`, `style[property]`.

  use Phoenix.Component

  alias ElementorexCms.Block.Prop
  alias ElementorexCms.Dynamic
  alias ElementorexCms.Heroicons
  alias ElementorexCms.I18n
  alias ElementorexCms.Source
  alias Phoenix.LiveView.JS

  @theme_colors [
    {"Primary", "var(--color-primary)", "primary"},
    {"Secondary", "var(--color-secondary)", "secondary"},
    {"Accent", "var(--color-accent)", "accent"},
    {"Neutral", "var(--color-neutral)", "neutral"},
    {"Base 100", "var(--color-base-100)", "base-100"},
    {"Base 200", "var(--color-base-200)", "base-200"},
    {"Base 300", "var(--color-base-300)", "base-300"},
    {"Base content", "var(--color-base-content)", "base-content"},
    {"Info", "var(--color-info)", "info"},
    {"Success", "var(--color-success)", "success"},
    {"Warning", "var(--color-warning)", "warning"},
    {"Error", "var(--color-error)", "error"}
  ]

  @doc false
  def theme_colors, do: @theme_colors

  defp t(text, bindings \\ []), do: I18n.t(text, bindings)

  attr :name, :string, required: true
  attr :class, :any, default: nil

  def i(assigns) do
    ~H"""
    <Heroicons.icon name={@name} class={["exr-i", @class]} />
    """
  end

  ## Content tab

  attr :prop, Prop, required: true
  attr :value, :any, required: true
  attr :name, :string, required: true
  attr :id, :string, required: true
  attr :target, :any, required: true
  attr :uploads, :any, default: nil
  attr :media, :any, default: nil
  attr :index, :any, default: nil, doc: "index of the list item (nested fields)"
  attr :list, :string, default: nil, doc: "key of the list prop (nested fields)"

  attr :dyn, :map,
    default: nil,
    doc: "dynamic content of the inspector: sources, item source, site fields, bindings"

  def prop(%{prop: %Prop{control: :repeater}} = assigns), do: repeater(assigns)

  def prop(assigns) do
    dyn = assigns.dyn
    top? = assigns.index == nil
    binding = if top? and dyn, do: Map.get(dyn.bindings, assigns.prop.key)

    bindable? =
      binding != nil or
        (top? and dyn != nil and Dynamic.bindable?(assigns.prop) and
           (dyn.item_source != nil or dyn.site_fields != []))

    assigns = assign(assigns, binding: binding, bindable?: bindable?)

    ~H"""
    <div class={["exr-field", "exr-field-#{@prop.control}", @binding && "is-bound"]}>
      <div :if={@prop.control != :toggle or @binding} class="exr-label">
        <label for={@id}>{t(@prop.label)}</label>
        <span
          :if={@prop.inline and @index == nil and !@binding}
          class="exr-hint-chip"
          title={t("Double-click it on the canvas to type")}
        >
          <.i name="cursor-arrow-rays" />
        </span>
        <.dyn_button :if={@bindable?} prop={@prop} on={@binding != nil} target={@target} />
      </div>
      <%= if @binding do %>
        {binding_control(assigns)}
      <% else %>
        {control(assigns)}
        <p :if={@prop.help} class="exr-help">{t(@prop.help)}</p>
      <% end %>
    </div>
    """
  end

  attr :prop, Prop, required: true
  attr :on, :boolean, default: false
  attr :target, :any, required: true

  defp dyn_button(assigns) do
    ~H"""
    <button
      type="button"
      class={["exr-dyn-btn", @on && "is-on"]}
      phx-click="dynamic_open"
      phx-value-prop={@prop.key}
      phx-target={@target}
      title={if(@on, do: t("Change the field"), else: t("Show a field"))}
      aria-label={t("Show a field")}
      data-exr-dyn={@prop.key}
    >
      <.i name="circle-stack" />
    </button>
    """
  end

  ## Bindings (dynamic content)

  defp binding_control(assigns) do
    %{dyn: dyn, binding: binding, prop: prop} = assigns

    field =
      if binding["from"] == "site",
        do: Enum.find(dyn.site_fields, &(&1.key == binding["field"])),
        else: dyn.item_source && Source.field(dyn.item_source, binding["field"])

    origin =
      cond do
        binding["from"] == "site" -> t("Site")
        dyn.item_source -> t(dyn.item_source.label)
        true -> t("Item")
      end

    assigns =
      assign(assigns,
        field: field,
        origin: origin,
        box: "#{assigns.id}-binding",
        text?: prop.type not in [:integer, :number, :boolean, :datetime],
        fallback?: prop.type != :boolean,
        formats:
          if(prop.type in [:integer, :number, :boolean, :datetime], do: [], else: formats(field))
      )

    ~H"""
    <div class={["exr-binding", !@field && "is-missing"]} id={@box}>
      <div class="exr-binding-head">
        <span class="exr-binding-icon">
          <.i name={
            if(@field,
              do: ElementorexCms.Editor.UI.type_icon(@field.type),
              else: "exclamation-triangle"
            )
          } />
        </span>
        <button
          type="button"
          class="exr-binding-name"
          phx-click={JS.toggle_class("is-open", to: "##{@box}")}
          title={t("Settings")}
        >
          <small>{@origin}</small>
          <b>{if(@field, do: t(@field.label), else: @binding["field"])}</b>
        </button>
        <span :if={summary(@binding) != ""} class="exr-binding-summary">{summary(@binding)}</span>
        <button
          :if={@text? or @fallback?}
          type="button"
          class="exr-icon-btn"
          phx-click={JS.toggle_class("is-open", to: "##{@box}")}
          title={t("Settings")}
        >
          <.i name="adjustments-horizontal" />
        </button>
        <button
          type="button"
          class="exr-icon-btn"
          phx-click="dynamic_clear"
          phx-value-prop={@prop.key}
          phx-target={@target}
          title={t("Remove the binding")}
        >
          <.i name="x-mark" />
        </button>
      </div>
      <p :if={!@field} class="exr-help">{t("This field is not available here.")}</p>
      <div class="exr-binding-body">
        <div :if={@text?} class="exr-grid-2">
          <div class="exr-field">
            <label class="exr-label" for={"#{@id}-before"}>{t("Before")}</label>
            <input
              id={"#{@id}-before"}
              type="text"
              name={"dynamic[#{@prop.key}][before]"}
              value={@binding["before"]}
              class="exr-input"
              phx-debounce="300"
            />
          </div>
          <div class="exr-field">
            <label class="exr-label" for={"#{@id}-after"}>{t("After")}</label>
            <input
              id={"#{@id}-after"}
              type="text"
              name={"dynamic[#{@prop.key}][after]"}
              value={@binding["after"]}
              class="exr-input"
              phx-debounce="300"
            />
          </div>
        </div>
        <div :if={@fallback?} class="exr-field">
          <label class="exr-label" for={"#{@id}-fallback"}>{t("When it has no value")}</label>
          <input
            id={"#{@id}-fallback"}
            type="text"
            name={"dynamic[#{@prop.key}][fallback]"}
            value={@binding["fallback"]}
            class="exr-input"
            placeholder={t("Nothing")}
            phx-debounce="300"
          />
        </div>
        <div :if={@formats != []} class="exr-grid-2">
          <div class="exr-field">
            <label class="exr-label" for={"#{@id}-format"}>{t("Format")}</label>
            <select
              id={"#{@id}-format"}
              name={"dynamic[#{@prop.key}][format]"}
              class="exr-input exr-select"
            >
              <option value="">{t("As it is")}</option>
              <option
                :for={{label, value} <- @formats}
                value={value}
                selected={@binding["format"] == value}
              >
                {t(label)}
              </option>
            </select>
          </div>
          <div :if={@binding["format"] == "number"} class="exr-field">
            <label class="exr-label" for={"#{@id}-decimals"}>{t("Decimals")}</label>
            <input
              id={"#{@id}-decimals"}
              type="number"
              min="0"
              max="4"
              name={"dynamic[#{@prop.key}][decimals]"}
              value={@binding["decimals"]}
              class="exr-input"
              placeholder={t("As it is")}
              phx-debounce="300"
            />
          </div>
          <div :if={@binding["format"] == "excerpt"} class="exr-field">
            <label class="exr-label" for={"#{@id}-length"}>{t("Characters")}</label>
            <input
              id={"#{@id}-length"}
              type="number"
              min="10"
              max="2000"
              name={"dynamic[#{@prop.key}][length]"}
              value={@binding["length"] || 160}
              class="exr-input"
              phx-debounce="300"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @number_formats [{"Number", "number"}]
  @date_formats [{"Date", "date"}, {"Date and time", "datetime"}, {"Time", "time"}]
  @text_formats [{"Excerpt", "excerpt"}, {"Uppercase", "upper"}, {"Lowercase", "lower"}]

  defp formats(nil), do: @number_formats ++ @date_formats ++ @text_formats
  defp formats(%{type: type}) when type in [:integer, :number], do: @number_formats
  defp formats(%{type: type}) when type in [:date, :datetime], do: @date_formats
  defp formats(%{type: type}) when type in [:string, :text, :html], do: @text_formats
  defp formats(_field), do: []

  # "$ … · number"
  defp summary(binding) do
    around =
      case {binding["before"], binding["after"]} do
        {nil, nil} -> nil
        {before, after_text} -> "#{before}…#{after_text}"
      end

    [around, binding["format"] && t(format_label(binding["format"]))]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp format_label(format) do
    Enum.find_value(@number_formats ++ @date_formats ++ @text_formats, format, fn {label, value} ->
      if value == format, do: label
    end)
  end

  defp control(%{prop: %Prop{control: :text}} = assigns) do
    ~H"""
    <input
      type="text"
      id={@id}
      name={@name}
      value={@value}
      class="exr-input"
      placeholder={@prop.placeholder && t(@prop.placeholder)}
      phx-debounce="250"
    />
    """
  end

  defp control(%{prop: %Prop{control: :url}} = assigns) do
    ~H"""
    <div class="exr-input exr-input-icon">
      <.i name="link" />
      <input
        type="text"
        id={@id}
        name={@name}
        value={@value}
        placeholder={@prop.placeholder || "https://… /path #anchor"}
        phx-debounce="300"
        spellcheck="false"
      />
    </div>
    """
  end

  defp control(%{prop: %Prop{control: control}} = assigns)
       when control in [:textarea, :richtext, :code] do
    ~H"""
    <textarea
      id={@id}
      name={@name}
      class={["exr-input exr-textarea", @prop.control == :code && "exr-mono"]}
      rows={if(@prop.control == :code, do: 9, else: 4)}
      phx-debounce="400"
      spellcheck={@prop.control != :code}
    >{@value}</textarea>
    <p :if={@prop.control == :richtext} class="exr-help">
      {t("Double-click the text on the canvas to edit it with formatting.")}
    </p>
    """
  end

  defp control(%{prop: %Prop{control: :number}} = assigns) do
    ~H"""
    <div class="exr-input exr-input-unit">
      <input
        type="number"
        id={@id}
        name={@name}
        value={@value}
        min={@prop.min}
        max={@prop.max}
        step={@prop.step || "any"}
        phx-debounce="250"
      />
      <span :if={@prop.unit}>{@prop.unit}</span>
    </div>
    """
  end

  defp control(%{prop: %Prop{control: :range}} = assigns) do
    ~H"""
    <div class="exr-range">
      <input
        type="range"
        id={@id}
        name={@name}
        value={@value}
        min={@prop.min || 0}
        max={@prop.max || 100}
        step={@prop.step || 1}
        phx-debounce="80"
      />
      <output>{@value}{@prop.unit}</output>
    </div>
    """
  end

  defp control(%{prop: %Prop{control: :toggle}} = assigns) do
    assigns = assign_new(assigns, :bindable?, fn -> false end)

    ~H"""
    <div class="exr-switch-line">
      <label class="exr-switch-row" for={@id}>
        <span>{t(@prop.label)}</span>
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@value == true}
          class="exr-switch"
        />
      </label>
      <.dyn_button :if={@bindable?} prop={@prop} target={@target} />
    </div>
    """
  end

  defp control(%{prop: %Prop{control: :source}} = assigns) do
    sources = (assigns.dyn && assigns.dyn.sources) || []

    assigns =
      assign(assigns, sources: sources, known?: Enum.any?(sources, &(&1.key == assigns.value)))

    ~H"""
    <select id={@id} name={@name} class="exr-input exr-select">
      <option value="">{t("Choose a collection")}</option>
      <option :for={source <- @sources} value={source.key} selected={@value == source.key}>
        {t(source.label)}
      </option>
      <option :if={@value != "" and !@known?} value={@value} selected>
        {t("Unknown collection: %{source}", source: @value)}
      </option>
    </select>
    <p :if={@sources == []} class="exr-help">
      {t("There are no collections yet: add a source to the configuration.")}
    </p>
    """
  end

  defp control(%{prop: %Prop{control: :loop}} = assigns) do
    loops = (assigns.dyn && assigns.dyn[:loops]) || []

    assigns =
      assign(assigns, loops: loops, known?: Enum.any?(loops, &(elem(&1, 1) == assigns.value)))

    ~H"""
    <select id={@id} name={@name} class="exr-input exr-select">
      <option value="">{t("The first loop grid of the page")}</option>
      <option :for={{label, id} <- @loops} value={id} selected={@value == id}>{label}</option>
      <option :if={@value != "" and !@known?} value={@value} selected>
        {t("A loop grid that is not on the page")}
      </option>
    </select>
    <p :if={@loops == []} class="exr-help">
      {t("Add a loop grid to the page: the filters work on it")}
    </p>
    """
  end

  defp control(%{prop: %Prop{control: :field}} = assigns) do
    source = assigns.dyn && assigns.dyn.own_source

    fields =
      case {source, assigns.prop.only} do
        {nil, _only} -> []
        {source, :sortable} -> Enum.filter(source.fields, & &1.sortable)
        {source, :filterable} -> Enum.filter(source.fields, & &1.filterable)
        {source, _only} -> source.fields
      end

    assigns =
      assign(assigns,
        fields: fields,
        known?: Enum.any?(fields, &(&1.key == assigns.value)),
        empty: if(assigns.prop.only == :sortable, do: "Default order", else: "Choose a field")
      )

    ~H"""
    <select id={@id} name={@name} class="exr-input exr-select">
      <option value="">{t(@empty)}</option>
      <option :for={field <- @fields} value={field.key} selected={@value == field.key}>
        {t(field.label)}
      </option>
      <option :if={@value != "" and !@known?} value={@value} selected>{@value}</option>
    </select>
    """
  end

  defp control(%{prop: %Prop{control: :select}} = assigns) do
    ~H"""
    <select id={@id} name={@name} class="exr-input exr-select">
      <option
        :for={{label, value} <- @prop.options}
        value={value}
        selected={to_string(@value) == value}
      >
        {t(label)}
      </option>
    </select>
    """
  end

  defp control(%{prop: %Prop{control: :segmented}} = assigns) do
    ~H"""
    <div class="exr-seg exr-seg-full" role="radiogroup" id={@id}>
      <label
        :for={{label, value} <- @prop.options}
        class={["exr-seg-item", to_string(@value) == value && "is-on"]}
        title={t(label)}
      >
        <input type="radio" name={@name} value={value} checked={to_string(@value) == value} />
        <span>{t(label)}</span>
      </label>
    </div>
    """
  end

  defp control(%{prop: %Prop{control: :swatches}} = assigns) do
    ~H"""
    <div class="exr-swatches" role="radiogroup" id={@id}>
      <label
        :for={{label, value} <- @prop.options}
        class={[
          "exr-swatch",
          to_string(@value) == value && "is-on",
          value in ["default", "current", "base"] && "is-default"
        ]}
        style={swatch_style(value)}
        title={t(label)}
      >
        <input type="radio" name={@name} value={value} checked={to_string(@value) == value} />
      </label>
    </div>
    """
  end

  defp control(%{prop: %Prop{control: :datetime}} = assigns) do
    ~H"""
    <input type="datetime-local" id={@id} name={@name} value={@value} class="exr-input" />
    """
  end

  defp control(%{prop: %Prop{control: :color}} = assigns) do
    ~H"""
    <.color_input id={@id} name={@name} value={@value} />
    """
  end

  defp control(%{prop: %Prop{control: :icon}} = assigns) do
    ~H"""
    <div class="exr-iconpick" id={@id}>
      <button
        type="button"
        class="exr-iconpick-preview"
        phx-click="picker_open"
        phx-value-prop={@list || @prop.key}
        phx-value-index={@index}
        phx-value-field={@list && @prop.key}
        phx-target={@target}
        title={t("Choose an icon")}
      >
        <Heroicons.icon :if={@value != ""} name={@value} class="exr-i-lg" />
        <.i :if={@value == ""} name="plus" />
      </button>
      <div class="exr-iconpick-name">
        <span class="exr-mono">{if(@value == "", do: t("No icon"), else: @value)}</span>
        <button
          type="button"
          class="exr-link"
          phx-click="picker_open"
          phx-value-prop={@list || @prop.key}
          phx-value-index={@index}
          phx-value-field={@list && @prop.key}
          phx-target={@target}
        >
          {if(@value == "", do: t("Choose"), else: t("Change"))}
        </button>
      </div>
      <button
        :if={@value != ""}
        type="button"
        class="exr-icon-btn"
        title={t("Remove icon")}
        phx-click="value_set"
        phx-value-prop={@list || @prop.key}
        phx-value-index={@index}
        phx-value-field={@list && @prop.key}
        phx-value-value=""
        phx-target={@target}
      >
        <.i name="x-mark" />
      </button>
      <input type="hidden" name={@name} value={@value} />
    </div>
    """
  end

  defp control(%{prop: %Prop{control: :image}} = assigns) do
    ~H"""
    <div class="exr-image" id={@id}>
      <div class={["exr-image-thumb", @value == "" && "is-empty"]}>
        <img :if={@value != ""} src={@value} alt="" />
        <.i :if={@value == ""} name="photo" />
      </div>
      <div class="exr-image-side">
        <div :if={@media} class="exr-image-actions">
          <label
            class="exr-btn exr-btn-sm"
            phx-click="upload_target"
            phx-value-prop={@list || @prop.key}
            phx-value-index={@index}
            phx-value-field={@list && @prop.key}
            phx-target={@target}
          >
            <.i name="arrow-up-tray" />{t("Upload")}
            <.live_file_input :if={@uploads} upload={@uploads.exr_image} class="exr-hidden" />
          </label>
          <button
            type="button"
            class="exr-btn exr-btn-sm"
            phx-click="library_open"
            phx-value-prop={@list || @prop.key}
            phx-value-index={@index}
            phx-value-field={@list && @prop.key}
            phx-target={@target}
          >
            <.i name="photo" />{t("Library")}
          </button>
        </div>
        <div class="exr-input exr-input-icon">
          <.i name="link" />
          <input
            type="text"
            name={@name}
            value={@value}
            placeholder="https://…"
            phx-debounce="400"
            spellcheck="false"
          />
        </div>
        <.upload_progress :if={@uploads} upload={@uploads.exr_image} />
      </div>
    </div>
    """
  end

  defp control(assigns) do
    ~H"""
    <input
      type="text"
      id={@id}
      name={@name}
      value={to_string(@value)}
      class="exr-input"
      phx-debounce="250"
    />
    """
  end

  attr :upload, :any, required: true

  defp upload_progress(assigns) do
    ~H"""
    <div :for={entry <- @upload.entries} class="exr-progress">
      <span style={"width:#{entry.progress}%"}></span>
    </div>
    <p :for={error <- upload_errors(@upload)} class="exr-error">{upload_error(error)}</p>
    """
  end

  defp upload_error(:too_large), do: t("The file is too large")
  defp upload_error(:not_accepted), do: t("That file type is not allowed")
  defp upload_error(:too_many_files), do: t("Only one file at a time")
  defp upload_error(_error), do: t("The file could not be uploaded")

  ## Repeater (list props)

  defp repeater(assigns) do
    assigns = assign(assigns, :items, assigns.value || [])

    ~H"""
    <div class="exr-field exr-repeater" id={@id}>
      <div class="exr-label">
        {t(@prop.label)} <span class="exr-count">{length(@items)}</span>
      </div>
      <input type="hidden" name={"#{@name}[__present]"} value="" />
      <div class="exr-rep-items">
        <div
          :for={{item, index} <- Enum.with_index(@items)}
          class="exr-rep-item"
          id={"#{@id}-#{item["id"]}"}
        >
          <div class="exr-rep-head">
            <button
              type="button"
              class="exr-rep-toggle"
              phx-click={JS.toggle_class("is-open", to: "##{@id}-#{item["id"]}")}
            >
              <.i name="chevron-right" class="exr-rep-caret" />
              <span class="exr-rep-title">{item_title(@prop, item, index, @dyn)}</span>
            </button>
            <button
              type="button"
              class="exr-icon-btn"
              title={t("Move up")}
              phx-click="list_move"
              phx-value-prop={@prop.key}
              phx-value-index={index}
              phx-value-dir="up"
              phx-target={@target}
              disabled={index == 0}
            >
              <.i name="chevron-up" />
            </button>
            <button
              type="button"
              class="exr-icon-btn"
              title={t("Move down")}
              phx-click="list_move"
              phx-value-prop={@prop.key}
              phx-value-index={index}
              phx-value-dir="down"
              phx-target={@target}
              disabled={index == length(@items) - 1}
            >
              <.i name="chevron-down" />
            </button>
            <button
              type="button"
              class="exr-icon-btn"
              title={t("Duplicate")}
              phx-click="list_duplicate"
              phx-value-prop={@prop.key}
              phx-value-index={index}
              phx-target={@target}
            >
              <.i name="document-duplicate" />
            </button>
            <button
              type="button"
              class="exr-icon-btn is-danger"
              title={t("Remove")}
              phx-click="list_remove"
              phx-value-prop={@prop.key}
              phx-value-index={index}
              phx-target={@target}
            >
              <.i name="trash" />
            </button>
          </div>
          <div class="exr-rep-body">
            <input type="hidden" name={"#{@name}[#{index}][id]"} value={item["id"]} />
            <.prop
              :for={field <- @prop.fields}
              prop={field}
              value={item[field.key]}
              name={"#{@name}[#{index}][#{field.key}]"}
              id={"#{@id}-#{item["id"]}-#{field.key}"}
              target={@target}
              uploads={@uploads}
              media={@media}
              index={index}
              list={@prop.key}
              dyn={@dyn}
            />
          </div>
        </div>
      </div>
      <button
        :if={length(@items) < @prop.max_items}
        type="button"
        class="exr-btn exr-btn-sm exr-btn-dashed"
        phx-click="list_add"
        phx-value-prop={@prop.key}
        phx-target={@target}
      >
        <.i name="plus" />{t("Add item")}
      </button>
    </div>
    """
  end

  defp item_title(prop, item, index, dyn) do
    label = prop.item_label && item[prop.item_label]
    label = if label == "", do: nil, else: field_label(prop, label, dyn)

    case label && ElementorexCms.HTML.Sanitizer.text(to_string(label)) do
      text when is_binary(text) and text != "" -> text
      _ -> t("Item %{n}", n: index + 1)
    end
  end

  # Items titled by a field of the block's source (the filters of a loop) show
  # the name of the field.
  defp field_label(prop, key, %{own_source: %Source{} = source}) when is_binary(key) do
    with %Prop{type: :field} <- Enum.find(prop.fields, &(&1.key == prop.item_label)),
         %Source.Field{label: label} <- Source.field(source, key) do
      t(label)
    else
      _ -> key
    end
  end

  defp field_label(_prop, label, _dyn), do: label

  ## Shared inputs

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, required: true
  attr :placeholder, :string, default: nil

  def color_input(assigns) do
    assigns = assign(assigns, :value, assigns.value || "")

    ~H"""
    <div class="exr-color" id={@id}>
      <div class="exr-swatches exr-swatches-sm" role="radiogroup">
        <label
          :for={{label, value, key} <- theme_colors()}
          class={["exr-swatch", @value == value && "is-on"]}
          style={"--sw: var(--exr-theme-#{key}, #{value})"}
          title={t(label)}
        >
          <input
            type="radio"
            name={suffixed(@name, "swatch")}
            value={value}
            checked={@value == value}
          />
        </label>
        <label class={["exr-swatch is-none", @value == "" && "is-on"]} title={t("Default")}>
          <input type="radio" name={suffixed(@name, "swatch")} value="" checked={@value == ""} />
        </label>
      </div>
      <div class="exr-color-custom">
        <input
          type="color"
          value={hex_or_default(@value)}
          name={suffixed(@name, "picker")}
          class="exr-color-native"
          title={t("Custom color")}
        />
        <input
          type="text"
          name={@name}
          value={@value}
          class="exr-input exr-mono"
          placeholder={@placeholder || "#000000 · var(--…)"}
          phx-debounce="400"
          spellcheck="false"
        />
      </div>
    </div>
    """
  end

  # `style[color]` → `style[color__swatch]`: the swatches, the native color
  # picker and the text field each send their own key, and the editor reads the
  # one that changed (with a shared name the last input would always win).
  defp suffixed(name, suffix), do: String.replace_suffix(name, "]", "__#{suffix}]")

  defp hex_or_default("#" <> _ = hex) when byte_size(hex) == 7, do: hex
  defp hex_or_default(_value), do: "#000000"

  defp swatch_style(value) when value in ["default", "current", "base"], do: nil
  defp swatch_style(value), do: "--sw: var(--exr-theme-#{value}, var(--color-#{value}, #999))"

  ## Style tab

  attr :field, :map, required: true
  attr :values, :map, required: true, doc: "values of the current state"
  attr :inherited, :map, required: true, doc: "values the current state inherits"
  attr :id, :string, required: true
  attr :linked, :any, required: true
  attr :target, :any, required: true
  attr :media, :any, default: nil
  attr :uploads, :any, default: nil

  def style_field(%{field: %{control: control}} = assigns) when control in [:sides, :corners] do
    group = assigns.field.property
    properties = Map.fetch!(ElementorexCms.Editor.StyleFields.groups(), group)

    labels =
      if control == :corners,
        do: [t("Top left"), t("Top right"), t("Bottom right"), t("Bottom left")],
        else: [t("Top"), t("Right"), t("Bottom"), t("Left")]

    assigns =
      assigns
      |> assign(:group, group)
      |> assign(:sides, Enum.zip(properties, labels))
      |> assign(:linked?, MapSet.member?(assigns.linked, group))

    ~H"""
    <div class="exr-field">
      <div class="exr-label">
        {t(@field.label)}
        <span
          :if={Enum.any?(@sides, fn {p, _} -> @values[p] end)}
          class="exr-dot"
          title={t("Has a value")}
        ></span>
      </div>
      <div class="exr-sides">
        <label :for={{property, label} <- @sides} class="exr-side" title={label}>
          <input
            type="text"
            name={"style[#{property}]"}
            value={@values[property]}
            placeholder={@inherited[property] || "–"}
            phx-debounce="350"
            spellcheck="false"
          />
          <span>{String.first(label)}</span>
        </label>
        <button
          type="button"
          class={["exr-icon-btn exr-link-btn", @linked? && "is-on"]}
          phx-click="toggle_link"
          phx-value-group={@group}
          phx-target={@target}
          title={
            if(@linked?, do: t("Linked: one value for all sides"), else: t("Each side on its own"))
          }
        >
          <.i name={if(@linked?, do: "link", else: "link-slash")} />
        </button>
      </div>
    </div>
    """
  end

  def style_field(assigns) do
    property = assigns.field.property

    assigns =
      assigns
      |> assign(:property, property)
      |> assign(:value, assigns.values[property])
      |> assign(:inherit, assigns.inherited[property])
      |> assign(:name, "style[#{property}]")

    ~H"""
    <div class={["exr-field", "exr-style-#{@field.control}"]}>
      <label class="exr-label" for={"#{@id}-#{@property}"}>
        {t(@field.label)}
        <span :if={@value} class="exr-dot" title={t("Has a value")}></span>
      </label>
      {style_control(assigns)}
    </div>
    """
  end

  defp style_control(%{field: %{control: :length}} = assigns) do
    ~H"""
    <input
      type="text"
      id={"#{@id}-#{@property}"}
      name={@name}
      value={@value}
      placeholder={@inherit || @field[:placeholder]}
      class="exr-input"
      phx-debounce="350"
      spellcheck="false"
    />
    """
  end

  defp style_control(%{field: %{control: :number}} = assigns) do
    ~H"""
    <input
      type="number"
      id={"#{@id}-#{@property}"}
      name={@name}
      value={@value}
      placeholder={@inherit}
      min={@field[:min]}
      max={@field[:max]}
      step={@field[:step]}
      class="exr-input"
      phx-debounce="300"
    />
    """
  end

  defp style_control(%{field: %{control: :range}} = assigns) do
    ~H"""
    <div class="exr-range">
      <input
        type="range"
        id={"#{@id}-#{@property}"}
        name={@name}
        value={@value || @inherit || @field[:max]}
        min={@field[:min]}
        max={@field[:max]}
        step={@field[:step]}
        phx-debounce="80"
      />
      <output>{@value || @inherit || "–"}</output>
    </div>
    """
  end

  defp style_control(%{field: %{control: :select}} = assigns) do
    ~H"""
    <select id={"#{@id}-#{@property}"} name={@name} class="exr-input exr-select">
      <option :for={{label, value} <- @field.options} value={value} selected={(@value || "") == value}>
        {if(value == "" and @inherit, do: t("Inherit (%{value})", value: @inherit), else: t(label))}
      </option>
    </select>
    """
  end

  defp style_control(%{field: %{control: :segmented}} = assigns) do
    ~H"""
    <div class="exr-seg exr-seg-full">
      <label
        :for={{label, value} <- @field.options}
        class={[
          "exr-seg-item",
          @value == value && "is-on",
          !@value && @inherit == value && "is-inherited"
        ]}
        title={t(label)}
      >
        <input type="radio" name={@name} value={value} checked={@value == value} />
        <span>{t(label)}</span>
      </label>
      <label :if={@value} class="exr-seg-item exr-seg-clear" title={t("Clear")}>
        <input type="radio" name={@name} value="" />
        <.i name="x-mark" />
      </label>
    </div>
    """
  end

  defp style_control(%{field: %{control: :icons}} = assigns) do
    ~H"""
    <div class="exr-seg exr-seg-full">
      <label
        :for={{label, value, icon} <- @field.options}
        class={[
          "exr-seg-item",
          @value == value && "is-on",
          !@value && @inherit == value && "is-inherited"
        ]}
        title={t(label)}
      >
        <input type="radio" name={@name} value={value} checked={@value == value} />
        <.i name={icon} />
      </label>
      <label :if={@value} class="exr-seg-item exr-seg-clear" title={t("Clear")}>
        <input type="radio" name={@name} value="" />
        <.i name="x-mark" />
      </label>
    </div>
    """
  end

  defp style_control(%{field: %{control: :color}} = assigns) do
    ~H"""
    <.color_input id={"#{@id}-#{@property}"} name={@name} value={@value} placeholder={@inherit} />
    """
  end

  defp style_control(%{field: %{control: :background_image}} = assigns) do
    assigns = assign(assigns, :url, background_url(assigns.value))

    ~H"""
    <div class="exr-image">
      <div class={["exr-image-thumb", !@url && "is-empty"]}>
        <img :if={@url} src={@url} alt="" />
        <.i :if={!@url} name="photo" />
      </div>
      <div class="exr-image-side">
        <div :if={@media} class="exr-image-actions">
          <label
            class="exr-btn exr-btn-sm"
            phx-click="upload_target"
            phx-value-prop="__style"
            phx-value-style={@property}
            phx-target={@target}
          >
            <.i name="arrow-up-tray" />{t("Upload")}
          </label>
          <button
            type="button"
            class="exr-btn exr-btn-sm"
            phx-click="library_open"
            phx-value-prop="__style"
            phx-value-style={@property}
            phx-target={@target}
          >
            <.i name="photo" />{t("Library")}
          </button>
        </div>
        <div class="exr-input exr-input-icon">
          <.i name="link" />
          <input
            type="text"
            name={@name}
            value={@value}
            placeholder="url(https://…)"
            phx-debounce="400"
            spellcheck="false"
          />
        </div>
      </div>
    </div>
    """
  end

  defp background_url(nil), do: nil

  defp background_url(value) do
    case Regex.run(~r/url\(\s*["']?([^"')]+)["']?\s*\)/, value) do
      [_, url] -> url
      _ -> nil
    end
  end
end
