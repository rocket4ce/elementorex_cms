defmodule ElementorexCms.Blocks.FilterRange do
  @moduledoc """
  Range filter of a *Filters* form: a minimum and a maximum for a number or a
  date field (a price between, a date from).
  """

  use ElementorexCms.Block,
    type: "filter_range",
    label: "Range filter",
    icon: "adjustments-horizontal",
    category: :dynamic,
    description: "From a minimum to a maximum of a number or a date",
    keywords: ~w(range price min max between date rango precio desde hasta),
    parents: ["filters"]

  alias ElementorexCms.Blocks.FilterField

  prop(:field, :field, label: "Field", only: :filterable)
  prop(:label, :string, label: "Label", help: "Empty: the name of the field")
  prop(:min_label, :string, label: "Minimum text", default: "Min")
  prop(:max_label, :string, label: "Maximum text", default: "Max")
  prop(:prefix, :string, label: "Before the values", placeholder: "$")
  prop(:step, :number, label: "Step", min: 0)

  def render(assigns) do
    if filter_form?(assigns) and assigns.field != "" do
      field = filter_field(assigns, assigns.field)

      assigns =
        assign(assigns,
          title: FilterField.label(assigns, assigns.field),
          type: if(field && field.type in [:date, :datetime], do: "date", else: "number")
        )

      ~H"""
      <fieldset {root(assigns, class: "flex min-w-48 flex-col gap-1")}>
        <legend :if={@title != ""} class="mb-1 text-sm font-medium">{@title}</legend>
        <div class="flex items-center gap-2">
          <label :for={{bound, text} <- [{"min", @min_label}, {"max", @max_label}]} class="input grow">
            <span :if={@prefix != ""} class="opacity-60">{@prefix}</span>
            <input
              type={@type}
              name={filter_name(assigns, [@field, bound])}
              value={filter_value(assigns, [@field, bound])}
              placeholder={text}
              step={@type == "number" && (@step || "any")}
              aria-label={text}
              class="w-full min-w-0"
              data-ex-filter-input="text"
            />
          </label>
        </div>
      </fieldset>
      """
    else
      FilterField.outside(%{assigns: assigns, __changed__: nil})
    end
  end
end
