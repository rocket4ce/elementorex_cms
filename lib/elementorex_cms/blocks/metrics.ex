defmodule ElementorexCms.Blocks.Metrics do
  @moduledoc """
  Key figures in cards: a value with its label, a note, a trend arrow and a
  tone (good, warning, bad). Drawn with inline styles, without a CSS
  framework; the cards wrap to the width available.
  """

  use ElementorexCms.Block,
    type: "metrics",
    label: "Metrics",
    icon: "presentation-chart-bar",
    category: :charts,
    description: "Key figures with trend and tone",
    keywords: ~w(kpi metrics figures numbers indicators indicadores cifras metricas)

  prop(:items, :list,
    label: "Figures",
    item_label: :label,
    max_items: 12,
    default: [
      %{
        "label" => "Progress",
        "value" => "62%",
        "note" => "Planned 58%",
        "trend" => "up",
        "tone" => "good"
      },
      %{
        "label" => "Late tasks",
        "value" => "3",
        "note" => "2 critical",
        "trend" => "down",
        "tone" => "warning"
      },
      %{
        "label" => "Open constraints",
        "value" => "4",
        "note" => "1 overdue",
        "trend" => "",
        "tone" => "bad"
      }
    ],
    fields: [
      {:label, :string, label: "Label", default: "Label"},
      {:value, :string, label: "Value", default: "0"},
      {:note, :string, label: "Note"},
      {:trend, :select,
       label: "Trend",
       options: [{"None", ""}, {"Up", "up"}, {"Down", "down"}, {"Flat", "flat"}],
       default: ""},
      {:tone, :select,
       label: "Tone",
       options: [{"Neutral", "neutral"}, {"Good", "good"}, {"Warning", "warning"}, {"Bad", "bad"}],
       default: "neutral"}
    ]
  )

  prop(:min_width, :integer,
    label: "Card width",
    default: 150,
    min: 110,
    max: 320,
    unit: "px",
    control: :range
  )

  @tones %{"good" => "#059669", "warning" => "#d97706", "bad" => "#e11d48"}
  @arrows %{"up" => "▲", "down" => "▼", "flat" => "▶"}

  def render(assigns) do
    ~H"""
    <div {root(assigns, style: "display:grid;grid-template-columns:repeat(auto-fit,minmax(#{width(@min_width)}px,1fr));gap:12px;width:100%")}>
      <div
        :for={item <- @items}
        style={"border:1px solid rgba(148,163,184,.35);border-radius:14px;padding:12px 14px;background:rgba(148,163,184,.06);#{tone_border(item["tone"])}"}
      >
        <div style="font-size:12px;opacity:.7;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">
          {item["label"]}
        </div>
        <div style={"display:flex;align-items:baseline;gap:6px;margin-top:4px;font-size:24px;font-weight:700;line-height:1.15;font-variant-numeric:tabular-nums;#{tone_color(item["tone"])}"}>
          {item["value"]}
          <span :if={arrow(item["trend"])} style="font-size:12px">{arrow(item["trend"])}</span>
        </div>
        <div :if={item["note"] not in [nil, ""]} style="margin-top:4px;font-size:12px;opacity:.7">
          {item["note"]}
        </div>
      </div>
    </div>
    """
  end

  defp width(value) when is_integer(value), do: value |> max(110) |> min(320)
  defp width(_value), do: 150

  defp arrow(trend), do: Map.get(@arrows, trend)

  defp tone_color(tone) do
    case Map.get(@tones, tone) do
      nil -> ""
      color -> "color:#{color}"
    end
  end

  defp tone_border(tone) do
    case Map.get(@tones, tone) do
      nil -> ""
      color -> "border-left:3px solid #{color}"
    end
  end
end
