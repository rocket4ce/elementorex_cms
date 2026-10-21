# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# It is idempotent: pages and products are matched by slug and updated.

alias Example.Catalog.Product
alias Example.Pages
alias Example.Pages.Page
alias Example.Repo

# The products of the shop (dynamic content, see ExampleWeb.Sources.Products).
# "Sunglasses" is a draft: the editor shows it, the shop does not.
products = [
  {"Trail running shoes", "Shoes", 64_990, 18, true,
   "Grippy soles and a breathable mesh for long days on the mountain.\n\nWeighs 280 g."},
  {"Canvas sneakers", "Shoes", 39_990, 40, false,
   "The classic low-top in organic canvas, with a natural rubber sole."},
  {"Leather boots", "Shoes", 89_990, 7, true,
   "Full-grain leather, stitched by hand. They get better with every year."},
  {"Linen shirt", "Shirts", 29_990, 25, false,
   "Washed linen that stays cool in summer. Relaxed fit, mother-of-pearl buttons."},
  {"Organic cotton tee", "Shirts", 14_990, 120, true,
   "Heavyweight jersey of organic cotton, cut and sewn in Santiago."},
  {"Denim jacket", "Jackets", 69_990, 12, false,
   "Rigid selvedge denim that fades with you. Two chest pockets."},
  {"Rain jacket", "Jackets", 54_990, 0, false,
   "Waterproof and packable into its own pocket, for the days that change their mind."},
  {"Wool beanie", "Accessories", 12_990, 60, false, "Merino wool, ribbed knit, one size."},
  {"Leather backpack", "Accessories", 79_990, 9, false,
   "Fits a 15\" laptop and a day of errands. Vegetable-tanned leather."},
  {"Sunglasses", "Accessories", 24_990, 30, false,
   "Polarized lenses in a recycled acetate frame."}
]

for {name, category, price, stock, featured, description} <- products do
  slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")

  attrs = %{
    name: name,
    slug: slug,
    category: category,
    price: price,
    stock: stock,
    featured: featured,
    published: name != "Sunglasses",
    description: description,
    image_url: "https://picsum.photos/seed/exr-#{slug}/800/800"
  }

  (Repo.get_by(Product, slug: slug) || %Product{})
  |> Product.changeset(attrs)
  |> Repo.insert_or_update!()
end

pages = [
  %{
    title: "Every block",
    slug: "every-block",
    status: :published,
    body: Example.Showcase.all_blocks()
  },
  %{
    title: "Templates",
    slug: "templates",
    status: :published,
    body: Example.Showcase.templates()
  },
  %{
    title: "Shop",
    slug: "shop",
    status: :published,
    body: Example.Showcase.Shop.page()
  },
  %{
    title: "Catalog",
    slug: "catalog",
    status: :published,
    body: Example.Showcase.Shop.catalog()
  },
  # The template of the products: /shop/:slug renders it with each product
  %{
    title: "Product page",
    slug: "product-page",
    status: :published,
    source: "products",
    body: Example.Showcase.Shop.product_template()
  },
  %{
    title: "Empty draft",
    slug: "draft",
    status: :draft,
    body: ElementorexCms.Document.new()
  }
]

for %{body: body} = attrs <- pages do
  page =
    case Repo.get_by(Page, slug: attrs.slug) do
      nil -> %Page{}
      page -> page
    end

  {:ok, page} = page |> Page.changeset(Map.delete(attrs, :body)) |> Repo.insert_or_update()
  {:ok, _page} = Pages.update_page_body(page, body)
end
