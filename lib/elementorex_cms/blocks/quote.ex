defmodule ElementorexCms.Blocks.Quote do
  @moduledoc "A quote or testimonial with its author."

  use ElementorexCms.Block,
    type: "quote",
    label: "Testimonial",
    icon: "chat-bubble-bottom-center-text",
    category: :components,
    description: "Quote with author and photo",
    keywords: ~w(quote blockquote review testimonio cita opinion)

  alias ElementorexCms.Blocks.Options

  prop(:text, :richtext,
    label: "Quote",
    default: "<p>It changed the way we work. Simple and fast.</p>",
    inline: true
  )

  prop(:author, :string, label: "Author", default: "María Pérez", inline: true)
  prop(:role, :string, label: "Role", default: "Customer since 2024", inline: true)
  prop(:image, :image, label: "Photo")

  prop(:style, :select,
    label: "Style",
    options: [{"Card", "card"}, {"Plain", "plain"}],
    default: "card",
    control: :segmented
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented
  )

  @align %{
    "left" => "items-start text-left",
    "center" => "items-center text-center",
    "right" => "items-end text-right"
  }

  def render(assigns) do
    ~H"""
    <figure {root(assigns,
      class: ["flex flex-col gap-4", Map.get(aligns(), @align), @style == "card" && "rounded-box border border-base-300 bg-base-100 p-6 shadow-sm"]
    )}>
      <span class="font-serif text-5xl leading-none text-primary" aria-hidden="true">&ldquo;</span>
      <blockquote class="exr-rich -mt-4 text-lg leading-relaxed" {inline(assigns, :text)}>
        {rich(@text)}
      </blockquote>
      <figcaption class="flex items-center gap-3">
        <img
          :if={@image != ""}
          src={@image}
          alt={@author}
          class="size-11 rounded-full object-cover"
          loading="lazy"
        />
        <span class="flex flex-col text-left">
          <span class="font-semibold" {inline(assigns, :author)}>{@author}</span>
          <span :if={@role != ""} class="text-sm opacity-70" {inline(assigns, :role)}>{@role}</span>
        </span>
      </figcaption>
    </figure>
    """
  end

  defp aligns, do: @align
end
