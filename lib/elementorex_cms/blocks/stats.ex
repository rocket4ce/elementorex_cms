defmodule ElementorexCms.Blocks.Stats do
  @moduledoc "daisyUI stats: figures with title, value, description and icon."

  use ElementorexCms.Block,
    type: "stats",
    label: "Stats",
    icon: "chart-bar",
    category: :components,
    description: "Key figures",
    keywords: ~w(numbers figures kpi metrics cifras numeros)

  prop(:items, :list,
    label: "Figures",
    item_label: :title,
    max_items: 6,
    default: [
      %{"title" => "Customers", "value" => "25K", "desc" => "Since 2020", "icon" => "users"},
      %{
        "title" => "Claims paid",
        "value" => "98%",
        "desc" => "In under 72 hours",
        "icon" => "check-badge"
      },
      %{"title" => "Rating", "value" => "4.9", "desc" => "Out of 5", "icon" => "star"}
    ],
    fields: [
      {:title, :string, label: "Title", default: "Title"},
      {:value, :string, label: "Value", default: "0"},
      {:desc, :string, label: "Description"},
      {:icon, :icon, label: "Icon"}
    ]
  )

  prop(:direction, :select,
    label: "Direction",
    options: [{"Horizontal", "horizontal"}, {"Vertical", "vertical"}],
    default: "horizontal",
    control: :segmented
  )

  prop(:color, :select,
    label: "Value color",
    options: [
      {"Default", "default"},
      {"Primary", "primary"},
      {"Secondary", "secondary"},
      {"Accent", "accent"}
    ],
    default: "primary",
    control: :swatches
  )

  prop(:shadow, :boolean, label: "Shadow", default: true)

  @colors %{
    "default" => nil,
    "primary" => "text-primary",
    "secondary" => "text-secondary",
    "accent" => "text-accent"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns,
      class: ["stats w-full bg-base-100", if(@direction == "vertical", do: "stats-vertical", else: "stats-horizontal max-md:stats-vertical"), @shadow && "shadow"]
    )}>
      <div :for={item <- @items} class="stat">
        <div :if={item["icon"] != ""} class={["stat-figure", Map.get(colors(), @color)]}>
          <.heroicon name={item["icon"]} class="size-8" />
        </div>
        <div class="stat-title">{item["title"]}</div>
        <div class={["stat-value", Map.get(colors(), @color)]}>{item["value"]}</div>
        <div :if={item["desc"] != ""} class="stat-desc">{item["desc"]}</div>
      </div>
    </div>
    """
  end

  defp colors, do: @colors
end
