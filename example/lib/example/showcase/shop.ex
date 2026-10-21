defmodule Example.Showcase.Shop do
  @moduledoc """
  The documents of the shop demo, built in code with `ElementorexCms.Builder`
  and dynamic content (the products of `ExampleWeb.Sources.Products`):

    * `page/0` - the shop (`/p/shop`): featured products and every product,
      in loop grids whose cards are bound to the fields of each product; the
      grid of every product has filters (search, categories, price ranges, in
      stock, order) and numbered pages (`?catalog[page]=2`)
    * `catalog/0` - every product with infinite scroll (`/p/catalog`)
    * `product_template/0` - the page of each product (`/shop/:slug`): its
      photo, name, price, stock and description, a WhatsApp button that asks
      about it and the other products of its category. Display conditions
      show *Featured* or *Sold out* and hide *Buy now* without stock

  Used by `priv/repo/seeds.exs`; both can be edited in `/admin/pages`.
  """

  import ElementorexCms.Builder

  @price [field: "price", before: "$", format: "number", decimals: 0]

  @doc "The shop: featured products and every product."
  def page do
    doc([
      block(
        "hero",
        %{
          image: "https://picsum.photos/seed/exr-shop/1600/900",
          overlay: true,
          min_height: "sm",
          content_width: "3xl"
        },
        children: [
          block("badge", %{text: "Example", color: "accent"},
            dynamic: %{text: [field: "site_name", from: "site", after: " · shop"]}
          ),
          block("heading", %{text: "Clothes made to last", level: "h1", size: "5xl"}),
          block("text", %{
            text:
              "<p>Every card below is the same card, designed once in the editor and " <>
                "repeated for each product of the database.</p>",
            size: "lg"
          }),
          block("button", %{label: "See the favorites", url: "#featured", icon: "arrow-down"})
        ]
      ),
      section(
        [
          block("heading", %{text: "Our favorites", level: "h2", size: "4xl"}),
          loop("products", [card()], %{
            limit: 3,
            columns: "3",
            filters: [%{"field" => "featured", "op" => "eq", "value" => "true"}]
          })
        ],
        %{gap: "6"},
        attrs: %{"id" => "featured", "label" => "Featured products"}
      ),
      section(
        [
          block("heading", %{text: "Every product", level: "h2", size: "4xl"}),
          filters(),
          # Its CSS id names its state in the URL: ?catalog[page]=2
          loop(
            "products",
            [card()],
            %{
              limit: 4,
              columns: "4",
              columns_tablet: "2",
              columns_mobile: "1",
              order_by: "name",
              pagination: "numbers_prev_next",
              empty_text: "No products yet: add them at /products."
            },
            id: "shopCatalog",
            attrs: %{"id" => "catalog"}
          )
        ],
        %{gap: "6"},
        attrs: %{"label" => "Every product"}
      )
    ])
  end

  @doc "Every product, three at a time: more load as the visitor scrolls."
  def catalog do
    doc([
      section(
        [
          block("badge", %{text: "Infinite scroll", color: "accent", icon: "arrows-up-down"}),
          block("heading", %{text: "The whole catalog", level: "h1", size: "5xl"}),
          block("text", %{
            text:
              "<p>Keep scrolling: the next products load on their own. Without " <>
                "JavaScript, a button links to the next page.</p>",
            size: "lg",
            muted: true
          }),
          loop(
            "products",
            [card()],
            %{
              limit: 3,
              columns: "3",
              columns_tablet: "2",
              order_by: "price",
              order: "desc",
              pagination: "infinite"
            },
            attrs: %{"id" => "products"}
          )
        ],
        %{gap: "6"},
        attrs: %{"label" => "Catalog"}
      )
    ])
  end

  @doc "The template of the page of each product."
  def product_template do
    doc([
      section(
        [
          columns(
            [
              [
                block("image", %{width: "full", aspect: "square", rounded: "box", shadow: "md"},
                  dynamic: %{src: "image_url", alt: "name"}
                )
              ],
              [
                container(
                  [
                    block("badge", %{text: "Category", color: "accent"},
                      dynamic: %{text: "category"}
                    ),
                    block("badge", %{text: "Featured", color: "warning", icon: "star"},
                      attrs: %{"condition" => condition("featured", "eq", "true")}
                    )
                  ],
                  %{direction: "row", gap: "2", stack_on_mobile: false}
                ),
                block("heading", %{text: "Product name", level: "h1", size: "4xl"},
                  dynamic: %{text: "name"}
                ),
                block("heading", %{text: "$0", level: "p", size: "3xl", weight: "black"},
                  dynamic: %{text: @price}
                ),
                block("badge", %{text: "In stock", variant: "outline", color: "success"},
                  dynamic: %{text: [field: "stock", after: " in stock"]},
                  attrs: %{"condition" => condition("stock", "gt", "0")}
                ),
                block("badge", %{text: "Sold out", color: "error"},
                  attrs: %{"condition" => condition("stock", "lte", "0")}
                ),
                block("text", %{text: "<p>Description of the product.</p>"},
                  dynamic: %{text: "description"}
                ),
                block(
                  "button",
                  %{label: "Buy now", size: "lg", icon: "shopping-cart", wide: true},
                  attrs: %{"condition" => condition("stock", "gt", "0")}
                ),
                block("whatsapp", %{label: "Ask about this product", size: "sm"},
                  dynamic: %{
                    message: [field: "name", before: "Hi! I would like to know more about "]
                  }
                )
              ]
            ],
            %{columns: "2", columns_tablet: "2", gap: "8", align: "start"}
          )
        ],
        %{},
        attrs: %{"label" => "Product"}
      ),
      section(
        [
          block("heading", %{text: "More from this category", level: "h2", size: "2xl"}),
          loop("products", [card()], %{
            limit: 4,
            columns: "4",
            columns_tablet: "2",
            exclude_current: true,
            filters: [%{"field" => "category", "op" => "same", "value" => ""}],
            empty_text: ""
          })
        ],
        %{},
        attrs: %{"label" => "Related products"}
      )
    ])
  end

  # The visitors' filters of the catalog grid: search, categories (the values
  # of the column), price ranges (a filter block of this app), in stock (a
  # filter of the source with logic of its own) and the order.
  defp filters do
    block(
      "filters",
      %{target: "shopCatalog", reset_label: "Clear filters"},
      children: [
        block("filter_search", %{placeholder: "Search products…"}),
        block("filter_choice", %{field: "category", label: "Category", control: "buttons"}),
        block("price_ranges", %{field: "price", label: "Price"}),
        block("filter_toggle", %{field: "in_stock", label: "In stock"}),
        block("filter_sort", %{
          options: [
            %{"label" => "Name", "field" => "name", "direction" => "asc"},
            %{"label" => "Price: low to high", "field" => "price", "direction" => "asc"},
            %{"label" => "Price: high to low", "field" => "price", "direction" => "desc"},
            %{"label" => "Newest", "field" => "inserted_at", "direction" => "desc"}
          ]
        })
      ],
      attrs: %{"label" => "Filters of the catalog"}
    )
  end

  # Shown only for the products that match (the Advanced tab of the editor).
  defp condition(field, op, value), do: %{"field" => field, "op" => op, "value" => value}

  # The card of one product, linked to its page.
  defp card do
    block(
      "card",
      %{
        title: "Product",
        text: "<p>Description</p>",
        badge: "$0",
        button_label: "See product",
        shadow: "md"
      },
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
