defmodule ElementorexCms.Chart do
  @moduledoc """
  Data and drawing helpers of the chart blocks (*Bar chart*, *Line chart*,
  *Donut chart*, *Table* and *Metrics*).

  ## Data

  Charts and tables take their data as delimited text, easy to type or paste
  in the editor and to generate from your app: the first row names the
  columns, the first column holds the categories and every other column is a
  series.

      Week;Planned;Actual
      W1;10;8
      W2;25;21.5

  The delimiter is the first of tab, `;` or `,` found in the first row.
  Values may be quoted (`"Walls; level 2"`), numbers use `.` for decimals and
  may carry a `%` or thousands separators (`1,250.5` with `;` or tabs).

      iex> ElementorexCms.Chart.series("Week;Planned;Actual\\nW1;10;8\\nW2;25;21.5")
      %{
        labels: ["W1", "W2"],
        series: [%{name: "Planned", values: [10, 25]}, %{name: "Actual", values: [8, 21.5]}]
      }

  ## Colors

  Series take the colors of a palette (`palette_options/0`), each one a CSS
  custom property with a fallback, so a site can theme them:
  `--exr-chart-1` ... `--exr-chart-8`.
  """

  @palettes %{
    "default" => ~w(#0ea5e9 #6366f1 #10b981 #f59e0b #f43f5e #8b5cf6 #14b8a6 #64748b),
    "cool" => ~w(#0369a1 #0ea5e9 #6366f1 #14b8a6 #22d3ee #818cf8 #0f766e #94a3b8),
    "warm" => ~w(#f97316 #f43f5e #f59e0b #e11d48 #fb923c #d97706 #be123c #a8a29e),
    "status" => ~w(#10b981 #0ea5e9 #94a3b8 #f43f5e #f59e0b #8b5cf6 #14b8a6 #64748b),
    "mono" => ~w(#0f172a #334155 #475569 #64748b #94a3b8 #cbd5e1 #1e293b #e2e8f0)
  }

  @max_rows 500
  @max_columns 12

  @doc "Palettes offered by the chart blocks."
  def palette_options do
    [
      {"Default", "default"},
      {"Cool", "cool"},
      {"Warm", "warm"},
      {"Status", "status"},
      {"Grayscale", "mono"}
    ]
  end

  @doc """
  The color of series `index` (0-based) in `palette`, as a CSS value that a
  site can override with `--exr-chart-<n>`.

      iex> ElementorexCms.Chart.color("default", 0)
      "var(--exr-chart-1, #0ea5e9)"
  """
  def color(palette, index) do
    colors = Map.get(@palettes, palette, @palettes["default"])
    n = rem(index, length(colors))
    "var(--exr-chart-#{n + 1}, #{Enum.at(colors, n)})"
  end

  @doc """
  Parses delimited text into a header and rows of cells (strings). Blank
  lines are skipped; at most #{@max_rows} rows and #{@max_columns} columns.

      iex> ElementorexCms.Chart.parse(~s(Task,Owner\\n"Walls, L2",Ana\\n))
      %{header: ["Task", "Owner"], rows: [["Walls, L2", "Ana"]]}
  """
  def parse(text) when is_binary(text) do
    lines =
      text
      |> String.split(~r/\r\n|\n|\r/)
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.take(@max_rows + 1)

    case lines do
      [] ->
        %{header: [], rows: []}

      [first | rest] ->
        separator = separator(first)
        header = first |> split(separator) |> Enum.take(@max_columns)
        width = length(header)

        rows =
          Enum.map(rest, fn line ->
            cells = line |> split(separator) |> Enum.take(width)
            cells ++ List.duplicate("", width - length(cells))
          end)

        %{header: header, rows: rows}
    end
  end

  def parse(_text), do: %{header: [], rows: []}

  defp separator(line) do
    cond do
      String.contains?(line, "\t") -> "\t"
      String.contains?(line, ";") -> ";"
      true -> ","
    end
  end

  # Splits a line on the separator, honoring double quotes ("" is a quote)
  defp split(line, separator) do
    line
    |> String.graphemes()
    |> do_split(separator, [], [], false)
    |> Enum.map(&String.trim/1)
  end

  defp do_split([], _sep, field, fields, _quoted),
    do: Enum.reverse([field |> Enum.reverse() |> Enum.join() | fields])

  defp do_split(["\"", "\"" | rest], sep, field, fields, true),
    do: do_split(rest, sep, ["\"" | field], fields, true)

  defp do_split(["\"" | rest], sep, field, fields, quoted),
    do: do_split(rest, sep, field, fields, not quoted)

  defp do_split([sep | rest], sep, field, fields, false),
    do: do_split(rest, sep, [], [field |> Enum.reverse() |> Enum.join() | fields], false)

  defp do_split([char | rest], sep, field, fields, quoted),
    do: do_split(rest, sep, [char | field], fields, quoted)

  @doc """
  The categories (first column) and the numeric series (other columns) of
  delimited text. Cells that aren't numbers are `nil`.
  """
  def series(text) do
    %{header: header, rows: rows} = parse(text)

    case header do
      [] ->
        %{labels: [], series: []}

      [_category | names] ->
        series =
          names
          |> Enum.with_index(1)
          |> Enum.map(fn {name, column} ->
            %{name: name, values: Enum.map(rows, &number(Enum.at(&1, column)))}
          end)

        %{labels: Enum.map(rows, &hd/1), series: series}
    end
  end

  @doc """
  Reads a number: `"12"`, `"-3.5"`, `"45%"`, `"1,250.75"`. Anything else is `nil`.

      iex> Enum.map(["12", "-3.5", "45%", "1,250.75", "n/a", ""], &ElementorexCms.Chart.number/1)
      [12, -3.5, 45, 1250.75, nil, nil]
  """
  def number(value) when is_number(value), do: value

  def number(value) when is_binary(value) do
    clean = value |> String.trim() |> String.trim_trailing("%") |> String.replace(",", "")

    cond do
      clean =~ ~r/\A-?\d+\z/ -> String.to_integer(clean)
      clean =~ ~r/\A-?\d*\.\d+\z/ -> clean |> normalize_float() |> String.to_float()
      true -> nil
    end
  end

  def number(_value), do: nil

  defp normalize_float("-." <> rest), do: "-0." <> rest
  defp normalize_float("." <> rest), do: "0." <> rest
  defp normalize_float(value), do: value

  @doc """
  Round tick values covering `min..max`, about `count` of them.

      iex> ElementorexCms.Chart.ticks(0, 87)
      [0, 20, 40, 60, 80, 100]
  """
  def ticks(min, max, count \\ 5)
  def ticks(min, max, count) when max <= min, do: ticks(min, min + 1, count)

  def ticks(min, max, count) do
    step = nice_step((max - min) / max(count, 1))
    first = Float.floor(min / step) * step
    last = Float.ceil(max / step) * step
    steps = round((last - first) / step)
    for i <- 0..steps, do: clean(first + i * step)
  end

  defp nice_step(raw) do
    magnitude = :math.pow(10, Float.floor(:math.log10(raw)))
    fraction = raw / magnitude

    nice =
      cond do
        fraction <= 1 -> 1
        fraction <= 2 -> 2
        fraction <= 2.5 -> 2.5
        fraction <= 5 -> 5
        true -> 10
      end

    nice * magnitude
  end

  defp clean(value) do
    rounded = Float.round(value / 1, 6)
    if rounded == Float.round(rounded), do: trunc(rounded), else: rounded
  end

  @doc """
  A number as text with at most `decimals` decimals and an optional unit.

      iex> ElementorexCms.Chart.format(12.345, "%")
      "12.3%"
      iex> ElementorexCms.Chart.format(1500, "")
      "1500"
  """
  def format(value, unit \\ "", decimals \\ 1)
  def format(nil, _unit, _decimals), do: "—"

  def format(value, unit, decimals) when is_number(value) do
    text =
      cond do
        is_integer(value) ->
          Integer.to_string(value)

        value == Float.round(value) ->
          value |> trunc() |> Integer.to_string()

        true ->
          value
          |> Float.round(decimals)
          |> :erlang.float_to_binary([:compact, decimals: decimals])
      end

    text <> (unit || "")
  end

  @doc "The largest and smallest numbers of the series (stacked: of the totals)."
  def extent(series, stacked \\ false) do
    values =
      if stacked do
        series
        |> Enum.map(& &1.values)
        |> Enum.zip_with(fn column -> column |> Enum.reject(&is_nil/1) |> Enum.sum() end)
      else
        Enum.flat_map(series, & &1.values)
      end
      |> Enum.reject(&is_nil/1)

    case values do
      [] -> {0, 1}
      _ -> {min(Enum.min(values), 0), max(Enum.max(values), 0)}
    end
  end
end
