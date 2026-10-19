defmodule ElementorexCms.Blocks.Accordion do
  @moduledoc """
  daisyUI collapse as an accordion (FAQ). Built on `<details>`, so it opens and
  closes without JavaScript; with *One at a time* the browser closes the others.
  """

  use ElementorexCms.Block,
    type: "accordion",
    label: "Accordion",
    icon: "queue-list",
    category: :components,
    description: "Questions and answers that expand",
    keywords: ~w(faq collapse toggle preguntas frecuentes acordeon)

  prop(:items, :list,
    label: "Items",
    item_label: :title,
    max_items: 30,
    default: [
      %{"title" => "How does it work?", "content" => "<p>Explain it here.</p>", "open" => true},
      %{"title" => "How much does it cost?", "content" => "<p>Tell them here.</p>"},
      %{"title" => "Can I cancel anytime?", "content" => "<p>Answer here.</p>"}
    ],
    fields: [
      {:title, :string, label: "Title", default: "Question"},
      {:content, :richtext, label: "Content", default: "<p>Answer</p>", control: :textarea},
      {:open, :boolean, label: "Open at first", default: false}
    ]
  )

  prop(:icon, :select,
    label: "Indicator",
    options: [{"Arrow", "arrow"}, {"Plus", "plus"}, {"None", "none"}],
    default: "arrow",
    control: :segmented
  )

  prop(:exclusive, :boolean, label: "One at a time", default: true)

  prop(:style, :select,
    label: "Style",
    options: [{"Bordered", "bordered"}, {"Joined", "joined"}, {"Plain", "plain"}],
    default: "joined",
    control: :segmented
  )

  @icons %{"arrow" => "collapse-arrow", "plus" => "collapse-plus", "none" => nil}

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["w-full", if(@style == "joined", do: "join join-vertical", else: "flex flex-col gap-2")])}>
      <details
        :for={item <- @items}
        class={[
          "collapse",
          Map.get(icons(), @icon),
          @style != "plain" && "bg-base-100 border border-base-300",
          @style == "joined" && "join-item"
        ]}
        name={@exclusive && "ex-#{@node["id"]}"}
        open={item["open"]}
      >
        <summary class="collapse-title font-semibold">{item["title"]}</summary>
        <div class="collapse-content exr-rich text-sm">{rich(item["content"])}</div>
      </details>
    </div>
    """
  end

  defp icons, do: @icons
end
