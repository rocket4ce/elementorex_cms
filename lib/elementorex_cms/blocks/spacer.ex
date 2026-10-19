defmodule ElementorexCms.Blocks.Spacer do
  @moduledoc "Empty vertical space."

  use ElementorexCms.Block,
    type: "spacer",
    label: "Spacer",
    icon: "arrows-up-down",
    category: :layout,
    description: "Blank space between components",
    keywords: ~w(space gap espacio)

  prop(:height, :integer,
    label: "Height",
    default: 32,
    min: 0,
    max: 600,
    unit: "px",
    control: :range
  )

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: "w-full", style: style([{"height", "#{@height}px"}]), attrs: [{"aria-hidden", "true"}])}>
    </div>
    """
  end
end
