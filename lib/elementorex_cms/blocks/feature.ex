defmodule ElementorexCms.Blocks.Feature do
  @moduledoc "Icon box: an icon with a title and a text, on top or to the left."

  use ElementorexCms.Block,
    type: "feature",
    label: "Icon box",
    icon: "rectangle-stack",
    category: :basic,
    description: "Icon with title and text",
    keywords: ~w(feature benefit icon box beneficio caracteristica)

  alias ElementorexCms.Blocks.Options

  prop(:icon, :icon, label: "Icon", default: "shield-check")

  prop(:icon_style, :select,
    label: "Icon style",
    options: Options.icon_styles(),
    default: "outline",
    control: :segmented
  )

  prop(:color, :select,
    label: "Color",
    options: Options.colors(),
    default: "primary",
    control: :swatches
  )

  prop(:title, :string, label: "Title", default: "A great benefit", inline: true)

  prop(:text, :richtext,
    label: "Text",
    default: "<p>Explain it in a sentence or two.</p>",
    inline: true
  )

  prop(:layout, :select,
    label: "Layout",
    options: [{"Icon on top", "top"}, {"Icon on the left", "left"}],
    default: "top",
    control: :segmented
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented,
    show_if: {:layout, "top"}
  )

  prop(:url, :url, label: "Link")

  @soft %{
    "primary" => "bg-primary/10 text-primary",
    "secondary" => "bg-secondary/10 text-secondary",
    "accent" => "bg-accent/10 text-accent",
    "neutral" => "bg-neutral/10 text-neutral",
    "info" => "bg-info/10 text-info",
    "success" => "bg-success/10 text-success",
    "warning" => "bg-warning/10 text-warning",
    "error" => "bg-error/10 text-error"
  }
  @align %{
    "left" => "items-start text-left",
    "center" => "items-center text-center",
    "right" => "items-end text-right"
  }

  def render(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={if(@url != "", do: "a", else: "div")}
      {root(assigns,
        class: ["flex gap-4", if(@layout == "left", do: "flex-row items-start", else: ["flex-col", Map.get(aligns(), @align)]), @url != "" && "group"],
        attrs: link_attrs(@url)
      )}
    >
      <span class={["grid size-12 shrink-0 place-items-center rounded-box", Map.get(softs(), @color)]}>
        <.heroicon name={@icon} style={@icon_style} class="size-6" />
      </span>
      <div class="flex min-w-0 flex-col gap-1">
        <h3 class="text-lg font-bold leading-snug group-hover:underline" {inline(assigns, :title)}>
          {@title}
        </h3>
        <div class="exr-rich text-sm leading-relaxed opacity-80" {inline(assigns, :text)}>
          {rich(@text)}
        </div>
      </div>
    </.dynamic_tag>
    """
  end

  defp softs, do: @soft
  defp aligns, do: @align
end
