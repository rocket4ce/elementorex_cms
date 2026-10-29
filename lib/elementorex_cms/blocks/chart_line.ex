defmodule ElementorexCms.Blocks.ChartLine do
  @moduledoc """
  Line chart of one or more series over the categories (dates, weeks...),
  with optional area, points, dashed series (a plan against the actual, for
  instance) and a target line. The data is delimited text (see
  `ElementorexCms.Chart`); empty cells leave a gap.
  """

  use ElementorexCms.Block,
    type: "chart_line",
    label: "Line chart",
    icon: "presentation-chart-line",
    category: :charts,
    description: "Lines or areas over time",
    keywords: ~w(chart graph line area trend curve grafico linea area tendencia curva)

  alias ElementorexCms.Blocks.ChartParts
  alias ElementorexCms.Chart

  import ChartParts, only: [r: 1]

  prop(:title, :string, label: "Title", default: "Progress", inline: true)

  prop(:data, :text,
    label: "Data",
    default: "Week;Planned;Actual\nW1;5;4\nW2;12;10\nW3;22;17\nW4;35;29\nW5;50;\nW6;66;",
    help: ChartParts.data_help(),
    max_length: 50_000
  )

  prop(:area, :boolean, label: "Fill the area", default: true)
  prop(:points, :boolean, label: "Points", default: true)

  prop(:dashed, :string,
    label: "Dashed series",
    default: "",
    placeholder: "Planned",
    help: "Names of the series drawn dashed, separated by commas"
  )

  prop(:unit, :string, label: "Unit", default: "", placeholder: "%")
  prop(:min, :number, label: "Minimum", help: "Leave empty to fit the data")
  prop(:max, :number, label: "Maximum", help: "Leave empty to fit the data")
  prop(:target, :number, label: "Target line", help: "Leave empty for none")
  prop(:target_label, :string, label: "Target label", default: "Target")
  prop(:palette, :select, label: "Colors", options: Chart.palette_options(), default: "default")
  prop(:show_legend, :boolean, label: "Legend", default: true)

  prop(:height, :integer,
    label: "Height",
    default: 260,
    min: 120,
    max: 640,
    unit: "px",
    control: :range
  )

  @width 600

  def render(assigns) do
    chart = Chart.series(assigns.data)
    empty = chart.labels == [] or chart.series == []

    dashed =
      assigns.dashed
      |> to_string()
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    assigns =
      assign(assigns,
        chart: chart,
        empty: empty,
        dashed_names: dashed,
        h: ChartParts.height(assigns.height)
      )

    assigns = if empty, do: assigns, else: assign(assigns, plot: plot(chart, assigns))

    ~H"""
    <figure {root(assigns, style: "margin:0;width:100%")}>
      <ChartParts.title title={@title} inline={inline(assigns, :title)} />
      <ChartParts.empty :if={@empty} />
      <svg
        :if={!@empty}
        viewBox={"0 0 #{@plot.width} #{@h}"}
        style="width:100%;height:auto;display:block;overflow:visible"
        role="img"
        aria-label={@title}
      >
        <g :for={tick <- @plot.ticks}>
          <line
            x1={@plot.left}
            x2={@plot.width - @plot.right}
            y1={tick.y}
            y2={tick.y}
            stroke="currentColor"
            stroke-opacity={if tick.value == 0, do: ".35", else: ".1"}
          />
          <text
            x={@plot.left - 6}
            y={tick.y}
            text-anchor="end"
            dominant-baseline="middle"
            font-size="11"
            fill="currentColor"
            fill-opacity=".6"
          >
            {tick.label}
          </text>
        </g>
        <path
          :for={line <- @plot.lines}
          :if={@area and line.area}
          d={line.area}
          fill={line.color}
          fill-opacity=".12"
        />
        <path
          :for={line <- @plot.lines}
          d={line.path}
          fill="none"
          stroke={line.color}
          stroke-width="2.5"
          stroke-linejoin="round"
          stroke-linecap="round"
          stroke-dasharray={if line.dashed, do: "6 5"}
        />
        <g :if={@points}>
          <circle
            :for={point <- @plot.points}
            cx={point.x}
            cy={point.y}
            r="3.5"
            fill="white"
            stroke={point.color}
            stroke-width="2"
          >
            <title>{point.title}</title>
          </circle>
        </g>
        <text
          :for={label <- @plot.labels}
          x={label.x}
          y={@h - 10}
          text-anchor="middle"
          font-size="11"
          fill="currentColor"
          fill-opacity=".7"
        >
          {label.text}
          <title>{label.full}</title>
        </text>
        <g :if={@plot.target}>
          <line
            x1={@plot.left}
            x2={@plot.width - @plot.right}
            y1={@plot.target}
            y2={@plot.target}
            stroke="#10b981"
            stroke-width="1.5"
            stroke-dasharray="5 4"
          />
          <text
            x={@plot.width - @plot.right}
            y={@plot.target - 5}
            text-anchor="end"
            font-size="10"
            font-weight="600"
            fill="#059669"
          >
            {@target_label} {Chart.format(@target, @unit)}
          </text>
        </g>
      </svg>
      <ChartParts.legend
        :if={!@empty and @show_legend and length(@chart.series) > 1}
        names={Enum.map(@chart.series, & &1.name)}
        palette={@palette}
        dashed={@dashed_names}
      />
    </figure>
    """
  end

  defp plot(chart, assigns) do
    {left, right, top, bottom} = {44, 14, 16, 30}
    {low, high} = Chart.extent(chart.series)
    target = assigns.target
    high = if is_number(target), do: max(high, target), else: high
    low = if is_number(assigns.min), do: assigns.min, else: low
    high = if is_number(assigns.max), do: assigns.max, else: high
    ticks = Chart.ticks(low, high)
    {t0, t1} = {hd(ticks), List.last(ticks)}
    plot_w = @width - left - right
    plot_h = assigns.h - top - bottom
    count = length(chart.labels)
    x = fn i -> if count == 1, do: left + plot_w / 2, else: left + plot_w * i / (count - 1) end
    y = fn value -> top + (1 - (min(max(value, t0), t1) - t0) / (t1 - t0)) * plot_h end
    base = y.(max(t0, min(0, t1)))
    every = max(ceil(count / 10), 1)

    lines =
      for {series, j} <- Enum.with_index(chart.series) do
        segments =
          series.values
          |> Enum.with_index()
          |> Enum.chunk_by(fn {value, _i} -> is_number(value) end)
          |> Enum.filter(fn [{value, _i} | _] -> is_number(value) end)
          |> Enum.map(fn segment ->
            Enum.map(segment, fn {value, i} -> {r(x.(i)), r(y.(value))} end)
          end)

        %{
          color: Chart.color(assigns.palette, j),
          dashed: series.name in assigns.dashed_names,
          path: Enum.map_join(segments, " ", &path/1),
          area:
            segments
            |> Enum.filter(&(length(&1) > 1))
            |> Enum.map_join(" ", fn [{x0, _} | _] = segment ->
              {x1, _} = List.last(segment)
              path(segment) <> " L #{x1} #{r(base)} L #{x0} #{r(base)} Z"
            end)
            |> then(&if(&1 == "", do: nil, else: &1))
        }
      end

    points =
      for {series, j} <- Enum.with_index(chart.series),
          {value, i} <- Enum.with_index(series.values),
          is_number(value),
          count <= 60 do
        %{
          x: r(x.(i)),
          y: r(y.(value)),
          color: Chart.color(assigns.palette, j),
          title:
            "#{series.name} · #{Enum.at(chart.labels, i)}: #{Chart.format(value, assigns.unit)}"
        }
      end

    %{
      width: @width,
      left: left,
      right: right,
      lines: lines,
      points: points,
      ticks:
        for(
          tick <- ticks,
          do: %{y: r(y.(tick)), value: tick, label: Chart.format(tick, assigns.unit)}
        ),
      labels:
        for {label, i} <- Enum.with_index(chart.labels), rem(i, every) == 0 do
          %{x: r(x.(i)), text: ChartParts.short(label, 12), full: label}
        end,
      target: is_number(target) && r(y.(target))
    }
  end

  defp path([{x0, y0} | rest]),
    do: "M #{x0} #{y0}" <> Enum.map_join(rest, "", fn {x, y} -> " L #{x} #{y}" end)
end
