defmodule ElementorexCms.Blocks.Link do
  @moduledoc "daisyUI link: a text link with color and hover underline."

  use ElementorexCms.Block,
    type: "link",
    label: "Link",
    icon: "link",
    category: :basic,
    description: "Text link",
    keywords: ~w(anchor url enlace vinculo)

  alias ElementorexCms.Blocks.Options

  prop(:label, :string, label: "Text", default: "Learn more", inline: true)
  prop(:url, :url, label: "Link", default: "#")
  prop(:new_tab, :boolean, label: "Open in a new tab", default: false)

  prop(:color, :select,
    label: "Color",
    options: Options.colors_with_default(),
    default: "primary",
    control: :swatches
  )

  prop(:hover, :boolean, label: "Underline only on hover", default: true)
  prop(:icon, :icon, label: "Icon", default: "arrow-right")

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented
  )

  @colors %{
    "default" => nil,
    "primary" => "link-primary",
    "secondary" => "link-secondary",
    "accent" => "link-accent",
    "neutral" => "link-neutral",
    "info" => "link-info",
    "success" => "link-success",
    "warning" => "link-warning",
    "error" => "link-error"
  }
  @align %{"left" => "mr-auto", "center" => "mx-auto", "right" => "ml-auto"}

  def render(assigns) do
    ~H"""
    <a {root(assigns,
      class: ["link inline-flex w-fit items-center gap-1.5 font-medium", Map.get(colors(), @color), @hover && "link-hover", Map.get(aligns(), @align)],
      attrs: link_attrs(@url, @new_tab)
    )}><span {inline(assigns, :label)}>{@label}</span><.heroicon
      name={@icon}
      class="size-4"
    /></a>
    """
  end

  defp colors, do: @colors
  defp aligns, do: @align
end
