defmodule ElementorexCms.Blocks.Heading do
  @moduledoc "A heading (`<h1>`-`<h6>`), editable by typing on the canvas."

  use ElementorexCms.Block,
    type: "heading",
    label: "Heading",
    icon: "h1",
    category: :basic,
    description: "Title or subtitle",
    keywords: ~w(title headline titulo encabezado h1 h2)

  alias ElementorexCms.Blocks.Options

  prop(:text, :richtext,
    label: "Text",
    default: "Add your heading",
    inline: true,
    policy: :inline,
    control: :textarea
  )

  prop(:level, :select,
    label: "HTML tag",
    options: ~w(h1 h2 h3 h4 h5 h6 p div),
    default: "h2",
    control: :segmented
  )

  prop(:size, :select,
    label: "Size",
    options: [
      {"Auto", "auto"},
      {"S", "lg"},
      {"M", "xl"},
      {"L", "2xl"},
      {"XL", "3xl"},
      {"2XL", "4xl"},
      {"3XL", "5xl"},
      {"4XL", "6xl"}
    ],
    default: "3xl"
  )

  prop(:weight, :select,
    label: "Weight",
    options: [
      {"Normal", "normal"},
      {"Medium", "medium"},
      {"Semibold", "semibold"},
      {"Bold", "bold"},
      {"Extra bold", "extrabold"},
      {"Black", "black"}
    ],
    default: "bold"
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "left",
    control: :segmented
  )

  prop(:link, :url, label: "Link", group: "Link")

  prop(:new_tab, :boolean,
    label: "Open in a new tab",
    default: false,
    group: "Link",
    show_if: {:link, :present}
  )

  @sizes %{
    "auto" => nil,
    "lg" => "text-lg",
    "xl" => "text-xl",
    "2xl" => "text-2xl",
    "3xl" => "text-3xl max-md:text-2xl",
    "4xl" => "text-4xl max-md:text-3xl",
    "5xl" => "text-5xl max-md:text-4xl",
    "6xl" => "text-6xl max-md:text-4xl"
  }
  @weights %{
    "normal" => "font-normal",
    "medium" => "font-medium",
    "semibold" => "font-semibold",
    "bold" => "font-bold",
    "extrabold" => "font-extrabold",
    "black" => "font-black"
  }
  @align %{"left" => "text-left", "center" => "text-center", "right" => "text-right"}

  def render(assigns) do
    ~H"""
    <.dynamic_tag
      tag_name={@level}
      {root(assigns, class: ["leading-tight text-balance", Map.get(sizes(), @size), Map.get(weights(), @weight), Map.get(aligns(), @align)])}
    >
      <%= if @link != "" do %>
        <a class="hover:underline" {link_attrs(@link, @new_tab)} {inline(assigns, :text)}>{rich_inline(
          @text
        )}</a>
      <% else %>
        <span {inline(assigns, :text)}>{rich_inline(@text)}</span>
      <% end %>
    </.dynamic_tag>
    """
  end

  defp sizes, do: @sizes
  defp weights, do: @weights
  defp aligns, do: @align
end
