defmodule ElementorexCms.Blocks.ChartBar do
  @moduledoc """
  Bar chart of one or more series: vertical (columns) or horizontal, grouped
  or stacked, with values on the bars and an optional target line. The data
  is delimited text (see `ElementorexCms.Chart`).
  """

  use ElementorexCms.Block,
    type: "chart_bar",
    label: "Bar chart",
    icon: "chart-bar",
    category: :charts,
    description: "Columns or bars of one or more series",
    keywords: ~w(chart graph bars columns grafico barras columnas)

  alias ElementorexCms.Blocks.ChartParts
  alias ElementorexCms.Chart

  import ChartParts, only: [r: 1]

  prop(:title, :string, label: "Title", default: "Sales by quarter", inline: true)

  prop(:data, :text,
    label: "Data",
    default: "Quarter;2025;2026\nQ1;120;135\nQ2;150;172\nQ3;98;140\nQ4;180;210",
    help: ChartParts.data_help(),
    max_length: 50_000
  )

  prop(:orientation, :select,
    label: "Orientation",
    options: [{"Vertical", "vertical"}, {"Horizontal", "horizontal"}],
    default: "vertical",
    control: :segmented
  )

  prop(:stacked, :boolean, label: "Stacked", default: false)
  prop(:show_values, :boolean, label: "Show values", default: true)
  prop(:unit, :string, label: "Unit", default: "", placeholder: "%")
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

    assigns =
      assign(assigns,
        chart: chart,
        empty: chart.labels == [] or chart.series == [],
        h: ChartParts.height(assigns.height)
      )

    assigns =
      if assigns.empty,
        do: assigns,
        else:
          assign(assigns,
            plot:
              if(assigns.orientation == "horizontal",
                do: horizontal(chart, assigns),
                else: vertical(chart, assigns)
              )
          )

    ~H"""
    <figure {root(assigns, style: "margin:0;width:100%")}>
      <ChartParts.title title={@title} inline={inline(assigns, :title)} />
      <ChartParts.empty :if={@empty} />
      <svg
        :if={!@empty and @orientation != "horizontal"}
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
        <rect
          :for={bar <- @plot.bars}
          x={bar.x}
          y={bar.y}
          width={bar.w}
          height={bar.h}
          rx="3"
          fill={bar.color}
        >
          <title>{bar.title}</title>
        </rect>
        <text
          :for={bar <- @plot.bars}
          :if={@show_values and @plot.values and bar.value_label}
          x={bar.x + bar.w / 2}
          y={bar.label_y}
          text-anchor="middle"
          font-size="10"
          font-weight="600"
          fill="currentColor"
          fill-opacity=".8"
        >
          {bar.value_label}
        </text>
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
      <div
        :if={!@empty and @orientation == "horizontal"}
        style="display:flex;flex-direction:column;gap:8px"
      >
        <div :for={row <- @plot.rows} style="display:flex;align-items:center;gap:10px;font-size:12px">
          <span
            style="flex:0 0 34%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;opacity:.85"
            title={row.label}
          >
            {row.label}
          </span>
          <span style="position:relative;flex:1;display:flex;flex-direction:column;gap:2px">
            <span
              :if={@stacked}
              style="display:flex;height:14px;border-radius:4px;overflow:hidden;background:rgba(148,163,184,.15)"
            >
              <span
                :for={bar <- row.bars}
                style={"display:block;height:100%;width:#{bar.width}%;background:#{bar.color}"}
                title={bar.title}
              ></span>
            </span>
            <span
              :for={bar <- row.bars}
              :if={!@stacked}
              style={"display:block;height:#{row.thickness}px;width:#{bar.width}%;min-width:2px;border-radius:4px;background:#{bar.color}"}
              title={bar.title}
            ></span>
            <span
              :if={@plot.target}
              style={"position:absolute;top:-3px;bottom:-3px;left:#{@plot.target}%;border-left:2px dashed #10b981"}
              title={"#{@target_label} #{Chart.format(@target, @unit)}"}
            ></span>
          </span>
          <span
            :if={@show_values}
            style="flex:0 0 auto;min-width:44px;text-align:right;font-weight:600;font-variant-numeric:tabular-nums"
          >
            {row.value}
          </span>
        </div>
      </div>
      <ChartParts.legend
        :if={!@empty and @show_legend and length(@chart.series) > 1}
        names={Enum.map(@chart.series, & &1.name)}
        palette={@palette}
      />
    </figure>
    """
  end

  defp vertical(chart, assigns) do
    {left, right, top, bottom} = {44, 12, 16, 30}
    stacked = assigns.stacked
    {low, high} = Chart.extent(chart.series, stacked)
    target = assigns.target
    high = if is_number(target), do: max(high, target), else: high
    ticks = Chart.ticks(low, high)
    {t0, t1} = {hd(ticks), List.last(ticks)}
    plot_w = @width - left - right
    plot_h = assigns.h - top - bottom
    y = fn value -> top + (1 - (value - t0) / (t1 - t0)) * plot_h end
    count = length(chart.labels)
    band = plot_w / count
    group = band * 0.72
    series_count = length(chart.series)
    every = max(ceil(count / 12), 1)

    bars =
      for {label, i} <- Enum.with_index(chart.labels),
          {series, j} <- Enum.with_index(chart.series),
          value = Enum.at(series.values, i),
          is_number(value) do
        {from, to, width, x} =
          if stacked do
            below =
              chart.series
              |> Enum.take(j)
              |> Enum.map(&Enum.at(&1.values, i))
              |> Enum.filter(&(is_number(&1) and &1 >= 0 == value >= 0))
              |> Enum.sum()

            {below, below + value, group, left + band * i + (band - group) / 2}
          else
            width = group / series_count
            {0, value, width, left + band * i + (band - group) / 2 + width * j}
          end

        {y1, y2} = {y.(max(from, to)), y.(min(from, to))}

        %{
          x: r(x + 1),
          y: r(y1),
          w: r(max(width - 2, 1)),
          h: r(max(y2 - y1, 0.5)),
          color: Chart.color(assigns.palette, j),
          title: "#{series.name} · #{label}: #{Chart.format(value, assigns.unit)}",
          value_label: Chart.format(value, assigns.unit),
          label_y: r(if(stacked, do: (y1 + y2) / 2 + 3, else: y1 - 4))
        }
      end

    %{
      width: @width,
      left: left,
      right: right,
      bars: bars,
      # values only fit on wide enough bars
      values: count * if(stacked, do: 1, else: series_count) <= 24,
      ticks:
        for(
          tick <- ticks,
          do: %{y: r(y.(tick)), value: tick, label: Chart.format(tick, assigns.unit)}
        ),
      labels:
        for {label, i} <- Enum.with_index(chart.labels), rem(i, every) == 0 do
          %{x: r(left + band * i + band / 2), text: ChartParts.short(label), full: label}
        end,
      target: is_number(target) && r(y.(target))
    }
  end

  defp horizontal(chart, assigns) do
    stacked = assigns.stacked
    {_low, high} = Chart.extent(chart.series, stacked)
    target = assigns.target
    high = if is_number(target), do: max(high, target), else: high
    high = if high <= 0, do: 1, else: high
    series_count = length(chart.series)

    rows =
      for {label, i} <- Enum.with_index(chart.labels) do
        values = Enum.map(chart.series, &Enum.at(&1.values, i))
        numbers = Enum.filter(values, &is_number/1)

        bars =
          for {value, j} <- Enum.with_index(values) do
            %{
              width: r(if(is_number(value) and value > 0, do: value / high * 100, else: 0)),
              color: Chart.color(assigns.palette, j),
              title:
                "#{Enum.at(chart.series, j).name} · #{label}: #{Chart.format(value, assigns.unit)}"
            }
          end

        %{
          label: label,
          bars: bars,
          thickness: if(series_count == 1, do: 14, else: max(div(18, series_count), 5)),
          value:
            cond do
              numbers == [] -> "—"
              stacked or series_count == 1 -> Chart.format(Enum.sum(numbers), assigns.unit)
              true -> Enum.map_join(numbers, " · ", &Chart.format(&1, assigns.unit))
            end
        }
      end

    %{rows: rows, target: is_number(target) && r(target / high * 100)}
  end
end
