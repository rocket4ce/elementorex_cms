defmodule ElementorexCms.Blocks.Progress do
  @moduledoc "daisyUI progress bar or radial progress with its value."

  use ElementorexCms.Block,
    type: "progress",
    label: "Progress",
    icon: "chart-pie",
    category: :components,
    description: "Bar or circle with a percentage",
    keywords: ~w(bar percentage radial progreso barra porcentaje)

  alias ElementorexCms.Blocks.Options

  prop(:kind, :select,
    label: "Kind",
    options: [{"Bar", "bar"}, {"Circle", "radial"}],
    default: "bar",
    control: :segmented
  )

  prop(:value, :integer,
    label: "Value",
    default: 70,
    min: 0,
    max: 100,
    unit: "%",
    control: :range
  )

  prop(:label, :string, label: "Label", default: "Progress", inline: true)
  prop(:show_value, :boolean, label: "Show value", default: true)

  prop(:color, :select,
    label: "Color",
    options: Options.colors(),
    default: "primary",
    control: :swatches
  )

  prop(:size, :select,
    label: "Size",
    options: [{"S", "sm"}, {"M", "md"}, {"L", "lg"}],
    default: "md",
    control: :segmented
  )

  @bars %{
    "primary" => "progress-primary",
    "secondary" => "progress-secondary",
    "accent" => "progress-accent",
    "neutral" => "progress-neutral",
    "info" => "progress-info",
    "success" => "progress-success",
    "warning" => "progress-warning",
    "error" => "progress-error"
  }
  @texts %{
    "primary" => "text-primary",
    "secondary" => "text-secondary",
    "accent" => "text-accent",
    "neutral" => "text-neutral",
    "info" => "text-info",
    "success" => "text-success",
    "warning" => "text-warning",
    "error" => "text-error"
  }
  @heights %{"sm" => "h-1.5", "md" => "h-2.5", "lg" => "h-4"}
  @radial %{
    "sm" => "--size:4rem;--thickness:5px",
    "md" => "--size:6rem;--thickness:8px",
    "lg" => "--size:8rem;--thickness:10px"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["flex w-full flex-col gap-2", @kind == "radial" && "items-center"])}>
      <div
        :if={@kind == "bar" and (@label != "" or @show_value)}
        class="flex items-baseline justify-between gap-3 text-sm font-medium"
      >
        <span {inline(assigns, :label)}>{@label}</span>
        <span :if={@show_value} class="font-mono">{@value}%</span>
      </div>
      <progress
        :if={@kind == "bar"}
        class={["progress w-full", Map.get(bars(), @color), Map.get(heights(), @size)]}
        value={@value}
        max="100"
      ></progress>
      <div
        :if={@kind == "radial"}
        class={["radial-progress font-bold", Map.get(texts(), @color)]}
        style={"--value:#{@value};" <> Map.get(radials(), @size)}
        role="progressbar"
        aria-valuenow={@value}
      >
        <span :if={@show_value}>{@value}%</span>
      </div>
      <span
        :if={@kind == "radial" and @label != ""}
        class="text-sm font-medium"
        {inline(assigns, :label)}
      >{@label}</span>
    </div>
    """
  end

  defp bars, do: @bars
  defp texts, do: @texts
  defp heights, do: @heights
  defp radials, do: @radial
end
