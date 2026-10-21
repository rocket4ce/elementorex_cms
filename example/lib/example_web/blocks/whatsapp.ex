defmodule ExampleWeb.Blocks.Whatsapp do
  @moduledoc """
  WhatsApp button for the visual editor (ElementorexCms).

  Shows how a block depends on the page it is rendered in: the phone number
  comes from `@ctx.data` (`data={%{whatsapp: "..."}}` on the editor and on
  `<ElementorexCms.Components.document>`) unless the block overrides it.
  """

  use ElementorexCms.Block,
    type: "whatsapp",
    label: "WhatsApp",
    icon: "chat-bubble-oval-left",
    category: :basic,
    description: "Button that opens a WhatsApp chat",
    keywords: ~w(whatsapp chat contact contacto mensaje)

  prop :label, :string, label: "Text", default: "Write to us on WhatsApp", inline: true

  prop :message, :text,
    label: "Message",
    default: "Hi! I would like more information.",
    help: "Text the chat starts with"

  prop :phone, :string,
    label: "Phone",
    help: "Leave it empty to use the number of the site",
    group: "Number"

  prop :size, :select,
    label: "Size",
    options: [{"Small", "sm"}, {"Medium", "md"}, {"Large", "lg"}],
    default: "md",
    control: :segmented,
    group: "Look"

  prop :floating, :boolean,
    label: "Floating",
    default: false,
    help: "Fixed at the bottom right corner of the page",
    group: "Look"

  @sizes %{"sm" => "btn-sm", "md" => "btn-md", "lg" => "btn-lg"}

  def render(assigns) do
    assigns = assign(assigns, :href, href(assigns))

    ~H"""
    <a {root(assigns,
      class: [
        "btn w-fit gap-2 border-0 bg-[#25D366] text-white hover:bg-[#1ebe5a]",
        Map.get(sizes(), @size),
        @floating && !editor?(assigns) && "fixed right-6 bottom-6 z-50 rounded-full shadow-lg"
      ],
      attrs: if(@href, do: [{"href", @href}, {"target", "_blank"}, {"rel", "noopener"}], else: [])
    )}>
      <.heroicon name="chat-bubble-oval-left-ellipsis" style="solid" class="size-[1.2em] shrink-0" />
      <span {inline(assigns, :label)}>{@label}</span>
    </a>
    """
  end

  defp href(assigns) do
    phone =
      case assigns.phone do
        "" -> assigns.ctx.data[:whatsapp] || ""
        phone -> phone
      end

    case String.replace(phone, ~r/\D/, "") do
      "" -> nil
      digits -> "https://wa.me/#{digits}?" <> URI.encode_query(%{"text" => assigns.message})
    end
  end

  defp sizes, do: @sizes
end
