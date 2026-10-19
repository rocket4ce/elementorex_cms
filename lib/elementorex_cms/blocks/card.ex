defmodule ElementorexCms.Blocks.Card do
  @moduledoc "daisyUI card: image, badge, title, text and a button."

  use ElementorexCms.Block,
    type: "card",
    label: "Card",
    icon: "rectangle-stack",
    category: :components,
    description: "Image, title, text and button in a box",
    keywords: ~w(box tile product tarjeta caja)

  alias ElementorexCms.Blocks.Options

  prop(:image, :image, label: "Image", group: "Image")

  prop(:image_alt, :string,
    label: "Alternative text",
    group: "Image",
    show_if: {:image, :present}
  )

  prop(:image_position, :select,
    label: "Image position",
    options: [{"Top", "top"}, {"Side", "side"}, {"Background", "overlay"}],
    default: "top",
    control: :segmented,
    group: "Image",
    show_if: {:image, :present}
  )

  prop(:badge, :string, label: "Badge", inline: true)
  prop(:title, :string, label: "Title", default: "Card title", inline: true)

  prop(:text, :richtext,
    label: "Text",
    default: "<p>A short description of what this card is about.</p>",
    inline: true
  )

  prop(:button_label, :string, label: "Button text", default: "Learn more", group: "Button")

  prop(:button_url, :url,
    label: "Button link",
    default: "#",
    group: "Button",
    show_if: {:button_label, :present}
  )

  prop(:button_color, :select,
    label: "Button color",
    options: Options.colors_with_default(),
    default: "primary",
    control: :swatches,
    group: "Button",
    show_if: {:button_label, :present}
  )

  prop(:background, :select,
    label: "Background",
    options: [
      {"Base 100", "base-100"},
      {"Base 200", "base-200"},
      {"Primary", "primary"},
      {"Neutral", "neutral"}
    ],
    default: "base-100",
    group: "Look"
  )

  prop(:border, :select,
    label: "Border",
    options: [{"None", "none"}, {"Solid", "border"}, {"Dash", "dash"}],
    default: "border",
    control: :segmented,
    group: "Look"
  )

  prop(:shadow, :select,
    label: "Shadow",
    options: Options.shadows(),
    default: "sm",
    group: "Look"
  )

  prop(:size, :select,
    label: "Padding",
    options: Options.sizes(),
    default: "md",
    control: :segmented,
    group: "Look"
  )

  prop(:centered, :boolean, label: "Center content", default: false, group: "Look")

  @backgrounds %{
    "base-100" => "bg-base-100",
    "base-200" => "bg-base-200",
    "primary" => "bg-primary text-primary-content",
    "neutral" => "bg-neutral text-neutral-content"
  }
  @borders %{"none" => nil, "border" => "card-border", "dash" => "card-dash"}
  @shadows %{
    "none" => nil,
    "sm" => "shadow-sm",
    "md" => "shadow-md",
    "lg" => "shadow-lg",
    "xl" => "shadow-xl",
    "2xl" => "shadow-2xl"
  }
  @sizes %{
    "xs" => "card-xs",
    "sm" => "card-sm",
    "md" => "card-md",
    "lg" => "card-lg",
    "xl" => "card-xl"
  }
  @buttons %{
    "default" => nil,
    "primary" => "btn-primary",
    "secondary" => "btn-secondary",
    "accent" => "btn-accent",
    "neutral" => "btn-neutral",
    "info" => "btn-info",
    "success" => "btn-success",
    "warning" => "btn-warning",
    "error" => "btn-error"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns,
      class: [
        "card w-full",
        Map.get(backgrounds(), @background),
        Map.get(borders(), @border),
        Map.get(shadows(), @shadow),
        Map.get(sizes(), @size),
        @image != "" && @image_position == "side" && "card-side max-md:card-normal",
        @image != "" && @image_position == "overlay" && "image-full"
      ]
    )}>
      <figure :if={@image != ""} class={@image_position == "side" && "md:max-w-[42%]"}>
        <img src={@image} alt={@image_alt} loading="lazy" class="h-full w-full object-cover" />
      </figure>
      <div class={["card-body", @centered && "items-center text-center"]}>
        <h3 class="card-title">
          <span {inline(assigns, :title)}>{@title}</span>
          <span :if={@badge != ""} class="badge badge-secondary badge-sm" {inline(assigns, :badge)}>{@badge}</span>
        </h3>
        <div class="exr-rich" {inline(assigns, :text)}>{rich(@text)}</div>
        <div
          :if={@button_label != ""}
          class={["card-actions mt-2", if(@centered, do: "justify-center", else: "justify-end")]}
        >
          <a class={["btn", Map.get(buttons(), @button_color)]} {link_attrs(@button_url)}>{@button_label}</a>
        </div>
      </div>
    </div>
    """
  end

  defp backgrounds, do: @backgrounds
  defp borders, do: @borders
  defp shadows, do: @shadows
  defp sizes, do: @sizes
  defp buttons, do: @buttons
end
