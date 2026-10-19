defmodule ElementorexCms.Blocks.ButtonGroup do
  @moduledoc "Several buttons side by side, separate or joined (daisyUI `join`)."

  use ElementorexCms.Block,
    type: "button_group",
    label: "Buttons",
    icon: "squares-plus",
    category: :basic,
    description: "Group of buttons",
    keywords: ~w(buttons cta join botones grupo)

  alias ElementorexCms.Blocks.Options

  prop(:items, :list,
    label: "Buttons",
    item_label: :label,
    max_items: 8,
    default: [
      %{"label" => "Primary action", "url" => "#", "color" => "primary", "variant" => "solid"},
      %{"label" => "Secondary", "url" => "#", "color" => "default", "variant" => "ghost"}
    ],
    fields: [
      {:label, :string, label: "Text", default: "Button"},
      {:url, :url, label: "Link", default: "#"},
      {:new_tab, :boolean, label: "Open in a new tab", default: false},
      {:color, :select,
       label: "Color",
       options: Options.colors_with_default(),
       default: "primary",
       control: :swatches},
      {:variant, :select,
       label: "Style",
       options: Options.variants() ++ [{"Ghost", "ghost"}, {"Link", "link"}],
       default: "solid"},
      {:icon, :icon, label: "Icon"}
    ]
  )

  prop(:joined, :boolean, label: "Joined", default: false)

  prop(:size, :select,
    label: "Size",
    options: Options.sizes(),
    default: "md",
    control: :segmented
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments() ++ [{"Justify", "between"}],
    default: "left",
    control: :segmented
  )

  prop(:stack_on_mobile, :boolean, label: "Stack on mobile", default: false)

  @colors %{
    "default" => nil,
    "primary" => "btn-primary",
    "secondary" => "btn-secondary",
    "accent" => "btn-accent",
    "neutral" => "btn-neutral",
    "info" => "btn-info",
    "success" => "btn-success",
    "warning" => "btn-warning",
    "error" => "btn-error"
  }
  @variants %{
    "solid" => nil,
    "soft" => "btn-soft",
    "outline" => "btn-outline",
    "dash" => "btn-dash",
    "ghost" => "btn-ghost",
    "link" => "btn-link"
  }
  @sizes %{
    "xs" => "btn-xs",
    "sm" => "btn-sm",
    "md" => "btn-md",
    "lg" => "btn-lg",
    "xl" => "btn-xl"
  }
  @align %{
    "left" => "justify-start",
    "center" => "justify-center",
    "right" => "justify-end",
    "between" => "justify-between"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns,
      class: [
        "flex flex-wrap",
        if(@joined, do: "join", else: "gap-3"),
        Map.get(aligns(), @align),
        @stack_on_mobile && "max-md:flex-col max-md:items-stretch"
      ]
    )}>
      <a
        :for={item <- @items}
        class={[
          "btn",
          @joined && "join-item",
          Map.get(colors(), item["color"]),
          Map.get(variants(), item["variant"]),
          Map.get(sizes(), @size)
        ]}
        {link_attrs(item["url"], item["new_tab"])}
      >
        <.heroicon :if={item["icon"] != ""} name={item["icon"]} class="size-[1.2em]" />
        {item["label"]}
      </a>
    </div>
    """
  end

  defp colors, do: @colors
  defp variants, do: @variants
  defp sizes, do: @sizes
  defp aligns, do: @align
end
