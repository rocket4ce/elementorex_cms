defmodule ElementorexCms.Blocks.DataTable do
  @moduledoc """
  A table from delimited text (see `ElementorexCms.Chart`): the first row is
  the header. Numeric columns are aligned to the right, and one column can
  be drawn as bars (a percentage, a share).
  """

  use ElementorexCms.Block,
    type: "data_table",
    label: "Table",
    icon: "table-cells",
    category: :charts,
    description: "Rows and columns of data",
    keywords: ~w(table data rows columns grid tabla datos filas columnas)

  alias ElementorexCms.Blocks.ChartParts
  alias ElementorexCms.Chart

  prop(:title, :string, label: "Title", default: "", placeholder: "Title", inline: true)

  prop(:data, :text,
    label: "Data",
    default:
      "Task;Start;Finish;Progress %\nFoundations;Mar 2;Mar 13;100\nSlab level 1;Mar 16;Mar 27;60\nWalls level 1;Mar 30;Apr 8;15",
    help: "One row per line, the first one is the header. Separate with ; , or tab.",
    max_length: 50_000
  )

  prop(:bar_column, :string,
    label: "Column drawn as bars",
    default: "Progress %",
    help: "Name of a column of numbers from 0 to 100"
  )

  prop(:striped, :boolean, label: "Striped rows", default: true)

  prop(:size, :select,
    label: "Size",
    options: [{"S", "sm"}, {"M", "md"}],
    default: "sm",
    control: :segmented
  )

  prop(:empty_text, :string, label: "Text without rows", default: "Nothing to show")

  def render(assigns) do
    %{header: header, rows: rows} = Chart.parse(assigns.data)

    numeric =
      for column <- 0..max(length(header) - 1, 0) do
        cells = rows |> Enum.map(&Enum.at(&1, column)) |> Enum.reject(&(&1 in [nil, ""]))
        cells != [] and Enum.all?(cells, &is_number(Chart.number(&1)))
      end

    bar_index =
      Enum.find_index(
        header,
        &(String.downcase(&1) == String.downcase(to_string(assigns.bar_column)))
      )

    assigns =
      assign(assigns,
        header: header,
        rows: rows,
        numeric: numeric,
        bar_index: bar_index,
        pad: if(assigns.size == "md", do: "9px 12px", else: "6px 10px"),
        font: if(assigns.size == "md", do: "14px", else: "13px")
      )

    ~H"""
    <figure {root(assigns, style: "margin:0;width:100%")}>
      <ChartParts.title title={@title} inline={inline(assigns, :title)} />
      <ChartParts.empty :if={@header == []} />
      <div
        :if={@header != []}
        style="overflow-x:auto;border:1px solid rgba(148,163,184,.35);border-radius:12px"
      >
        <table style={"width:100%;border-collapse:collapse;font-size:#{@font}"}>
          <thead>
            <tr style="background:rgba(148,163,184,.12)">
              <th
                :for={{cell, index} <- Enum.with_index(@header)}
                scope="col"
                style={"padding:#{@pad};font-weight:600;font-size:12px;text-align:#{align(@numeric, index)};white-space:nowrap;opacity:.8"}
              >
                {cell}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@rows == []}>
              <td colspan={length(@header)} style={"padding:#{@pad};text-align:center;opacity:.6"}>
                {@empty_text}
              </td>
            </tr>
            <tr
              :for={{row, row_index} <- Enum.with_index(@rows)}
              style={"border-top:1px solid rgba(148,163,184,.25);#{if @striped and rem(row_index, 2) == 1, do: "background:rgba(148,163,184,.06)"}"}
            >
              <td
                :for={{cell, index} <- Enum.with_index(row)}
                style={"padding:#{@pad};text-align:#{align(@numeric, index)};font-variant-numeric:tabular-nums;vertical-align:middle"}
              >
                <%= if index == @bar_index and is_number(Chart.number(cell)) do %>
                  <span style="display:inline-flex;align-items:center;gap:8px;justify-content:flex-end;width:100%">
                    <span style="flex:1;max-width:90px;height:6px;border-radius:9px;background:rgba(148,163,184,.25);overflow:hidden">
                      <span style={"display:block;height:100%;border-radius:9px;background:var(--exr-chart-1, #0ea5e9);width:#{bar_width(cell)}%"}></span>
                    </span>
                    <span style="min-width:36px">{cell}</span>
                  </span>
                <% else %>
                  {cell}
                <% end %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </figure>
    """
  end

  defp align(numeric, index), do: if(Enum.at(numeric, index), do: "right", else: "left")

  defp bar_width(cell), do: cell |> Chart.number() |> max(0) |> min(100)
end
