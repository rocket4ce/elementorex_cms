defmodule ElementorexCms.Blocks.Divider do
  @moduledoc "daisyUI divider: a line, optionally with a text in it."

  use ElementorexCms.Block,
    type: "divider",
    label: "Divider",
    icon: "minus",
    category: :layout,
    description: "Separator line with optional text",
    keywords: ~w(hr line separator linea separador)

  alias ElementorexCms.Blocks.Options

  prop(:text, :string, label: "Text", default: "", inline: true)

  prop(:color, :select,
    label: "Color",
    options: Options.colors_with_default(),
    default: "default",
    control: :swatches
  )

  prop(:position, :select,
    label: "Text position",
    options: [{"Start", "start"}, {"Center", "center"}, {"End", "end"}],
    default: "center",
    control: :segmented,
    show_if: {:text, :present}
  )

  prop(:vertical, :boolean, label: "Vertical", default: false)

  @colors %{
    "default" => nil,
    "primary" => "divider-primary",
    "secondary" => "divider-secondary",
    "accent" => "divider-accent",
    "neutral" => "divider-neutral",
    "info" => "divider-info",
    "success" => "divider-success",
    "warning" => "divider-warning",
    "error" => "divider-error"
  }
  @positions %{"start" => "divider-start", "center" => nil, "end" => "divider-end"}

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["divider", Map.get(colors(), @color), Map.get(positions(), @position), @vertical && "divider-horizontal"])}>
      <span :if={@text != ""} {inline(assigns, :text)}>{@text}</span>
    </div>
    """
  end

  defp colors, do: @colors
  defp positions, do: @positions
end
