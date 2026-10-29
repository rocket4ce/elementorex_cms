defmodule ElementorexCms.Blocks.ChartDonut do
  @moduledoc """
  Donut (or pie) chart of the parts of a whole: the first column names the
  parts and the second holds their values (see `ElementorexCms.Chart`). The
  legend shows each value and its share.
  """

  use ElementorexCms.Block,
    type: "chart_donut",
    label: "Donut chart",
    icon: "chart-pie",
    category: :charts,
    description: "Parts of a whole with their shares",
    keywords: ~w(chart graph donut pie share grafico torta dona participacion)

  alias ElementorexCms.Blocks.ChartParts
  alias ElementorexCms.Chart

  import ChartParts, only: [r: 1]

  prop(:title, :string, label: "Title", default: "Tasks by state", inline: true)

  prop(:data, :text,
    label: "Data",
    default: "State;Tasks\nDone;18\nIn progress;9\nNot started;14\nLate;3",
    help: ChartParts.data_help(),
    max_length: 50_000
  )

  prop(:center_label, :string, label: "Center label", default: "Total")
  prop(:unit, :string, label: "Unit", default: "")
  prop(:show_percent, :boolean, label: "Show shares", default: true)

  prop(:kind, :select,
    label: "Kind",
    options: [{"Donut", "donut"}, {"Pie", "pie"}],
    default: "donut",
    control: :segmented
  )

  prop(:palette, :select, label: "Colors", options: Chart.palette_options(), default: "status")

  @radius 70
  @circumference 2 * :math.pi() * @radius

  def render(assigns) do
    chart = Chart.series(assigns.data)

    parts =
      case chart.series do
        [series | _] ->
          chart.labels
          |> Enum.zip(series.values)
          |> Enum.filter(fn {_label, value} -> is_number(value) and value > 0 end)

        [] ->
          []
      end

    total = parts |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    {segments, _offset} =
      parts
      |> Enum.with_index()
      |> Enum.map_reduce(0, fn {{label, value}, index}, offset ->
        length = value / total * @circumference

        segment = %{
          label: label,
          value: value,
          share: value / total * 100,
          color: Chart.color(assigns.palette, index),
          dash: "#{r(length)} #{r(@circumference - length)}",
          offset: r(-offset)
        }

        {segment, offset + length}
      end)

    assigns =
      assign(assigns,
        segments: segments,
        total: total,
        stroke: if(assigns.kind == "pie", do: @radius * 2, else: 26),
        radius: if(assigns.kind == "pie", do: @radius / 2, else: @radius)
      )

    ~H"""
    <figure {root(assigns, style: "margin:0;width:100%")}>
      <ChartParts.title title={@title} inline={inline(assigns, :title)} />
      <ChartParts.empty :if={@segments == []} />
      <div
        :if={@segments != []}
        style="display:flex;flex-wrap:wrap;align-items:center;gap:16px 24px"
      >
        <svg
          viewBox="0 0 200 200"
          style="width:170px;max-width:45%;height:auto;flex:0 0 auto"
          role="img"
          aria-label={@title}
        >
          <g transform="rotate(-90 100 100)">
            <circle
              :for={segment <- @segments}
              cx="100"
              cy="100"
              r={@radius}
              fill="none"
              stroke={segment.color}
              stroke-width={@stroke}
              stroke-dasharray={
                if @kind == "pie",
                  do: pie_dash(segment, @radius),
                  else: segment.dash
              }
              stroke-dashoffset={
                if @kind == "pie", do: pie_offset(segment, @radius), else: segment.offset
              }
            >
              <title>
                {segment.label}: {Chart.format(segment.value, @unit)} ({Chart.format(
                  segment.share,
                  "%"
                )})
              </title>
            </circle>
          </g>
          <g :if={@kind == "donut"}>
            <text
              x="100"
              y="97"
              text-anchor="middle"
              font-size="26"
              font-weight="700"
              fill="currentColor"
            >
              {Chart.format(@total, @unit)}
            </text>
            <text
              x="100"
              y="120"
              text-anchor="middle"
              font-size="12"
              fill="currentColor"
              fill-opacity=".6"
            >
              {@center_label}
            </text>
          </g>
        </svg>
        <ul style="list-style:none;margin:0;padding:0;flex:1;min-width:160px;display:flex;flex-direction:column;gap:6px;font-size:13px">
          <li :for={segment <- @segments} style="display:flex;align-items:center;gap:8px">
            <span style={"width:10px;height:10px;border-radius:3px;flex:0 0 auto;background:#{segment.color}"}></span>
            <span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">{segment.label}</span>
            <span style="font-weight:600;font-variant-numeric:tabular-nums">{Chart.format(
              segment.value,
              @unit
            )}</span>
            <span
              :if={@show_percent}
              style="min-width:44px;text-align:right;opacity:.6;font-variant-numeric:tabular-nums"
            >
              {Chart.format(segment.share, "%")}
            </span>
          </li>
        </ul>
      </div>
    </figure>
    """
  end

  # A pie is a circle of half the radius with a stroke as wide as the
  # diameter: the dashes become wedges
  defp pie_dash(segment, radius) do
    circumference = 2 * :math.pi() * radius
    length = segment.share / 100 * circumference
    "#{r(length)} #{r(circumference - length)}"
  end

  defp pie_offset(segment, radius) do
    circumference = 2 * :math.pi() * radius
    r(segment.offset / @circumference * circumference)
  end
end
