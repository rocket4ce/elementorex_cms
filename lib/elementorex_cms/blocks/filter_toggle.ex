defmodule ElementorexCms.Blocks.FilterToggle do
  @moduledoc """
  Toggle filter of a *Filters* form: when on, only the items whose field has a
  value (`true` by default) are shown. *Only featured*, *In stock* (a filter
  of the source with logic of its own)…
  """

  use ElementorexCms.Block,
    type: "filter_toggle",
    label: "Toggle filter",
    icon: "check-circle",
    category: :dynamic,
    description: "A switch that keeps only the items with a value",
    keywords: ~w(toggle switch checkbox only boolean interruptor solo casilla),
    parents: ["filters"]

  alias ElementorexCms.Blocks.FilterField

  prop(:field, :field, label: "Field", only: :filterable)
  prop(:label, :string, label: "Label", help: "Empty: the name of the field")
  prop(:value, :string, label: "Value", default: "true", help: "What the field must be")

  prop(:style, :select,
    label: "Style",
    options: [{"Switch", "toggle"}, {"Checkbox", "checkbox"}],
    default: "toggle",
    control: :segmented
  )

  def render(assigns) do
    if filter_form?(assigns) and assigns.field != "" do
      assigns = assign(assigns, :title, FilterField.label(assigns, assigns.field))

      ~H"""
      <label {root(assigns, class: "flex min-h-10 cursor-pointer items-center gap-2")}>
        <input
          type="checkbox"
          class={if(@style == "checkbox", do: "checkbox checkbox-sm", else: "toggle toggle-sm")}
          name={filter_name(assigns, @field)}
          value={@value}
          checked={filter_checked?(assigns, @field, @value)}
        />
        <span>{@title}</span>
      </label>
      """
    else
      FilterField.outside(%{assigns: assigns, __changed__: nil})
    end
  end
end
