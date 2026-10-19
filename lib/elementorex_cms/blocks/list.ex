defmodule ElementorexCms.Blocks.List do
  @moduledoc "List of items, each with a Heroicon (checks, benefits, steps...)."

  use ElementorexCms.Block,
    type: "list",
    label: "Icon list",
    icon: "list-bullet",
    category: :basic,
    description: "Items with an icon each",
    keywords: ~w(bullets checklist benefits lista viñetas)

  alias ElementorexCms.Blocks.Options

  prop(:items, :list,
    label: "Items",
    item_label: :text,
    max_items: 30,
    default: [
      %{"text" => "First benefit"},
      %{"text" => "Second benefit"},
      %{"text" => "Third benefit"}
    ],
    fields: [
      {:text, :richtext, label: "Text", default: "Item", policy: :inline, control: :textarea},
      {:icon, :icon, label: "Icon (optional)"}
    ]
  )

  prop(:icon, :icon, label: "Icon", default: "check-circle")

  prop(:icon_style, :select,
    label: "Icon style",
    options: Options.icon_styles(),
    default: "solid",
    control: :segmented
  )

  prop(:color, :select,
    label: "Icon color",
    options: Options.text_colors(),
    default: "success",
    control: :swatches
  )

  prop(:spacing, :select,
    label: "Spacing",
    options: [{"S", "1"}, {"M", "2"}, {"L", "3"}, {"XL", "4"}],
    default: "2",
    control: :segmented
  )

  prop(:divider, :boolean, label: "Lines between items", default: false)

  @text %{
    "current" => nil,
    "base" => "text-base-content",
    "primary" => "text-primary",
    "secondary" => "text-secondary",
    "accent" => "text-accent",
    "neutral" => "text-neutral",
    "info" => "text-info",
    "success" => "text-success",
    "warning" => "text-warning",
    "error" => "text-error"
  }
  @gaps %{"1" => "gap-1", "2" => "gap-2", "3" => "gap-3", "4" => "gap-4"}

  def render(assigns) do
    ~H"""
    <ul {root(assigns, class: ["flex flex-col", Map.get(gaps(), @spacing), @divider && "divide-y divide-base-300 [&>li]:pt-2 [&>li:first-child]:pt-0"])}>
      <li :for={item <- @items} class="flex items-start gap-2.5">
        <.heroicon
          name={if(item["icon"] != "", do: item["icon"], else: @icon)}
          style={@icon_style}
          class={["mt-0.5 size-5 shrink-0", Map.get(text_colors(), @color)]}
        />
        <span class="min-w-0">{rich_inline(item["text"])}</span>
      </li>
    </ul>
    """
  end

  defp text_colors, do: @text
  defp gaps, do: @gaps
end
