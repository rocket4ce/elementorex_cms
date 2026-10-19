defmodule ElementorexCms.Blocks.Grid do
  @moduledoc """
  Grid of columns (CSS grid), with its own number of columns for desktop,
  tablet and mobile. New grids come with two columns.
  """

  use ElementorexCms.Block,
    type: "grid",
    label: "Columns",
    icon: "view-columns",
    category: :layout,
    description: "Columns that adapt to tablet and mobile",
    keywords: ~w(grid columns grilla columnas),
    container: true

  alias ElementorexCms.Blocks.Options
  alias ElementorexCms.Document

  @counts ~w(1 2 3 4 5 6)

  prop(:columns, :select, label: "Columns", options: @counts, default: "2", control: :segmented)

  prop(:columns_tablet, :select,
    label: "Columns on tablet",
    options: [{"Same", "same"} | Enum.map(@counts, &{&1, &1})],
    default: "same",
    control: :segmented
  )

  prop(:columns_mobile, :select,
    label: "Columns on mobile",
    options: @counts,
    default: "1",
    control: :segmented
  )

  prop(:gap, :select, label: "Gap", options: Options.gaps(), default: "6", control: :segmented)

  prop(:align, :select,
    label: "Align items",
    options: [{"Stretch", "stretch"}, {"Start", "start"}, {"Center", "center"}, {"End", "end"}],
    default: "stretch",
    control: :segmented
  )

  @desktop %{
    "1" => "grid-cols-1",
    "2" => "grid-cols-2",
    "3" => "grid-cols-3",
    "4" => "grid-cols-4",
    "5" => "grid-cols-5",
    "6" => "grid-cols-6"
  }
  @tablet %{
    "1" => "max-lg:grid-cols-1",
    "2" => "max-lg:grid-cols-2",
    "3" => "max-lg:grid-cols-3",
    "4" => "max-lg:grid-cols-4",
    "5" => "max-lg:grid-cols-5",
    "6" => "max-lg:grid-cols-6"
  }
  @mobile %{
    "1" => "max-md:grid-cols-1",
    "2" => "max-md:grid-cols-2",
    "3" => "max-md:grid-cols-3",
    "4" => "max-md:grid-cols-4",
    "5" => "max-md:grid-cols-5",
    "6" => "max-md:grid-cols-6"
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
  @align %{
    "stretch" => "items-stretch",
    "start" => "items-start",
    "center" => "items-center",
    "end" => "items-end"
  }

  def default_children do
    [Document.node("container", %{"gap" => "4"}), Document.node("container", %{"gap" => "4"})]
  end

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["grid w-full", classes(@columns, @columns_tablet, @columns_mobile), gap(@gap), align(@align)])}>
      <.children node={@node} ctx={@ctx} />
    </div>
    """
  end

  defp classes(desktop, tablet, mobile) do
    [Map.get(@desktop, desktop), Map.get(@tablet, tablet), Map.get(@mobile, mobile)]
  end

  defp gap(gap), do: Map.get(@gaps, gap)
  defp align(align), do: Map.get(@align, align)
end
