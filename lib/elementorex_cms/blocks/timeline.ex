defmodule ElementorexCms.Blocks.Timeline do
  @moduledoc "daisyUI timeline: dated milestones, vertical or horizontal."

  use ElementorexCms.Block,
    type: "timeline",
    label: "Timeline",
    icon: "calendar-days",
    category: :components,
    description: "Milestones in order",
    keywords: ~w(history milestones roadmap linea tiempo hitos)

  alias ElementorexCms.Blocks.Options

  prop(:items, :list,
    label: "Milestones",
    item_label: :title,
    max_items: 20,
    default: [
      %{"date" => "2024", "title" => "We started", "done" => true},
      %{"date" => "2025", "title" => "1,000 customers", "done" => true},
      %{"date" => "2026", "title" => "New products", "done" => false}
    ],
    fields: [
      {:date, :string, label: "Date"},
      {:title, :string, label: "Title", default: "Milestone"},
      {:text, :string, label: "Text"},
      {:done, :boolean, label: "Reached", default: false}
    ]
  )

  prop(:direction, :select,
    label: "Direction",
    options: [{"Vertical", "vertical"}, {"Horizontal", "horizontal"}],
    default: "vertical",
    control: :segmented
  )

  prop(:compact, :boolean,
    label: "All on one side",
    default: false,
    show_if: {:direction, "vertical"}
  )

  prop(:color, :select,
    label: "Color",
    options: Options.colors(),
    default: "primary",
    control: :swatches
  )

  @text %{
    "primary" => "text-primary",
    "secondary" => "text-secondary",
    "accent" => "text-accent",
    "neutral" => "text-neutral",
    "info" => "text-info",
    "success" => "text-success",
    "warning" => "text-warning",
    "error" => "text-error"
  }
  @bg %{
    "primary" => "bg-primary",
    "secondary" => "bg-secondary",
    "accent" => "bg-accent",
    "neutral" => "bg-neutral",
    "info" => "bg-info",
    "success" => "bg-success",
    "warning" => "bg-warning",
    "error" => "bg-error"
  }

  def render(assigns) do
    assigns = assign(assigns, :count, length(assigns.items))

    ~H"""
    <ul {root(assigns,
      class: [
        "timeline",
        if(@direction == "vertical", do: "timeline-vertical", else: "timeline-horizontal max-md:timeline-vertical"),
        @compact && "timeline-compact",
        "timeline-snap-icon"
      ]
    )}>
      <li :for={{item, index} <- Enum.with_index(@items)}>
        <hr :if={index > 0} class={item["done"] && Map.get(bgs(), @color)} />
        <div
          :if={item["date"] != ""}
          class={["font-mono text-sm opacity-70", side(index, @compact, :date)]}
        >
          {item["date"]}
        </div>
        <div class="timeline-middle">
          <.heroicon
            name="check-circle"
            style="mini"
            class={["size-5", item["done"] && Map.get(texts(), @color)]}
          />
        </div>
        <div class={["timeline-box", side(index, @compact, :box)]}>
          <div class="font-bold">{item["title"]}</div>
          <div :if={item["text"] != ""} class="text-sm opacity-80">{item["text"]}</div>
        </div>
        <hr
          :if={index < @count - 1}
          class={Enum.at(@items, index + 1)["done"] && Map.get(bgs(), @color)}
        />
      </li>
    </ul>
    """
  end

  defp side(_index, true, :date), do: "timeline-start"
  defp side(_index, true, :box), do: "timeline-end"

  defp side(index, _compact, :date),
    do: if(rem(index, 2) == 0, do: "timeline-start md:text-end", else: "timeline-end")

  defp side(index, _compact, :box),
    do: if(rem(index, 2) == 0, do: "timeline-end", else: "timeline-start")

  defp texts, do: @text
  defp bgs, do: @bg
end
