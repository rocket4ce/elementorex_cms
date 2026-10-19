defmodule ElementorexCms.Blocks.Badge do
  @moduledoc "daisyUI badge: a small label."

  use ElementorexCms.Block,
    type: "badge",
    label: "Badge",
    icon: "tag",
    category: :components,
    description: "Small label or tag",
    keywords: ~w(tag label pill chip etiqueta)

  alias ElementorexCms.Blocks.Options

  prop(:text, :string, label: "Text", default: "New", inline: true)

  prop(:color, :select,
    label: "Color",
    options: Options.colors_with_default(),
    default: "primary",
    control: :swatches
  )

  prop(:variant, :select,
    label: "Style",
    options: Options.variants() ++ [{"Ghost", "ghost"}],
    default: "soft"
  )

  prop(:size, :select,
    label: "Size",
    options: Options.sizes(),
    default: "md",
    control: :segmented
  )

  prop(:icon, :icon, label: "Icon")

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented
  )

  @colors %{
    "default" => nil,
    "primary" => "badge-primary",
    "secondary" => "badge-secondary",
    "accent" => "badge-accent",
    "neutral" => "badge-neutral",
    "info" => "badge-info",
    "success" => "badge-success",
    "warning" => "badge-warning",
    "error" => "badge-error"
  }
  @variants %{
    "solid" => nil,
    "soft" => "badge-soft",
    "outline" => "badge-outline",
    "dash" => "badge-dash",
    "ghost" => "badge-ghost"
  }
  @sizes %{
    "xs" => "badge-xs",
    "sm" => "badge-sm",
    "md" => "badge-md",
    "lg" => "badge-lg",
    "xl" => "badge-xl"
  }
  @align %{"left" => "mr-auto", "center" => "mx-auto", "right" => "ml-auto"}

  def render(assigns) do
    ~H"""
    <span {root(assigns,
      class: ["badge flex w-fit gap-1.5", Map.get(colors(), @color), Map.get(variants(), @variant), Map.get(sizes(), @size), Map.get(aligns(), @align)]
    )}><.heroicon
      :if={@icon != ""}
      name={@icon}
      style="mini"
      class="size-[1.1em]"
    /><span {inline(assigns, :text)}>{@text}</span></span>
    """
  end

  defp colors, do: @colors
  defp variants, do: @variants
  defp sizes, do: @sizes
  defp aligns, do: @align
end
