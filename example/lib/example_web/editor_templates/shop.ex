defmodule ExampleWeb.EditorTemplates.Shop do
  @moduledoc """
  Sections of the shop for the visual editor (ElementorexCms *Templates*
  panel), bound to the fields of the products (`ExampleWeb.Sources.Products`).

  `source: "products"` keeps them out of the panel when that source is not
  configured. The panel also offers templates ElementorexCms makes on its own
  from the fields of each source (grid, list and the page of one product).
  """

  @behaviour ElementorexCms.Templates

  import ElementorexCms.Builder

  @price [field: "price", before: "$", format: "number", decimals: 0]

  @impl true
  def templates do
    [
      %{
        key: "shop_featured",
        label: "Featured products",
        description: "The featured products in three columns",
        icon: "star",
        source: "products",
        nodes: fn ->
          [
            section([
              block("badge", %{text: "Featured", color: "accent"}),
              block("heading", %{text: "Our favorites", level: "h2", size: "4xl"}),
              loop("products", [product_card()], %{
                limit: 3,
                columns: "3",
                filters: [%{"field" => "featured", "op" => "eq", "value" => "true"}]
              })
            ])
          ]
        end
      },
      %{
        key: "shop_category",
        label: "Products of a category",
        description: "The products of one category, cheapest first",
        icon: "tag",
        source: "products",
        nodes: fn ->
          [
            section([
              block("heading", %{text: "Shoes", level: "h2"}),
              loop("products", [product_card()], %{
                limit: 8,
                columns: "4",
                columns_tablet: "2",
                order_by: "price",
                filters: [%{"field" => "category", "op" => "eq", "value" => "Shoes"}]
              })
            ])
          ]
        end
      },
      %{
        key: "shop_product_hero",
        label: "Product hero",
        description: "The photo of the product behind its name and price",
        icon: "photo",
        source: "products",
        nodes: fn ->
          [
            block("hero", %{overlay: true, min_height: "md"},
              dynamic: %{image: "image_url"},
              children: [
                block("badge", %{text: "Category", color: "accent"},
                  dynamic: %{text: "category"}
                ),
                block("heading", %{text: "Product name", level: "h1", size: "5xl"},
                  dynamic: %{text: "name"}
                ),
                block("heading", %{text: "$0", level: "p", size: "2xl"},
                  dynamic: %{text: @price}
                ),
                block("button", %{label: "Buy now", size: "lg", icon: "shopping-cart"})
              ]
            )
          ]
        end
      }
    ]
  end

  # A card of one product: photo, name, price, the start of its description
  # and a link to its page.
  defp product_card do
    block(
      "card",
      %{title: "Product", text: "<p>Description</p>", badge: "$0", button_label: "See product"},
      dynamic: %{
        title: "name",
        image: "image_url",
        text: [field: "description", format: "excerpt", length: 90],
        badge: @price,
        button_url: "@url"
      }
    )
  end
end
