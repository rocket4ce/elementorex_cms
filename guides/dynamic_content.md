# Dynamic content

Pages made in the editor can show the records of your app: the products of a
shop, the posts of a blog, the events of an agenda. You design a card once and
the editor repeats it for every product; you design the page of a product once
and every product gets it.

Three pieces make it work:

- **Sources** (`ElementorexCms.Source`): the collections the editor can read.
  An Ecto schema is enough: its fields are read from the schema.
- **Bindings** (`ElementorexCms.Dynamic`): any prop of a block (a heading's
  text, an image, a button's link) can show a field of the current item instead
  of its own value, with text before and after, a fallback and a format.
- **The *Loop grid* block** (`ElementorexCms.Blocks.Loop`): repeats its content
  for the items of a source, with a limit, an order and filters.

A document rendered with a record (`record={@product}`) is a **template** of
that source: the page of each product.

## An online store, step by step

### 1. The products

Any Ecto schema works, made with a generator or a migration of your own:

```bash
mix phx.gen.live Catalog Product products name:string slug:string:unique \
  description:text price:decimal image_url:string category:string \
  stock:integer featured:boolean published:boolean
mix ecto.migrate
```

### 2. Make them a source

The quickest way is the schema itself in the config:

```elixir
config :elementorex_cms, sources: [MyApp.Catalog.Product]
```

To choose the fields, give each product a page and keep drafts off your site,
generate a module:

```bash
mix elementorex.gen.source Catalog.Product --path "/products/:slug"
```

```elixir
defmodule MyAppWeb.Sources.Products do
  use ElementorexCms.Source.Ecto,
    schema: MyApp.Catalog.Product,
    repo: MyApp.Repo,
    label: "Products",
    icon: "shopping-bag",
    path: "/products/:slug",
    fields: [price: [defaults: %{"before" => "$", "format" => "number", "decimals" => 0}]]

  # Your pages only get published products; the editor shows them all.
  @impl true
  def scope(query, %{mode: :public}), do: where(query, [r], r.published)
  def scope(query, _context), do: query
end
```

```elixir
config :elementorex_cms, sources: [MyAppWeb.Sources.Products]
```

The fields come from the schema every time they are needed: a field added to
the schema later (a migration plus its `field`) shows up in the editor on its
own. Types come from Ecto and,
for strings, from the name (`image_url` is an image, `description` has
paragraphs, `website` is a link). Fields whose name suggests a secret
(`password_hash`, `api_token`…) and `redact: true` fields are never offered.

### 3. A shop page

In the editor, *Dynamic* → *Loop grid*. It starts with the first source; drop
a *Card* inside and select it: every prop has a database button (◎). Click it
next to *Title* and choose *Name*; next to *Image*, *Image URL*; next to
*Button link*, *Link to the item*. The canvas shows your products.

Or start from the *Templates* panel: *Products: grid* and *Products: list* are
made from the fields of the source.

The loop's *Content* tab sets the query (how many, from which, the order and
filters such as *Category · Is · Shoes* or *Featured · Is · true*) and the
layout (columns per device, gap, the text for no items).

### 4. The page of each product

Make a document that is the template of the source: pass `source` to the
editor, and the props can be bound to the fields of one product. The top bar
picks the product shown on the canvas.

```heex
<.live_component
  module={ElementorexCms.Editor}
  id="template-editor"
  document={@template.body}
  source="products"
  ...
/>
```

*Templates* → *Page of one item of Products* gives a picture, title, price,
description and a list of related products (a loop with *Same as the current
item* on a field and *Leave out the current item*).

Render it with the product:

```elixir
live "/products/:slug", ProductLive.Page, :show
```

```heex
<ElementorexCms.Components.document document={@template.body} record={@product} />
```

The source is found from the record's schema (pass `source="products"` when
it is not an Ecto source).

## Bindings

A node keeps its bindings next to its props:

```elixir
%{
  "type" => "heading",
  "props" => %{"text" => "Product name"},
  "dynamic" => %{"text" => %{"field" => "price", "before" => "$", "format" => "number"}}
}
```

| Setting | Meaning |
| --- | --- |
| `field` | key of a field of the source (`category.name` with `preload:`), or `@url` (the page of the item) |
| `from` | `item` (default) or `site`: a top-level value of the `data` passed to the editor and the page |
| `before`, `after` | text around the value |
| `fallback` | when the item has no value |
| `format` | `number` (separators of the language, `decimals`), `date`, `datetime`, `time`, `excerpt` (`length` characters), `upper`, `lower` |

