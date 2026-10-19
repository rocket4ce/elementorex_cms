defmodule ElementorexCms.Blocks.Text do
  @moduledoc "Rich text: paragraphs, lists, links and formatting."

  use ElementorexCms.Block,
    type: "text",
    label: "Text",
    icon: "bars-3-bottom-left",
    category: :basic,
    description: "Paragraphs with formatting, lists and links",
    keywords: ~w(paragraph rich editor parrafo texto)

  alias ElementorexCms.Blocks.Options

  prop(:text, :richtext,
    label: "Text",
    default: "<p>Write something here. Double-click on the canvas to edit it in place.</p>",
    inline: true
  )

  prop(:size, :select,
    label: "Size",
    options: [{"XS", "xs"}, {"S", "sm"}, {"M", "base"}, {"L", "lg"}, {"XL", "xl"}],
    default: "base",
    control: :segmented
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments() ++ [{"Justify", "justify"}],
    default: "left",
    control: :segmented
  )

  prop(:muted, :boolean, label: "Muted color", default: false)

  @sizes %{
    "xs" => "text-xs",
    "sm" => "text-sm",
    "base" => "text-base",
    "lg" => "text-lg",
    "xl" => "text-xl"
  }
  @align %{
    "left" => "text-left",
    "center" => "text-center",
    "right" => "text-right",
    "justify" => "text-justify"
  }

  def render(assigns) do
    ~H"""
    <div
      {root(assigns,
        class: [
          "exr-rich leading-relaxed text-pretty",
          Map.get(sizes(), @size),
          Map.get(aligns(), @align),
          @muted && "opacity-75"
        ]
      )}
      {inline(assigns, :text)}
    >
      {rich(@text)}
    </div>
    """
  end

  defp sizes, do: @sizes
  defp aligns, do: @align
end
