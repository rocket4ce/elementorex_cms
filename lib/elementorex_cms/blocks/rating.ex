defmodule ElementorexCms.Blocks.Rating do
  @moduledoc "daisyUI rating (read only): stars or hearts, with halves."

  use ElementorexCms.Block,
    type: "rating",
    label: "Rating",
    icon: "star",
    category: :components,
    description: "Score with stars",
    keywords: ~w(stars score review estrellas puntuacion)

  alias ElementorexCms.Blocks.Options

  prop(:value, :number, label: "Value", default: 4.5, min: 0, max: 10, step: 0.5)
  prop(:max, :select, label: "Out of", options: ~w(5 10), default: "5", control: :segmented)

  prop(:shape, :select,
    label: "Shape",
    options: [{"Star", "star-2"}, {"Rounded star", "star"}, {"Heart", "heart"}],
    default: "star-2",
    control: :segmented
  )

  prop(:color, :select,
    label: "Color",
    options: [
      {"Amber", "amber"},
      {"Primary", "primary"},
      {"Secondary", "secondary"},
      {"Accent", "accent"},
      {"Error", "error"}
    ],
    default: "amber",
    control: :swatches
  )

  prop(:size, :select,
    label: "Size",
    options: Options.sizes(),
    default: "md",
    control: :segmented
  )

  prop(:label, :string, label: "Text next to it", inline: true)

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented
  )

  @masks %{"star-2" => "mask-star-2", "star" => "mask-star", "heart" => "mask-heart"}
  @colors %{
    "amber" => "bg-amber-400",
    "primary" => "bg-primary",
    "secondary" => "bg-secondary",
    "accent" => "bg-accent",
    "error" => "bg-error"
  }
  @sizes %{
    "xs" => "rating-xs",
    "sm" => "rating-sm",
    "md" => "rating-md",
    "lg" => "rating-lg",
    "xl" => "rating-xl"
  }
  @align %{"left" => "justify-start", "center" => "justify-center", "right" => "justify-end"}

  def render(assigns) do
    assigns = assign(assigns, :halves, halves(assigns.value, assigns.max))

    ~H"""
    <div {root(assigns, class: ["flex items-center gap-2", Map.get(aligns(), @align)])}>
      <div
        class={["rating rating-half", Map.get(sizes(), @size)]}
        aria-label={t("%{value} out of %{max}", value: @value, max: @max)}
      >
        <div :if={@halves.current == 0} class="rating-hidden" aria-current="true"></div>
        <div
          :for={half <- 1..@halves.total}
          class={[
            "mask",
            Map.get(masks(), @shape),
            if(rem(half, 2) == 1, do: "mask-half-1", else: "mask-half-2"),
            Map.get(colors(), @color)
          ]}
          aria-current={half == @halves.current && "true"}
        >
        </div>
      </div>
      <span :if={@label != ""} class="text-sm font-medium" {inline(assigns, :label)}>{@label}</span>
    </div>
    """
  end

  defp halves(value, max) do
    max = String.to_integer(max)
    %{total: max * 2, current: value |> min(max) |> Kernel.*(2) |> round()}
  end

  defp masks, do: @masks
  defp colors, do: @colors
  defp sizes, do: @sizes
  defp aligns, do: @align
end