Without a current item (a document rendered with no record, or the canvas of a
loop without items) a bound prop shows its own value, so it works as a
placeholder. With an item, the field's value replaces it even when empty (then
the `fallback` is used).

Bound values are cast by the prop like any other value: text is escaped, rich
text sanitized, URLs and images go through the allow-list. A binding to a
field the source does not offer reads nothing, so a document edited by hand
cannot reach other columns.

In code, `ElementorexCms.Builder` takes `dynamic:` and `loop/4`:

```elixir
loop("products", [
  block("card", %{title: "Product"},
    dynamic: %{
      title: "name",
      image: "image_url",
      badge: [field: "price", before: "$", format: "number"],
      button_url: "@url"
    }
  )
], %{limit: 6, columns: "3", order_by: "price"})
```

## Pages and infinite scroll

The loop's *Pagination* (in its *Content* tab) splits the items in pages of
*Items* each:

| Pagination | On your site |
| --- | --- |
| *Numbers* | `1 2 3 … 9`, the current page highlighted |
| *Previous / Next* | two links (no counting needed) |
| *Numbers and Previous / Next* | both |
| *Load more button* | a button that adds the next page below the items |
| *Infinite scroll* | the next page is added when the visitor gets to the end of the grid |

The state of each loop is in the query string, under its key: the loop's CSS
ID (*Advanced* tab; without one, its node id). Its page is `?catalog[page]=2`.
Links keep the visitor's filters and the state of the other loops of the page,
and land on the loop (`#catalog`). *Page limit* caps how many pages there
are.

The loop reads its page from the `params` of the document, so pass them:

```elixir
# a LiveView
def mount(%{"slug" => slug} = params, _session, socket) do
  {:ok, socket |> assign(:page, Pages.get_published_page!(slug)) |> assign(:params, params)}
end
```

```heex
<ElementorexCms.Components.document document={@page.body} params={@params} />
```

In a controller, `params={@conn.params}`.

*Load more* and *Infinite scroll* need the runtime of the site (the
`ElementorexRuntime` hook on the element that holds the document, or
`initElementorex()` from `elementorex_cms/runtime`): it fetches the next page
like any page of your site, takes the new items of the loop from it and adds
them, without changing the address. Without JavaScript, the button is a link
to the next page. After each load the loop sends `elementorex:loaded` (with
the new items in `detail.items`).

Numbered pages need to count the items: Ecto sources do it with a `count`
query; your own sources implement `c:ElementorexCms.Source.count/2`
(`ElementorexCms.Source.Query.count/4` counts a list). Without it, *Numbers*
shows *Previous* and *Next*.

On the canvas the pagination is always shown, for page 1, so it can be styled.

## Search and filters for visitors

The *Filters* block is a form for a loop grid of the page: drop it next to
the grid (it filters the first loop grid of the page, or the one you pick in
*Loop grid*), then drop its fields inside, and arrange them like any other
blocks:

| Block | What visitors do |
| --- | --- |
| *Search box* | look for a text in the searchable fields of the source |
| *Choice filter* | pick a value of a field: a dropdown, options, checkboxes (several) or buttons; the options are the values the records have (with how many, if you want) or written by you |
| *Range filter* | a minimum and a maximum of a number or a date (price, date) |
| *Toggle filter* | keep only the items whose field has a value (*Only featured*) |
| *Sort* | the order, among the options you write (*Price: low to high*…) |

*Templates* → *%{collection}: grid with filters* builds all of them from the
fields of the source, with the grid.

The form applies on every change (or with a button) and can show a button to
clear the filters. Its params go to the loop's key:

    ?catalog[q]=boots&catalog[category][]=Shoes&catalog[price][min]=20000&catalog[sort]=-price

With the runtime of the site only the loop grid is replaced (the address
changes, so a filtered page can be shared and reloaded); without JavaScript
it is a plain form that reloads the page. The pages of the loop keep the
filters, and a new filter starts again at page 1.

Only fields the source marks `filterable` (and `sortable`, to order) can be
used, values are cast to their type and empty ones ignored: the query string
cannot reach other columns. The scope of the source and the loop's own
filters still apply.

### Filters of your own

