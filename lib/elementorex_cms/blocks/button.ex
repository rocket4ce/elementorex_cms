defmodule ElementorexCms.Blocks.Button do
  @moduledoc "daisyUI button with link, colors, styles, sizes and a Heroicon."

  use ElementorexCms.Block,
    type: "button",
    label: "Button",
    icon: "cursor-arrow-rays",
    category: :basic,
    description: "Call to action with a link",
    keywords: ~w(cta link boton enlace)

  alias ElementorexCms.Blocks.Options

  prop(:label, :string, label: "Text", default: "Click here", inline: true)
  prop(:url, :url, label: "Link", default: "#")
  prop(:new_tab, :boolean, label: "Open in a new tab", default: false)

  prop(:color, :select,
    label: "Color",
    options: Options.colors_with_default(),
    default: "primary",
    control: :swatches,
    group: "Look"
  )

  prop(:variant, :select,
    label: "Style",
    options: Options.variants() ++ [{"Ghost", "ghost"}, {"Link", "link"}],
    default: "solid",
    group: "Look"
  )

  prop(:size, :select,
    label: "Size",
    options: Options.sizes(),
    default: "md",
    control: :segmented,
    group: "Look"
  )

  prop(:shape, :select,
    label: "Shape",
    options: [{"Default", "default"}, {"Pill", "pill"}, {"Square", "square"}],
    default: "default",
    control: :segmented,
    group: "Look"
  )

  prop(:wide, :boolean, label: "Full width", default: false, group: "Look")

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented,
    group: "Look",
    show_if: {:wide, false}
  )

  prop(:icon, :icon, label: "Icon", group: "Icon")

  prop(:icon_style, :select,
    label: "Icon style",
    options: Options.icon_styles(),
    default: "outline",
    control: :segmented,
    group: "Icon",
    show_if: {:icon, :present}
  )

  prop(:icon_position, :select,
    label: "Icon position",
    options: [{"Before", "start"}, {"After", "end"}],
    default: "end",
    control: :segmented,
    group: "Icon",
    show_if: {:icon, :present}
  )

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
  @shapes %{"default" => nil, "pill" => "rounded-full", "square" => "rounded-none"}
  @align %{"left" => "mr-auto", "center" => "mx-auto", "right" => "ml-auto"}

  def render(assigns) do
    ~H"""
    <a {root(assigns,
      class: [
        "btn",
        Map.get(colors(), @color),
        Map.get(variants(), @variant),
        Map.get(sizes(), @size),
        Map.get(shapes(), @shape),
        if(@wide, do: "btn-block", else: ["flex w-fit", Map.get(aligns(), @align)])
      ],
      attrs: link_attrs(@url, @new_tab)
    )}>
      <.heroicon
        :if={@icon != "" and @icon_position == "start"}
        name={@icon}
        style={@icon_style}
        class="size-[1.2em] shrink-0"
      />
      <span {inline(assigns, :label)}>{@label}</span>
      <.heroicon
        :if={@icon != "" and @icon_position == "end"}
        name={@icon}
        style={@icon_style}
        class="size-[1.2em] shrink-0"
      />
    </a>
    """
  end

  defp colors, do: @colors
  defp variants, do: @variants
  defp sizes, do: @sizes
  defp shapes, do: @shapes
  defp aligns, do: @align
end
