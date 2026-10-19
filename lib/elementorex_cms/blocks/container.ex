defmodule ElementorexCms.Blocks.Container do
  @moduledoc """
  Flexbox container: lays its children out in a row or a column, with gap,
  alignment and wrapping. Rows stack on mobile unless told otherwise.
  """

  use ElementorexCms.Block,
    type: "container",
    label: "Container",
    icon: "square-2-stack",
    category: :layout,
    description: "Row or column of components (flexbox)",
    keywords: ~w(flex row column box div fila columna caja),
    container: true

  alias ElementorexCms.Blocks.Options

  prop(:direction, :select,
    label: "Direction",
    options: [{"Column", "column"}, {"Row", "row"}],
    default: "column",
    control: :segmented
  )

  prop(:stack_on_mobile, :boolean,
    label: "Stack on mobile",
    default: true,
    show_if: {:direction, "row"}
  )

  prop(:justify, :select,
    label: "Justify",
    options: [
      {"Start", "start"},
      {"Center", "center"},
      {"End", "end"},
      {"Space between", "between"},
      {"Space around", "around"},
      {"Space evenly", "evenly"}
    ],
    default: "start"
  )

  prop(:align, :select,
    label: "Align items",
    options: [
      {"Stretch", "stretch"},
      {"Start", "start"},
      {"Center", "center"},
      {"End", "end"},
      {"Baseline", "baseline"}
    ],
    default: "stretch"
  )

  prop(:gap, :select, label: "Gap", options: Options.gaps(), default: "4", control: :segmented)
  prop(:wrap, :boolean, label: "Wrap", default: false)

  prop(:tag, :select,
    label: "HTML tag",
    options: ~w(div section article aside header footer nav),
    default: "div"
  )

  @justify %{
    "start" => "justify-start",
    "center" => "justify-center",
    "end" => "justify-end",
    "between" => "justify-between",
    "around" => "justify-around",
    "evenly" => "justify-evenly"
  }
  @align %{
    "stretch" => "items-stretch",
    "start" => "items-start",
    "center" => "items-center",
    "end" => "items-end",
    "baseline" => "items-baseline"
  }
  @gaps %{
    "0" => "gap-0",
    "1" => "gap-1",
    "2" => "gap-2",
    "4" => "gap-4",
    "6" => "gap-6",
    "8" => "gap-8",
    "12" => "gap-12"
  }

  def render(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@tag}
      {root(assigns,
        class: [
          "flex min-w-0",
          direction_class(@direction, @stack_on_mobile),
          Map.get(justify_classes(), @justify),
          Map.get(align_classes(), @align),
          Map.get(gap_classes(), @gap),
          @wrap && "flex-wrap"
        ]
      )}
    >
      <.children node={@node} ctx={@ctx} />
    </.dynamic_tag>
    """
  end

  defp direction_class("row", true), do: "flex-row max-md:flex-col"
  defp direction_class("row", _stack), do: "flex-row"
  defp direction_class(_direction, _stack), do: "flex-col"

  defp justify_classes, do: @justify
  defp align_classes, do: @align
  defp gap_classes, do: @gaps
end
