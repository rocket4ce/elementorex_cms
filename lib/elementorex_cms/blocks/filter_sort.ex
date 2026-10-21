defmodule ElementorexCms.Blocks.FilterSort do
  @moduledoc """
  Sort of a *Filters* form: the visitor picks the order of the loop grid among
  the options written in the editor (a sortable field and a direction each).
  """

  use ElementorexCms.Block,
    type: "filter_sort",
    label: "Sort",
    icon: "arrows-up-down",
    category: :dynamic,
    description: "Visitors choose the order of the loop grid",
    keywords: ~w(sort order by price newest ordenar orden precio),
    parents: ["filters"]

  alias ElementorexCms.Blocks.FilterField

  prop(:label, :string, label: "Label", default: "Sort by")
  prop(:default_label, :string, label: "Text of the default order", default: "Recommended")

  prop(:options, :list,
    label: "Options",
    item_label: :label,
    max_items: 12,
    default: [],
    fields: [
      {:label, :string, label: "Text"},
      {:field, :field, label: "Field", only: :sortable},
      {:direction, :select,
       label: "Direction", options: [{"Ascending", "asc"}, {"Descending", "desc"}], default: "asc"}
    ]
  )

  def render(assigns) do
    if filter_form?(assigns) do
      options =
        for %{"field" => field} = option <- assigns.options, field != "" do
          value = if option["direction"] == "desc", do: "-" <> field, else: field
          label = if option["label"] in [nil, ""], do: field, else: option["label"]
          %{label: label, value: value}
        end

      assigns = assign(assigns, :choices, options)

      ~H"""
      <label {root(assigns, class: "flex min-w-40 flex-col gap-1")}>
        <span :if={@label != ""} class="text-sm font-medium">{@label}</span>
        <select class="select w-full" name={filter_name(assigns, "sort")}>
          <option value="">{@default_label}</option>
          <option
            :for={choice <- @choices}
            value={choice.value}
            selected={filter_checked?(assigns, "sort", choice.value)}
          >
            {choice.label}
          </option>
        </select>
      </label>
      """
    else
      FilterField.outside(%{assigns: assigns, __changed__: nil})
    end
  end
end
