defmodule ElementorexCms.Blocks.Icon do
  @moduledoc "A Heroicon, with size, color and an optional circle behind it."

  use ElementorexCms.Block,
    type: "icon",
    label: "Icon",
    icon: "star",
    category: :basic,
    description: "Heroicons icon",
    keywords: ~w(heroicons symbol icono simbolo)

  alias ElementorexCms.Blocks.Options

  prop(:name, :icon, label: "Icon", default: "star")

  prop(:style, :select,
    label: "Style",
    options: Options.icon_styles(),
    default: "outline",
    control: :segmented
  )

  prop(:size, :select,
    label: "Size",
    options: [{"S", "sm"}, {"M", "md"}, {"L", "lg"}, {"XL", "xl"}, {"2XL", "2xl"}],
    default: "lg",
    control: :segmented
  )

  prop(:color, :select,
    label: "Color",
    options: Options.text_colors(),
    default: "primary",
    control: :swatches
  )

  prop(:background, :select,
    label: "Background",
    options: [{"None", "none"}, {"Soft", "soft"}, {"Solid", "solid"}],
    default: "none",
    control: :segmented
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented
  )

  prop(:url, :url, label: "Link")

  prop(:label, :string,
    label: "Accessible label",
    help: "Read by screen readers when the icon means something"
  )

  @sizes %{
    "sm" => "size-4",
    "md" => "size-6",
    "lg" => "size-8",
    "xl" => "size-12",
    "2xl" => "size-16"
  }
  @pads %{"sm" => "p-1.5", "md" => "p-2", "lg" => "p-3", "xl" => "p-4", "2xl" => "p-5"}
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
  @soft %{
    "current" => "bg-base-200",
    "base" => "bg-base-200",
    "primary" => "bg-primary/10",
    "secondary" => "bg-secondary/10",
    "accent" => "bg-accent/10",
    "neutral" => "bg-neutral/10",
    "info" => "bg-info/10",
    "success" => "bg-success/10",
    "warning" => "bg-warning/10",
    "error" => "bg-error/10"
  }
  @solid %{
    "current" => "bg-base-content text-base-100",
    "base" => "bg-base-content text-base-100",
    "primary" => "bg-primary text-primary-content",
    "secondary" => "bg-secondary text-secondary-content",
    "accent" => "bg-accent text-accent-content",
    "neutral" => "bg-neutral text-neutral-content",
    "info" => "bg-info text-info-content",
    "success" => "bg-success text-success-content",
    "warning" => "bg-warning text-warning-content",
    "error" => "bg-error text-error-content"
  }
  @align %{"left" => "mr-auto", "center" => "mx-auto", "right" => "ml-auto"}

  def render(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={if(@url != "", do: "a", else: "span")}
      {root(assigns,
        class: ["flex w-fit shrink-0 items-center justify-center", Map.get(aligns(), @align) | wrapper(@background, @color, @size)],
        attrs: link_attrs(@url) ++ if(@label != "", do: [{"aria-label", @label}, {"role", "img"}], else: [])
      )}
    >
      <.heroicon name={@name} style={@style} class={Map.get(sizes(), @size)} />
    </.dynamic_tag>
    """
  end

  defp wrapper("soft", color, size), do: ["rounded-full", @soft[color], @text[color], @pads[size]]
  defp wrapper("solid", color, size), do: ["rounded-full", @solid[color], @pads[size]]
  defp wrapper(_none, color, _size), do: [@text[color]]

  defp sizes, do: @sizes
  defp aligns, do: @align
end
