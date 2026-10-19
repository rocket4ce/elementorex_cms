defmodule ElementorexCms.Blocks.Countdown do
  @moduledoc """
  daisyUI countdown to a date and time. The values are computed when the page is
  rendered and kept ticking by the runtime script (`elementorex_cms/runtime`,
  see the README); without it the countdown shows the values of the render.

  The target time is read in the time zone configured with
  `config :elementorex_cms, time_zone: "America/Santiago"` (UTC by default; any
  other zone needs a time zone database such as `tz` or `tzdata`).
  """

  use ElementorexCms.Block,
    type: "countdown",
    label: "Countdown",
    icon: "clock",
    category: :components,
    description: "Time left until a date",
    keywords: ~w(timer clock deadline cuenta regresiva reloj)

  prop(:target, :datetime, label: "Ends at", default: "2030-01-01T00:00")
  prop(:show_days, :boolean, label: "Days", default: true, group: "Units")
  prop(:show_hours, :boolean, label: "Hours", default: true, group: "Units")
  prop(:show_minutes, :boolean, label: "Minutes", default: true, group: "Units")
  prop(:show_seconds, :boolean, label: "Seconds", default: true, group: "Units")

  prop(:style, :select,
    label: "Style",
    options: [{"Boxes", "boxes"}, {"Plain", "plain"}],
    default: "boxes",
    control: :segmented
  )

  prop(:size, :select,
    label: "Size",
    options: [{"S", "2xl"}, {"M", "4xl"}, {"L", "5xl"}, {"XL", "6xl"}],
    default: "4xl",
    control: :segmented
  )

  prop(:align, :select,
    label: "Alignment",
    options: [{"Left", "left"}, {"Center", "center"}, {"Right", "right"}],
    default: "center",
    control: :segmented
  )

  prop(:expired_text, :string, label: "Text when it ends", default: "It's over!")

  @sizes %{"2xl" => "text-2xl", "4xl" => "text-4xl", "5xl" => "text-5xl", "6xl" => "text-6xl"}
  @align %{"left" => "justify-start", "center" => "justify-center", "right" => "justify-end"}

  def render(assigns) do
    assigns = assign(assigns, :units, units(assigns))

    ~H"""
    <div {root(assigns,
      class: ["flex flex-wrap gap-3 text-center", Map.get(aligns(), @align)],
      attrs: [{"data-ex-countdown", target_instant(@target) || ""}, {"data-ex-expired", @expired_text}]
    )}>
      <div
        :for={{unit, value, label} <- @units}
        data-ex-unit={unit}
        class={[
          "flex flex-col items-center",
          @style == "boxes" && "rounded-box bg-neutral text-neutral-content min-w-20 px-3 py-2"
        ]}
      >
        <span class={[value <= 99 && "countdown", "font-mono font-bold", Map.get(sizes(), @size)]}>
          <span style={value <= 99 && "--value:#{value};"} aria-live="polite" aria-label={value}>{value}</span>
        </span>
        <span class="text-xs uppercase tracking-wide opacity-70">{label}</span>
      </div>
    </div>
    """
  end

  defp units(assigns) do
    seconds = remaining(assigns.target)

    [
      {assigns.show_days, "days", div(seconds, 86_400), t("days")},
      {assigns.show_hours, "hours", rem(div(seconds, 3600), 24), t("hours")},
      {assigns.show_minutes, "minutes", rem(div(seconds, 60), 60), t("min")},
      {assigns.show_seconds, "seconds", rem(seconds, 60), t("sec")}
    ]
    |> Enum.filter(&elem(&1, 0))
    |> Enum.map(fn {_, unit, value, label} -> {unit, value, label} end)
  end

  defp remaining(target) do
    case to_datetime(target) do
      nil -> 0
      datetime -> max(DateTime.diff(datetime, DateTime.utc_now()), 0)
    end
  end

  # The runtime script ticks against this UTC instant.
  defp target_instant(target) do
    case to_datetime(target) do
      nil -> nil
      datetime -> datetime |> DateTime.shift_zone!("Etc/UTC") |> DateTime.to_iso8601()
    end
  end

  defp to_datetime(target) do
    with {:ok, naive} <- NaiveDateTime.from_iso8601(normalize(target)),
         {:ok, datetime} <- DateTime.from_naive(naive, time_zone()) do
      datetime
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp normalize(target) do
    if String.length(target) == 16, do: target <> ":00", else: target
  end

  defp time_zone, do: Application.get_env(:elementorex_cms, :time_zone, "Etc/UTC")

  defp sizes, do: @sizes
  defp aligns, do: @align
end