**Logic in the source.** What a field cannot express (*In stock* is
`stock > 0`, *On sale* compares two prices) is a filter of the source: it is
offered next to the fields, in loops and in the visitors' forms.

```elixir
use ElementorexCms.Source.Ecto,
  schema: MyApp.Catalog.Product,
  filters: [in_stock: [label: "In stock", type: :boolean]]

@impl true
def filter(query, "in_stock", "true", _context), do: where(query, [p], p.stock > 0)
def filter(query, _name, _value, _context), do: query
```

**Your own field blocks.** A filter block is a block with `parents:
["filters"]` whose inputs are named after the loop's params:

```bash
mix elementorex.gen.filter PriceRanges
```

```heex
<input type="radio" name={filter_name(assigns, @field)} value="20000..50000"
       checked={filter_checked?(assigns, @field, "20000..50000")} />
```

`filter_name(assigns, "q")`, `filter_name(assigns, [@field, ""])` (several
values) and `filter_name(assigns, [@field, "min"])` give the names;
`filter_value/2`, `filter_checked?/3` and `filter_options/2` (the values of a
field) the rest. Values like `20000..50000` (or `..20000`) are ranges of
number and date fields. See `ElementorexCms.Filters`.

Your own sources get the search in `query.search` and several values with
the `"in"` operator; `ElementorexCms.Source.Query.run/4` handles both for a
list, and `c:ElementorexCms.Source.values/2` gives the options of a field.
Loops inside other loops have no pages.

## Display conditions

Any block inside a loop or a template of a source can be shown only for some
items: *Advanced* → *Display condition*, a field, an operator and a value. A
*Sold out* badge with *Stock · At most · 0*, the *Buy now* button with
*Stock · Greater than · 0*, a *Featured* ribbon with *Featured · Is · true*.

On your site the block is left out for the other items; on the canvas it is
dimmed, so it can still be selected (pick another item in the top bar to see
it). The condition is an attribute of the node:

```elixir
block("badge", %{text: "Sold out", color: "error"},
  attrs: %{"condition" => %{"field" => "stock", "op" => "lte", "value" => "0"}}
)
```

The operators are those of the loop filters: `eq`, `neq`, `contains`, `gt`,
`gte`, `lt`, `lte`, `set` and `unset`. Without a current item there is nothing
to check, and the block is shown.

## Templates for the *Templates* panel

Templates of your app (`ElementorexCms.Templates`) can use loops and bindings.
Give them a `:source` and they only show up when that source exists:

```elixir
%{
  key: "featured_products",
  label: "Featured products",
  icon: "star",
  source: "products",
  nodes: fn ->
    [
      section([
        block("heading", %{text: "Featured"}),
        loop("products", [block("card", %{}, dynamic: %{title: "name"})], %{
          limit: 3,
          filters: [%{"field" => "featured", "op" => "eq", "value" => "true"}]
        })
      ])
    ]
  end
}
```

## Sources that are not Ecto

Implement `ElementorexCms.Source`: `key/0`, `label/0`, `fields/0` and
`list/2` (plus, optionally, `get/2`, `value/2`, `url/1`, `id/1`, `title/1` and
`icon/0`). `ElementorexCms.Source.Query.run/4` filters, orders and pages a
list kept in memory.

```elixir
defmodule MyAppWeb.Sources.Team do
  @behaviour ElementorexCms.Source

  alias ElementorexCms.Source.{Field, Query}

  @impl true
  def key, do: "team"

  @impl true
  def label, do: "Team"

  @impl true
  def fields do
    [Field.new(:name, role: :title), Field.new(:role), Field.new(:photo, type: :image)]
  end

  @impl true
  def list(query, _context) do
    Query.run(query, MyApp.Team.members(), &Map.get(&1, String.to_existing_atom(&2)))
  end
end
```

`list/2` gets the query of the loop (`ElementorexCms.Source.Query`: limit,
offset, order, filters and ids to leave out) and a context with the `mode`
(`:public` or `:editor`) and the `data` the host passed — the current user, a
tenant — so a source can scope its records.

## Limits

- A loop shows at most 100 items (per page); a loop inside another shows at
  most 24 and has no pages, and loops go two levels deep.
- On the canvas the first item of a loop is the one you edit; the others follow
  it. A source that fails shows its error on the canvas instead of taking the
  editor down.
