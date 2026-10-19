defmodule ElementorexCms.Blocks.Carousel do
  @moduledoc "daisyUI carousel of images with scroll snapping (no JavaScript)."

  use ElementorexCms.Block,
    type: "carousel",
    label: "Carousel",
    icon: "film",
    category: :media,
    description: "Images that slide",
    keywords: ~w(slider gallery slides galeria carrusel)

  prop(:items, :list,
    label: "Slides",
    item_label: :caption,
    max_items: 20,
    default: [%{"caption" => "Slide 1"}, %{"caption" => "Slide 2"}, %{"caption" => "Slide 3"}],
    fields: [
      {:image, :image, label: "Image"},
      {:alt, :string, label: "Alternative text"},
      {:caption, :string, label: "Caption"},
      {:url, :url, label: "Link"}
    ]
  )

  prop(:per_view, :select,
    label: "Slides per view",
    options: [{"1", "1"}, {"2", "2"}, {"3", "3"}, {"Auto", "auto"}],
    default: "1",
    control: :segmented
  )

  prop(:height, :select,
    label: "Height",
    options: [{"S", "64"}, {"M", "80"}, {"L", "96"}, {"XL", "128"}],
    default: "80",
    control: :segmented
  )

  prop(:snap, :select,
    label: "Snap",
    options: [{"Start", "start"}, {"Center", "center"}, {"End", "end"}],
    default: "start",
    control: :segmented
  )

  prop(:rounded, :boolean, label: "Rounded corners", default: true)

  @widths %{
    "1" => "w-full",
    "2" => "w-1/2 max-md:w-full",
    "3" => "w-1/3 max-md:w-4/5",
    "auto" => nil
  }
  @heights %{"64" => "h-64", "80" => "h-80", "96" => "h-96", "128" => "h-[32rem]"}
  @snaps %{"start" => "carousel-start", "center" => "carousel-center", "end" => "carousel-end"}

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["carousel w-full gap-3", Map.get(snaps(), @snap), @rounded && "rounded-box"])}>
      <div
        :for={item <- @items}
        class={["carousel-item relative", Map.get(widths(), @per_view), Map.get(heights(), @height)]}
      >
        <%= cond do %>
          <% item["image"] != "" and item["url"] != "" -> %>
            <a class="block size-full" {link_attrs(item["url"])}>
              <img
                src={item["image"]}
                alt={item["alt"]}
                loading="lazy"
                class={["size-full object-cover", @rounded && "rounded-box"]}
              />
            </a>
          <% item["image"] != "" -> %>
            <img
              src={item["image"]}
              alt={item["alt"]}
              loading="lazy"
              class={["size-full object-cover", @rounded && "rounded-box"]}
            />
          <% true -> %>
            <div class={[
              "grid size-full place-items-center bg-base-200 text-base-content/50",
              @rounded && "rounded-box"
            ]}>
              <.heroicon name="photo" class="size-10" />
            </div>
        <% end %>
        <span
          :if={item["caption"] != ""}
          class="absolute bottom-3 left-3 rounded-full bg-base-100/90 px-3 py-1 text-sm font-medium text-base-content"
        >
          {item["caption"]}
        </span>
      </div>
    </div>
    """
  end

  defp widths, do: @widths
  defp heights, do: @heights
  defp snaps, do: @snaps
end
