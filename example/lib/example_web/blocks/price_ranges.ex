defmodule ExampleWeb.Blocks.PriceRanges do
  @moduledoc """
  Price ranges: a filter of the visitors' *Filters* forms (ElementorexCms).
  Visitors pick one of the ranges written in the editor; each sends
  `min..max` for the field (`catalog[price]=20000..50000`).
  """

  use ElementorexCms.Block,
    type: "price_ranges",
    label: "Price ranges",
    icon: "funnel",
    category: :dynamic,
    description: "Pick one of a few ranges of a field",
    parents: ["filters"]

  prop :field, :field, label: "Field", only: :filterable
  prop :label, :string, label: "Label"

  prop :ranges, :list,
    label: "Ranges",
    item_label: :label,
    default: [
      %{"label" => "Under $20.000", "min" => "", "max" => "20000"},
      %{"label" => "$20.000 to $50.000", "min" => "20000", "max" => "50000"},
      %{"label" => "Over $50.000", "min" => "50000", "max" => ""}
    ],
    fields: [
      {:label, :string, label: "Text"},
      {:min, :string, label: "From"},
      {:max, :string, label: "To"}
    ]

  def render(assigns) do
    if filter_form?(assigns) and assigns.field != "" do
      ~H"""
      <fieldset {root(assigns, class: "flex flex-col gap-1")}>
        <legend :if={@label != ""} class="mb-1 text-sm font-medium">{@label}</legend>
        <label class="flex cursor-pointer items-center gap-2">
          <input
            type="radio"
            class="radio radio-sm"
            name={filter_name(assigns, @field)}
            value=""
            checked={filter_value(assigns, @field) in [nil, ""]}
          />
          <span>{t("All")}</span>
        </label>
        <label :for={range <- @ranges} class="flex cursor-pointer items-center gap-2">
          <input
            type="radio"
            class="radio radio-sm"
            name={filter_name(assigns, @field)}
            value={"#{range["min"]}..#{range["max"]}"}
            checked={filter_checked?(assigns, @field, "#{range["min"]}..#{range["max"]}")}
          />
          <span>{range["label"]}</span>
        </label>
      </fieldset>
      """
    else
      # Outside a Filters form: a hint on the canvas, nothing on the site.
      ~H"""
      <p {root(assigns, class: "text-sm opacity-60")} hidden={!editor?(assigns)}>
        {t("Put it in a Filters block that filters a loop grid")}
      </p>
      """
    end
  end
end
