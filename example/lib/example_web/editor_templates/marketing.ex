defmodule ExampleWeb.EditorTemplates.Marketing do
  @moduledoc """
  Ready-made sections for the visual editor (ElementorexCms *Templates* panel),
  built with the app's own blocks next to the built-in ones.
  """

  @behaviour ElementorexCms.Templates

  import ElementorexCms.Builder

  @impl true
  def templates do
    [
      %{
        key: "marketing_hero",
        label: "Hero with call to action",
        description: "Headline, text and two buttons",
        icon: "sparkles",
        nodes: fn ->
          [
            section([
              block("badge", %{text: "New"}),
              block("heading", %{text: "Your headline", level: "h2", size: "4xl"}),
              block("text", %{text: "<p>One or two lines that explain the offer.</p>"}),
              block("button_group", %{})
            ])
          ]
        end
      },
      %{
        key: "marketing_pricing",
        label: "Pricing table",
        description: "Three plans, the middle one featured",
        icon: "currency-dollar",
        nodes: fn ->
          [
            section([
              block("heading", %{text: "Plans for every size", level: "h2", align: "center"}),
              columns(
                [
                  [block("pricing", %{plan: "Starter", price: "$0", cta: "Start free"})],
                  [block("pricing", %{plan: "Pro", price: "$9.990", featured: true})],
                  [block("pricing", %{plan: "Business", price: "$29.990", cta: "Talk to sales"})]
                ],
                %{columns: "3", columns_tablet: "3", columns_mobile: "1"}
              )
            ])
          ]
        end
      },
      %{
        key: "marketing_contact",
        label: "Contact callout",
        description: "Callout with text and a WhatsApp button",
        icon: "chat-bubble-oval-left",
        nodes: fn ->
          [
            block("callout", %{title: "Questions?", icon: "chat-bubble-left-right"},
              children: [
                block("text", %{text: "<p>We answer in minutes, every day.</p>"}),
                block("whatsapp", %{})
              ]
            )
          ]
        end
      }
    ]
  end
end
