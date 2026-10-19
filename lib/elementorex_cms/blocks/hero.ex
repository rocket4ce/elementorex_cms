defmodule ElementorexCms.Blocks.Hero do
  @moduledoc """
  daisyUI hero: a large area with an optional background image and overlay that
  centers its content. New heroes come with a heading, a text and a button.
  """

  use ElementorexCms.Block,
    type: "hero",
    label: "Hero",
    icon: "sparkles",
    category: :layout,
    description: "Big banner with background and centered content",
    keywords: ~w(banner header cover portada),
    container: true

  alias ElementorexCms.Document

  prop(:image, :image, label: "Background image")
  prop(:overlay, :boolean, label: "Dark overlay", default: true, show_if: {:image, :present})

  prop(:min_height, :select,
    label: "Minimum height",
    options: [
      {"Auto", "auto"},
      {"Small", "sm"},
      {"Medium", "md"},
      {"Large", "lg"},
      {"Screen", "screen"}
    ],
    default: "sm"
  )

  prop(:align, :select,
    label: "Alignment",
    options: [{"Center", "center"}, {"Left", "left"}],
    default: "center",
    control: :segmented
  )

  prop(:content_width, :select,
    label: "Content width",
    options: [{"S", "md"}, {"M", "xl"}, {"L", "3xl"}, {"Full", "full"}],
    default: "xl",
    control: :segmented
  )

  @heights %{
    "auto" => nil,
    "sm" => "min-h-[320px]",
    "md" => "min-h-[480px]",
    "lg" => "min-h-[640px]",
    "screen" => "min-h-screen"
  }
  @widths %{
    "md" => "max-w-md",
    "xl" => "max-w-xl",
    "3xl" => "max-w-3xl",
    "full" => "max-w-none w-full"
  }

  def default_children do
    [
      Document.node("heading", %{
        "text" => "A headline that matters",
        "level" => "h1",
        "size" => "5xl"
      }),
      Document.node("text", %{
        "text" => "<p>Tell your visitors what this is about in one or two lines.</p>"
      }),
      Document.node("button", %{"label" => "Get started", "size" => "lg", "align" => "center"})
    ]
  end

  def render(assigns) do
    ~H"""
    <div {root(assigns,
      class: ["hero rounded-box", Map.get(heights(), @min_height), @image != "" && "bg-cover bg-center"],
      style: @image != "" && style([{"background-image", "url(#{@image})"}])
    )}>
      <div :if={@image != "" and @overlay} class="hero-overlay rounded-box"></div>
      <div class={[
        "hero-content w-full",
        @align == "center" && "text-center",
        (@image != "" and @overlay) && "text-neutral-content"
      ]}>
        <div class={[
          "flex w-full flex-col gap-4",
          Map.get(widths(), @content_width),
          @align == "center" && "items-center"
        ]}>
          <.children node={@node} ctx={@ctx} />
        </div>
      </div>
    </div>
    """
  end

  defp heights, do: @heights
  defp widths, do: @widths
end
