defmodule ElementorexCms.Blocks.Chat do
  @moduledoc "daisyUI chat bubbles: a conversation, a testimonial, a FAQ in dialogue."

  use ElementorexCms.Block,
    type: "chat",
    label: "Chat",
    icon: "chat-bubble-left-right",
    category: :components,
    description: "Conversation bubbles",
    keywords: ~w(conversation bubbles testimonial conversacion burbujas)

  alias ElementorexCms.Blocks.Options

  prop(:items, :list,
    label: "Messages",
    item_label: :text,
    max_items: 20,
    default: [
      %{"side" => "start", "name" => "Customer", "text" => "Is it really 100% online?"},
      %{
        "side" => "end",
        "name" => "Support",
        "text" => "Yes! You can sign up in two minutes.",
        "color" => "primary"
      }
    ],
    fields: [
      {:side, :select,
       label: "Side",
       options: [{"Left", "start"}, {"Right", "end"}],
       default: "start",
       control: :segmented},
      {:name, :string, label: "Name"},
      {:text, :text, label: "Message", default: "Hello!"},
      {:image, :image, label: "Photo"},
      {:time, :string, label: "Time"},
      {:color, :select,
       label: "Color",
       options: Options.colors_with_default(),
       default: "default",
       control: :swatches}
    ]
  )

  @colors %{
    "default" => nil,
    "primary" => "chat-bubble-primary",
    "secondary" => "chat-bubble-secondary",
    "accent" => "chat-bubble-accent",
    "neutral" => "chat-bubble-neutral",
    "info" => "chat-bubble-info",
    "success" => "chat-bubble-success",
    "warning" => "chat-bubble-warning",
    "error" => "chat-bubble-error"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: "flex w-full flex-col")}>
      <div
        :for={item <- @items}
        class={["chat", if(item["side"] == "end", do: "chat-end", else: "chat-start")]}
      >
        <div :if={item["image"] != ""} class="chat-image avatar">
          <div class="w-10 rounded-full">
            <img src={item["image"]} alt={item["name"]} loading="lazy" />
          </div>
        </div>
        <div :if={item["name"] != "" or item["time"] != ""} class="chat-header">
          {item["name"]}
          <time :if={item["time"] != ""} class="text-xs opacity-50">{item["time"]}</time>
        </div>
        <div class={["chat-bubble whitespace-pre-line", Map.get(colors(), item["color"])]}>
          {item["text"]}
        </div>
      </div>
    </div>
    """
  end

  defp colors, do: @colors
end
