defmodule ElementorexCms.Blocks.ChartParts do
  @moduledoc """
  Pieces shared by the chart blocks: the title, the legend, the empty state
  and the props every chart has.

  Charts are drawn with SVG and inline styles only, so they look the same
  whatever CSS framework the site uses; text takes the color of its
  container (`currentColor`).
  """
  use Phoenix.Component

  import ElementorexCms.Block.Helpers, only: [t: 1]

  alias ElementorexCms.Chart

  @doc "Help of the data props."
  def data_help,
    do:
      "One row per line. The first row names the columns; the first column holds the " <>
        "categories and each other column is a series. Separate with ; , or tab."

  @doc "Allowed heights, clamped."
  def height(value) when is_integer(value), do: value |> max(120) |> min(640)
  def height(_value), do: 260

  attr :title, :string, default: ""
  attr :inline, :list, default: []

  def title(assigns) do
    ~H"""
    <figcaption
      :if={@title not in [nil, ""] or @inline != []}
      style="font-weight:600;font-size:14px;line-height:1.4;margin:0 0 10px"
      {@inline}
    >
      {@title}
    </figcaption>
    """
  end

  attr :names, :list, required: true
  attr :palette, :string, required: true
  attr :dashed, :list, default: []

  def legend(assigns) do
    ~H"""
    <div style="display:flex;flex-wrap:wrap;gap:6px 14px;margin-top:8px;font-size:12px;opacity:.85">
      <span
        :for={{name, index} <- Enum.with_index(@names)}
        style="display:inline-flex;align-items:center;gap:6px"
      >
        <span style={
          if name in @dashed,
            do: "width:14px;border-top:2px dashed #{Chart.color(@palette, index)}",
            else:
              "width:10px;height:10px;border-radius:3px;background:#{Chart.color(@palette, index)}"
        }></span>
        {name}
      </span>
    </div>
    """
  end

  def empty(assigns) do
    ~H"""
    <div style="display:flex;align-items:center;justify-content:center;min-height:96px;border:1px dashed rgba(148,163,184,.6);border-radius:12px;font-size:13px;opacity:.7;padding:12px;text-align:center">
      {t("No data yet: write it in the Data field")}
    </div>
    """
  end

  @doc "Rounds a coordinate for the SVG."
  def r(value), do: Float.round(value / 1, 1)

  @doc "Cuts a label to `max` characters."
  def short(label, max \\ 14) do
    if String.length(label) > max, do: String.slice(label, 0, max - 1) <> "…", else: label
  end
end
