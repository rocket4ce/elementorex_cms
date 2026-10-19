defmodule ElementorexCms.Blocks.Section do
  @moduledoc "A section of the page: full width or boxed, with its children stacked."

  use ElementorexCms.Block,
    type: "section",
    label: "Section",
    icon: "rectangle-group",
    category: :layout,
    description: "Full-width or boxed area that stacks its content",
    keywords: ~w(row band wrapper seccion banda),
    container: true,
    style: %{"desktop" => %{"padding-top" => "24px", "padding-bottom" => "24px"}}

  alias ElementorexCms.Blocks.Options

  prop(:layout, :select,
    label: "Width",
    options: [{"Boxed", "boxed"}, {"Full width", "full"}],
    default: "boxed",
    control: :segmented
  )

  prop(:content_width, :integer,
    label: "Content width",
    default: 1140,
    min: 320,
    max: 1920,
    unit: "px",
    show_if: {:layout, "boxed"}
  )

  prop(:gap, :select, label: "Gap", options: Options.gaps(), default: "4", control: :segmented)

  prop(:align, :select,
    label: "Align items",
    options: [{"Stretch", "stretch"}, {"Start", "start"}, {"Center", "center"}, {"End", "end"}],
    default: "stretch",
    control: :segmented
  )

  prop(:tag, :select,
    label: "HTML tag",
    options: ~w(section div header footer article aside main),
    default: "section"
  )

  @gaps %{
    "0" => "gap-0",
    "1" => "gap-1",
    "2" => "gap-2",
    "4" => "gap-4",
    "6" => "gap-6",
    "8" => "gap-8",
    "12" => "gap-12"
  }
  @align %{
    "stretch" => "items-stretch",
    "start" => "items-start",
    "center" => "items-center",
    "end" => "items-end"
  }

  def render(assigns) do
    ~H"""
    <.dynamic_tag tag_name={@tag} {root(assigns, class: "relative w-full")}>
      <div
        class={[
          "flex w-full flex-col",
          gap_class(@gap),
          align_class(@align),
          @layout == "boxed" && "mx-auto"
        ]}
        style={@layout == "boxed" && style([{"max-width", "#{@content_width}px"}])}
      >
        <.children node={@node} ctx={@ctx} />
      </div>
    </.dynamic_tag>
    """
  end

  defp gap_class(gap), do: Map.get(@gaps, gap)
  defp align_class(align), do: Map.get(@align, align)
end
