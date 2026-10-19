defmodule ElementorexCms.Blocks.Steps do
  @moduledoc "daisyUI steps: a process with done and pending steps."

  use ElementorexCms.Block,
    type: "steps",
    label: "Steps",
    icon: "numbered-list",
    category: :components,
    description: "Steps of a process",
    keywords: ~w(process wizard progress pasos proceso)

  alias ElementorexCms.Blocks.Options

  prop(:items, :list,
    label: "Steps",
    item_label: :label,
    max_items: 10,
    default: [
      %{"label" => "Choose", "done" => true},
      %{"label" => "Fill in", "done" => true},
      %{"label" => "Pay", "done" => false},
      %{"label" => "Done", "done" => false}
    ],
    fields: [
      {:label, :string, label: "Text", default: "Step"},
      {:done, :boolean, label: "Done", default: false},
      {:content, :string,
       label: "Marker", help: "Replaces the number, e.g. ✓ or ★", max_length: 2}
    ]
  )

  prop(:color, :select,
    label: "Color",
    options: Options.colors(),
    default: "primary",
    control: :swatches
  )

  prop(:direction, :select,
    label: "Direction",
    options: [{"Horizontal", "horizontal"}, {"Vertical", "vertical"}],
    default: "horizontal",
    control: :segmented
  )

  prop(:vertical_on_mobile, :boolean,
    label: "Vertical on mobile",
    default: true,
    show_if: {:direction, "horizontal"}
  )

  @colors %{
    "primary" => "step-primary",
    "secondary" => "step-secondary",
    "accent" => "step-accent",
    "neutral" => "step-neutral",
    "info" => "step-info",
    "success" => "step-success",
    "warning" => "step-warning",
    "error" => "step-error"
  }

  def render(assigns) do
    ~H"""
    <ul {root(assigns,
      class: [
        "steps w-full",
        if(@direction == "vertical", do: "steps-vertical", else: ["steps-horizontal", @vertical_on_mobile && "max-md:steps-vertical"])
      ]
    )}>
      <li
        :for={item <- @items}
        class={["step", item["done"] && Map.get(colors(), @color)]}
        data-content={if(item["content"] != "", do: item["content"])}
      >
        {item["label"]}
      </li>
    </ul>
    """
  end

  defp colors, do: @colors
end
