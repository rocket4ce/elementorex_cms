# Example

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## The online shop (dynamic content)

The shop shows how pages made in the editor use the records of the app:

1. The products were scaffolded with
   `mix phx.gen.live Catalog Product products name:string slug:string:unique description:text price:decimal image_url:string category:string stock:integer featured:boolean published:boolean`
   (CRUD at [`/products`](http://localhost:4000/products)).
2. `mix elementorex.gen.source Catalog.Product --path "/shop/:slug"` made
   `ExampleWeb.Sources.Products`, registered in `config/config.exs`
   (`sources:`). Its fields are read from the schema; only published
   products reach the site.
3. [`/p/shop`](http://localhost:4000/p/shop) is a page made of *Loop grid*
   blocks whose cards are bound to the fields of each product; the grid of
   every product has filters (search, the categories of the table, price
   ranges written as a block of this app with `mix elementorex.gen.filter
   PriceRanges`, *In stock* written in the source, the order) and numbered
   pages (`?catalog[page]=2`), and
   [`/p/catalog`](http://localhost:4000/p/catalog) loads them with infinite
   scroll. `PageLive.Show` passes its `params` to the document for that.
4. The page *Product page* in `/admin/pages` (kind *Template of Products*) is
   the template of [`/shop/:slug`](http://localhost:4000/shop/leather-boots),
   rendered with each product by `ExampleWeb.ShopLive.Product`. The editor's
   top bar picks the product shown on the canvas.

`mix run priv/repo/seeds.exs` creates the products and the pages of the shop (and
rebuilds the documents of the seeded pages).

Ready to run in production? Please [check our deployment guides](https://phoenix.hexdocs.pm/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://phoenix.hexdocs.pm/overview.html
* Docs: https://phoenix.hexdocs.pm
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
