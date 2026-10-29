defmodule ElementorexCms.ChartsTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.{Chart, Document, Registry, Renderer}

  doctest ElementorexCms.Chart

  setup do
    %{registry: Registry.default()}
  end

  defp render(registry, type, props) do
    type
    |> Document.node(props, registry: registry)
    |> Renderer.to_html(registry: registry, mode: :public)
    |> LazyHTML.from_fragment()
  end

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()
  defp text(doc), do: LazyHTML.text(doc)

  describe "data" do
    test "is read with any delimiter and quotes" do
      assert %{header: ["A", "B"], rows: [["x;y", "2"]]} = Chart.parse(~s(A;B\n"x;y";2))
      assert %{header: ["A", "B"], rows: [["1", "2"]]} = Chart.parse("A\tB\n1\t2")
      assert %{header: ["A", "B", "C"], rows: [["1", "", ""]]} = Chart.parse("A,B,C\n1")
      assert %{header: [], rows: []} = Chart.parse("  \n ")
    end

    test "ticks cover negative values" do
      ticks = Chart.ticks(-12, 30)
      assert hd(ticks) <= -12 and List.last(ticks) >= 30
      assert 0 in ticks
    end
  end

  describe "bar chart" do
    test "draws one bar per value, with the target line", %{registry: registry} do
      doc =
        render(registry, "chart_bar", %{
          "title" => "PPC",
          "data" => "Week;PPC;Other\nW1;80;10\nW2;55;\nW3;100;20",
          "target" => 80,
          "unit" => "%"
        })

      # the empty cell has no bar
      assert count(doc, "svg rect") == 5
      assert text(doc) =~ "Target 80%"
      assert count(doc, "svg line[stroke-dasharray]") == 1
      assert text(doc) =~ "PPC"
    end

    test "draws stacked horizontal bars as rows", %{registry: registry} do
      doc =
        render(registry, "chart_bar", %{
          "data" => "Category;Open;Released\nMaterials;3;5\nDesign;1;0",
          "orientation" => "horizontal",
          "stacked" => true
        })

      assert count(doc, "svg") == 0
      assert text(doc) =~ "Materials"
      # totals at the end of the rows
      assert text(doc) =~ "8"
    end

    test "escapes labels", %{registry: registry} do
      html =
        "chart_bar"
        |> Document.node(%{"data" => "Name;Value\n<script>x</script>;1"}, registry: registry)
        |> Renderer.to_html(registry: registry)

      refute html =~ "<script>"
    end

    test "says when there is no data", %{registry: registry} do
      doc = render(registry, "chart_bar", %{"data" => ""})
      assert text(doc) =~ "No data yet"
    end
  end

  describe "line chart" do
    test "leaves gaps and draws dashed series", %{registry: registry} do
      doc =
        render(registry, "chart_line", %{
          "data" => "Week;Planned;Actual\nW1;10;8\nW2;20;\nW3;30;25",
          "dashed" => "Planned",
          "area" => false
        })

      paths = doc |> LazyHTML.query("svg path") |> Enum.map(&LazyHTML.attribute(&1, "d"))
      [planned, actual] = List.flatten(paths)

      assert length(String.split(planned, "M")) == 2
      # the empty cell splits the actual line in two
      assert length(String.split(actual, "M")) == 3
      assert count(doc, ~s(svg path[stroke-dasharray="6 5"])) == 1
      assert count(doc, "svg circle") == 5
    end
  end

  describe "donut chart" do
    test "draws the parts with their shares", %{registry: registry} do
      doc =
        render(registry, "chart_donut", %{
          "data" => "State;Tasks\nDone;3\nLate;1\nNone;0",
          "center_label" => "Tasks"
        })

      assert count(doc, "svg circle") == 2
      assert text(doc) =~ "75%"
      assert text(doc) =~ "25%"
      assert text(doc) =~ "Tasks"
    end
  end

  describe "table" do
    test "aligns numbers and draws the bar column", %{registry: registry} do
      doc =
        render(registry, "data_table", %{
          "data" => "Task;Progress %\nWalls;40\nSlab;100",
          "bar_column" => "Progress %"
        })

      assert count(doc, "thead th") == 2
      assert count(doc, "tbody tr") == 2

      assert doc
             |> LazyHTML.query("thead th")
             |> Enum.at(1)
             |> LazyHTML.attribute("style")
             |> hd() =~ "text-align:right"

      assert count(doc, "tbody td span span span") == 2
    end

    test "shows a text without rows", %{registry: registry} do
      doc = render(registry, "data_table", %{"data" => "Task;Owner", "empty_text" => "All done"})
      assert text(doc) =~ "All done"
    end
  end

  test "metrics show values, notes and tones", %{registry: registry} do
    doc =
      render(registry, "metrics", %{
        "items" => [
          %{
            "label" => "Late",
            "value" => "3",
            "note" => "2 critical",
            "trend" => "up",
            "tone" => "bad"
          }
        ]
      })

    assert text(doc) =~ "Late"
    assert text(doc) =~ "2 critical"
    assert text(doc) =~ "▲"

    assert Enum.any?(
             LazyHTML.attribute(LazyHTML.query(doc, "div div div"), "style"),
             &(&1 =~ "#e11d48")
           )
  end
end
