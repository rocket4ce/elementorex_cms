defmodule ElementorexCms.Blocks.Image do
  @moduledoc "An image with optional link, caption, rounded corners, daisyUI mask and shadow."

  use ElementorexCms.Block,
    type: "image",
    label: "Image",
    icon: "photo",
    category: :media,
    description: "Picture with link and caption",
    keywords: ~w(picture photo img foto imagen)

  alias ElementorexCms.Blocks.Options

  prop(:src, :image, label: "Image")

  prop(:alt, :string,
    label: "Alternative text",
    help: "Describe the image for people who cannot see it"
  )

  prop(:caption, :string, label: "Caption", inline: true)
  prop(:url, :url, label: "Link", group: "Link")

  prop(:new_tab, :boolean,
    label: "Open in a new tab",
    default: false,
    group: "Link",
    show_if: {:url, :present}
  )

  prop(:width, :select,
    label: "Width",
    options: [{"Original", "auto"}, {"Full", "full"}],
    default: "auto",
    control: :segmented,
    group: "Look"
  )

  prop(:align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "center",
    control: :segmented,
    group: "Look"
  )

  prop(:aspect, :select,
    label: "Aspect ratio",
    options: [
      {"Original", "auto"},
      {"1:1", "square"},
      {"16:9", "video"},
      {"4:3", "4/3"},
      {"3:4", "3/4"}
    ],
    default: "auto",
    group: "Look"
  )

  prop(:fit, :select,
    label: "Fit",
    options: [{"Cover", "cover"}, {"Contain", "contain"}],
    default: "cover",
    control: :segmented,
    group: "Look",
    show_if: {:aspect, ["square", "video", "4/3", "3/4"]}
  )

  prop(:rounded, :select,
    label: "Corners",
    options: Options.radii(),
    default: "box",
    group: "Look"
  )

  prop(:mask, :select,
    label: "Mask",
    options: [
      {"None", "none"},
      {"Squircle", "squircle"},
      {"Circle", "circle"},
      {"Heart", "heart"},
      {"Hexagon", "hexagon"},
      {"Decagon", "decagon"},
      {"Pentagon", "pentagon"},
      {"Diamond", "diamond"},
      {"Star", "star"},
      {"Triangle", "triangle"}
    ],
    default: "none",
    group: "Look"
  )

  prop(:shadow, :select,
    label: "Shadow",
    options: Options.shadows(),
    default: "none",
    group: "Look"
  )

  prop(:lazy, :boolean, label: "Load lazily", default: true, group: "Look")

  @align %{"left" => "mr-auto", "center" => "mx-auto", "right" => "ml-auto"}
  @aspects %{
    "auto" => nil,
    "square" => "aspect-square",
    "video" => "aspect-video",
    "4/3" => "aspect-[4/3]",
    "3/4" => "aspect-[3/4]"
  }
  @fits %{"cover" => "object-cover", "contain" => "object-contain"}
  @rounded %{
    "none" => "rounded-none",
    "sm" => "rounded-sm",
    "md" => "rounded-md",
    "lg" => "rounded-lg",
    "xl" => "rounded-xl",
    "2xl" => "rounded-2xl",
    "box" => "rounded-box",
    "full" => "rounded-full"
  }
  @masks %{
    "none" => nil,
    "squircle" => "mask mask-squircle",
    "circle" => "mask mask-circle",
    "heart" => "mask mask-heart",
    "hexagon" => "mask mask-hexagon",
    "decagon" => "mask mask-decagon",
    "pentagon" => "mask mask-pentagon",
    "diamond" => "mask mask-diamond",
    "star" => "mask mask-star-2",
    "triangle" => "mask mask-triangle"
  }
  @shadows %{
    "none" => nil,
    "sm" => "shadow-sm",
    "md" => "shadow-md",
    "lg" => "shadow-lg",
    "xl" => "shadow-xl",
    "2xl" => "shadow-2xl"
  }

  def render(assigns) do
    ~H"""
    <figure {root(assigns, class: ["flex max-w-full flex-col gap-2", if(@width == "full", do: "w-full", else: "w-fit"), Map.get(aligns(), @align)])}>
      <%= cond do %>
        <% @src == "" and editor?(assigns) -> %>
          <div class="exr-image-placeholder">
            <.heroicon name="photo" class="size-8" />
            <span>{t("Choose an image")}</span>
          </div>
        <% @src == "" -> %>
        <% @url != "" -> %>
          <a {link_attrs(@url, @new_tab)}><img {img_attrs(assigns)} /></a>
        <% true -> %>
          <img {img_attrs(assigns)} />
      <% end %>
      <figcaption
        :if={@caption != ""}
        class="text-center text-sm opacity-70"
        {inline(assigns, :caption)}
      >
        {@caption}
      </figcaption>
    </figure>
    """
  end

  defp img_attrs(assigns) do
    [
      {"src", assigns.src},
      {"alt", assigns.alt},
      {"loading", if(assigns.lazy, do: "lazy", else: "eager")},
      {"decoding", "async"},
      {"class",
       class_list([
         "block h-auto max-w-full",
         assigns.width == "full" && "w-full",
         Map.get(@aspects, assigns.aspect),
         assigns.aspect != "auto" && Map.get(@fits, assigns.fit),
         assigns.mask == "none" && Map.get(@rounded, assigns.rounded),
         Map.get(@masks, assigns.mask),
         Map.get(@shadows, assigns.shadow)
       ])}
    ]
  end

  defp aligns, do: @align
end
