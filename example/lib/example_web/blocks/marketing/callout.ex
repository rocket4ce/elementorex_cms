defmodule ExampleWeb.Blocks.Marketing.Callout do
  @moduledoc """
  Callout box for the visual editor (ElementorexCms): a container with an icon,
  a title and a background image or color, that holds other blocks.

  Exercises `container: true`, `:children` restrictions, `:image`, `:color`
  and values passed through `style/1`.
  """

  use ElementorexCms.Block,
    type: "callout",
    label: "Callout",
    icon: "sparkles",
    category: :marketing,
    description: "A highlighted box that holds text and buttons",
    keywords: ~w(callout box highlight destacado caja),
    container: true,
    children: ~w(heading text button button_group badge list whatsapp),
    style: %{"desktop" => %{"padding-top" => "32px", "padding-bottom" => "32px"}}

  prop :title, :string, label: "Title", default: "Don't miss it", inline: true
  prop :icon, :icon, label: "Icon", default: "sparkles"

  prop :background, :color,
    label: "Background",
    default: "var(--color-base-200)",
    group: "Background"

  prop :image, :image, label: "Background image", group: "Background"

  prop :overlay, :boolean,
    label: "Darken the image",
    default: true,
    group: "Background",
    show_if: {:image, :present}

  def render(assigns) do
    ~H"""
    <section {root(assigns,
      class: [
        "relative isolate flex flex-col gap-4 overflow-hidden rounded-box px-8",
        @image != "" && @overlay && "text-white"
      ],
      style: background(@background, @image)
    )}>
      <div :if={@image != "" and @overlay} class="absolute inset-0 -z-10 bg-black/50"></div>
      <div class="flex items-center gap-3">
        <.heroicon :if={@icon != ""} name={@icon} class="size-8 shrink-0" />
        <h3 class="text-2xl font-bold" {inline(assigns, :title)}>{@title}</h3>
      </div>
      <.children node={@node} ctx={@ctx} />
    </section>
    """
  end

  defp background(color, ""), do: style([{"background-color", color}])

  defp background(color, image) do
    style([
      {"background-color", color},
      {"background-image", "url(#{image})"},
      {"background-size", "cover"},
      {"background-position", "center"}
    ])
  end
end
