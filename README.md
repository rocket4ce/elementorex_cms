# ElementorexCms

**A visual, drag & drop content builder for Phoenix LiveView**, in the spirit of
WordPress' Elementor: build pages, modals or landing sections out of blocks,
with a live canvas that renders your site's own CSS.

- **Editor** (`ElementorexCms.Editor`, a LiveComponent): blocks palette with
  search, **DOM tree**, a **canvas iframe** with your stylesheets (desktop,
  tablet and mobile widths trigger your real media queries), an **inspector**
  with *Content*, *Style* and *Advanced* tabs, **inline text editing** with a
  formatting bar, **drag and drop** between palette, canvas and tree, an
  **HTML / CSS / JSON** drawer, undo/redo with history, templates, keyboard
  shortcuts, image uploads and a media library.
- **41 blocks** built with **daisyUI 5** and **Heroicons** (inline SVG, so any
  icon picked at runtime works): sections, flex containers, responsive grids,
  hero, headings, rich text, buttons, icon boxes, lists, alerts, badges, cards,
  stats, steps, countdown, accordion, tabs, timeline, rating, progress, avatar,
  chat, testimonials, carousel, video, mockups, HTML, loop grid, filters for
  visitors (search, choices, ranges, toggles, sort)…
- **Charts and data**: bar (vertical or horizontal, grouped or stacked, with a
  target line), line and area, donut and pie charts, tables with bar columns
  and key figures with trend and tone. They take their data as delimited text
  any app can generate, and are drawn with SVG and inline styles, without a
  CSS framework.
- **Dynamic content**: your Ecto schemas (from `mix phx.gen.live` or your own
  migrations) become collections the editor can list in a *Loop grid*; any prop
  of any block can show a field of the current item (with format, prefix and
  fallback), and a document rendered with a record is the template of its page.
- **Your own blocks** with a tiny DSL (`use ElementorexCms.Block` + `prop`), or
  `mix elementorex.gen.block`.
- **Documents are data**: a JSON tree you keep in a `jsonb` column
  (`ElementorexCms.Ecto.Document`), rendered on the server by
  `<ElementorexCms.Components.document>`.
- **Safe by design**: props are cast and sanitized every time a document is
  rendered, styles go through a per-property grammar, hand-written CSS is nested
  in its element's scope, and HTML is rebuilt from an allow-list. A stored
  document cannot inject script, markup or global CSS.
- **Generators**: a whole CMS (`mix elementorex.gen.cms`), blocks, templates,
  and `mix elementorex.install` to check the setup.
- The interface in English (default), Spanish, Portuguese, German, French,
  Italian and Japanese (`ElementorexCms.I18n`); `mix elementorex.gen.locale`
  translates your blocks or adds a language.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:elementorex_cms, "~> 0.3"}
  ]
end
```

Then `mix elementorex.install` checks the JavaScript and CSS steps below and
prints what is missing.

### 1. JavaScript

The JavaScript ships as plain ES modules inside the Hex package; Phoenix's
default esbuild configuration already resolves packages from `deps/`
(`NODE_PATH`). Register the hooks:

```js
// assets/js/app.js (or your admin entry point)
import {hooks as Elementorex} from "elementorex_cms"

const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Elementorex}
})
```

`hooks` has `ElementorexEditor` (the editor) and `ElementorexRuntime` (keeps
countdowns ticking on your site, changes the page of loop grids in place,
loads their next pages with *Load more* or infinite scroll and applies the
visitors' filters in place). Pages rendered by controllers can call
`initElementorex()` from `"elementorex_cms/runtime"` instead.

### 2. CSS

Blocks use daisyUI 5 and Tailwind classes, so the stylesheet of the pages that
show documents has to scan them:

```css
/* assets/css/app.css */
@import "tailwindcss" source(none);
@source "../../deps/elementorex_cms/lib";
@plugin "../vendor/daisyui";
```

The editor's own stylesheet is plain CSS included by the component; you don't
need to import anything for it (set `inline_css={false}` and import
`priv/static/elementorex.css` if you prefer).

### 3. Content-Security-Policy

The canvas is an `<iframe srcdoc>`: it works with `frame-src 'self'`. Video
embeds on your site need the players in `frame-src`
(`https://www.youtube-nocookie.com https://player.vimeo.com`); on the canvas
they are previews.

## Quick start

Store documents:

```elixir
schema "pages" do
  field :title, :string
  field :body, ElementorexCms.Ecto.Document, default: ElementorexCms.Document.new()
end
```

Edit them:

```heex
<.live_component
  module={ElementorexCms.Editor}
  id="page-editor"
  document={@page.body}
  title={@page.title}
  back={~p"/admin/pages"}
  canvas={ElementorexCms.Canvas.new(stylesheets: [~p"/assets/css/app.css"])}
/>
```

```elixir
def handle_info({ElementorexCms.Editor, "page-editor", {:save, doc}}, socket) do
  {:ok, page} = Pages.update_page(socket.assigns.page, %{body: doc})
  ElementorexCms.Editor.saved("page-editor")
  {:noreply, assign(socket, :page, page)}
end
```

Show them:

```heex
<div phx-hook="ElementorexRuntime" id="page-body">
  <ElementorexCms.Components.document document={@page.body} params={@params} />
</div>
```

(`params`, from `mount/3`, tell loop grids which page, search and filters the
visitor chose.)

Or generate all of it: `mix elementorex.gen.cms Pages Page pages`.

## Dynamic content

Make a schema a source of dynamic content (a product table made with
`mix phx.gen.live`, for instance):

```elixir
config :elementorex_cms, sources: [MyApp.Catalog.Product]
```

or, to choose the fields, link each record to its page and keep drafts off your
site, `mix elementorex.gen.source Catalog.Product --path "/products/:slug"`.

In the editor, the *Loop grid* repeats its content for the products (limit,
order, filters, and pages: numbers, previous/next, a *Load more* button or
infinite scroll). The *Filters* block gives visitors a search box, choices
with the values of a column, ranges, toggles and the order, and you can write
your own filters (`mix elementorex.gen.filter`, or logic in the source). The
database button next to any prop shows a field of the
current product instead: the name in a heading, the photo in an image, the price
with `$` and thousands separators in a badge, the product's page in a button.
*Display conditions* (in the *Advanced* tab) show a block only for some items:
a *Sold out* badge when the stock is 0, the *Buy now* button when it is not.
The *Templates* panel builds grids, lists and the page of one product from the
fields of each source.

A document is the template of the page of each product when the editor gets
`source="products"` (the top bar picks the product on the canvas) and the page
renders it with the product:

```heex
<ElementorexCms.Components.document document={@template.body} record={@product} />
```

See the [dynamic content guide](guides/dynamic_content.md).

## The editor

| Area | What it does |
| --- | --- |
| Top bar | back link, title, your `:status` slot, device (desktop/tablet/mobile), zoom (fit, 50–150%), undo/redo, code drawer, preview, your `:actions` slot, *Save* |
| Left | the searchable palette by category (drag a tile, or click it to add after the selection or inside an empty container) and, below it, *Structure*: the DOM tree, where rows are dragged to reorder or nest. The rail switches to *Templates*, *History* and *Keyboard shortcuts* |
| Canvas | your site's CSS in an iframe; hover to see the block, click to select, double-click text to type, drag the blue chip to move; the path of the selection at the bottom |
| Inspector | *Content* (the block's props), *Style* (typography, spacing, size, background, border, effects, position — per device and for `:hover`), *Advanced* (name, CSS id, classes, hide per device, entrance animation, scoped custom CSS) |
| Code | HTML, CSS and JSON of the selection (or the whole document), with copy |

Shortcuts: ⌘S save · ⌘Z / ⇧⌘Z undo/redo · ⌘D duplicate · ⌘C / ⌘V copy/paste
blocks · ⌫ delete · ↑/↓ select siblings · ⌥↑/⌥↓ move · Esc parent · / search.

### Attributes

`id`, `document`, `title`, `subtitle`, `back`, `canvas`
(`ElementorexCms.Canvas`), `registry` (`ElementorexCms.Registry`), `templates`,
`media` + `media_context` (`ElementorexCms.Media`), `data` (passed to blocks),
`sources` + `source` (dynamic content, `ElementorexCms.Source`), `locale`,
`notify_changes`, `fullscreen` (default `true`), `inline_css`, `remount_key`.
Slots: `:status`, `:actions`. See `ElementorexCms.Editor`.

### The canvas

```elixir
ElementorexCms.Canvas.new(
  stylesheets: [~p"/assets/css/app.css"],
  html_attrs: %{"data-theme" => "light"},
  body_class: "bg-base-200",
  # the document goes where the frame has data-exr-mount
  frame: ~s(<main class="mx-auto max-w-3xl bg-base-100 p-8" data-exr-mount></main>),
  widths: %{"desktop" => 1280, "tablet" => 768, "mobile" => 390}
)
```

The frame can be a rendered component: in the app this library was born in,
modals are edited inside the real modal of each brand.

## Documents

```elixir
%{
  "version" => 1,
  "root" => %{
    "id" => "Wq0m2Lx9Ka", "type" => "root", "props" => %{}, "style" => %{}, "attrs" => %{},
    "children" => [
      %{
        "id" => "b3Rt9Lm1Qe",
        "type" => "heading",
        "props" => %{"text" => "Hello", "level" => "h2"},
        "style" => %{"desktop" => %{"color" => "var(--color-primary)"}, "mobile" => %{"font-size" => "28px"}},
        "attrs" => %{"hide_on" => ["tablet"], "css" => "selector { letter-spacing: -0.02em }"},
        "children" => []
      }
    ]
  }
}
```

`ElementorexCms.Document` has the pure operations (`insert/5`, `move/5`,
`duplicate/3`, `put_style/5`, `normalize/2`…) and `ElementorexCms.Builder`
builds documents in code:

```elixir
import ElementorexCms.Builder

doc([
  section([
    block("heading", %{text: "Welcome", level: "h1"}),
    columns([[block("feature", %{icon: "bolt"})], [block("feature", %{icon: "heart"})]])
  ])
])
```

`ElementorexCms.to_html/2` renders to a string and `ElementorexCms.to_text/1`
extracts the text (excerpts, search).

## Styles

Styles are declarations per state — `desktop` (base), `tablet`
(`max-width: 1023.98px`), `mobile` (`max-width: 767.98px`) and `hover` — scoped
to the node (`[data-ex-id="…"]`). The breakpoints match Tailwind's `lg` and
`md`, so `max-lg:` / `max-md:` classes in your blocks agree with them. Colors
can be daisyUI theme variables (`var(--color-primary)`), so content follows the
theme of the page it is shown on.

## Custom blocks

```elixir
defmodule MyAppWeb.Blocks.Pricing do
  use ElementorexCms.Block,
    type: "pricing",
    label: "Pricing",
    icon: "currency-dollar",
    category: :components

  prop :plan, :string, default: "Pro", inline: true
  prop :price, :string, default: "$9.990"
  prop :featured, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["card bg-base-100 p-6", @featured && "border-2 border-primary"])}>
      <h3 class="text-xl font-bold" {inline(assigns, :plan)}>{@plan}</h3>
      <p class="text-4xl font-black">{@price}</p>
    </div>
    """
  end
end
```

```elixir
config :elementorex_cms, blocks: [MyAppWeb.Blocks.Pricing]
```

See the [blocks guide](guides/blocks.md) for prop types, controls, containers
and the rules for class names. Every prop of your blocks (but lists) can be
bound to dynamic content too.

## Generators

| Task | Creates |
| --- | --- |
| `mix elementorex.gen.cms Pages Page pages` | migration, schema, context, admin list, editor page and public page |
| `mix elementorex.gen.block Pricing` | a block and its test |
| `mix elementorex.gen.template Marketing` | a module of ready-made sections |
| `mix elementorex.gen.source Catalog.Product` | a source of dynamic content for an Ecto schema |
| `mix elementorex.gen.filter PriceRanges` | a filter block of your own for the visitors' *Filters* forms |
| `mix elementorex.gen.locale es pt ja` | the strings of your blocks and templates to translate, one module per language |
| `mix elementorex.install` | nothing: checks the setup and prints what is missing |

## Languages

The editor speaks English unless told otherwise. The library ships `es`, `pt`,
`de`, `fr`, `it` and `ja`; pick one per editor (and per page, for the texts the
blocks add themselves, like the countdown units):

```heex
<.live_component module={ElementorexCms.Editor} id="editor" locale={@locale} ... />
<ElementorexCms.Components.document document={@page.body} locale={@locale} />
```

`locale` can change while the editor runs (a language switcher in its
`:actions` slot). `ElementorexCms.I18n.languages/0` lists `{code, name}` for
switchers; regional codes fall back to their language (`"pt-BR"` → `"pt"`).

Your blocks and templates are translated like the built-in ones. Generate a
module per language with every string they have, fill it in and register it:

```bash
mix elementorex.gen.locale es pt de fr it ja   # your strings, for languages the library ships
mix elementorex.gen.locale ko --name 한국어      # a new language: the library's strings too
mix elementorex.gen.locale es --all            # also the library's, to override some
```

```elixir
config :elementorex_cms,
  locales: [MyAppWeb.ElementorexLocales.Es, MyAppWeb.ElementorexLocales.Pt]
```

Untranslated entries are `nil` and fall back to English. Running the task again
after adding blocks keeps what is already translated. See `ElementorexCms.I18n`.

## Configuration

```elixir
config :elementorex_cms,
  locale: "en",                          # default UI language (default "en")
  locales: [MyAppWeb.ElementorexLocales.Es], # your translations (mix elementorex.gen.locale)
  blocks: [MyAppWeb.Blocks.Pricing],     # added to the built-in ones
  exclude_blocks: ["video"],             # built-in types to leave out
  templates: [MyAppWeb.EditorTemplates.Marketing],
  sources: [MyApp.Catalog.Product],      # dynamic content: schemas or source modules
  repo: MyApp.Repo,                      # of Ecto sources without `repo:` (default: the app's first)
  time_zone: "America/Santiago",         # of countdown targets (needs a tz database, e.g. :tz)
  translations: %{"es" => %{"Pricing" => "Precios"}} # a few strings, win over everything
```

## Security model

- Props are cast by type on every write **and** every render; rich text and HTML
  go through `ElementorexCms.HTML.Sanitizer` (allow-list, rebuilt from tokens).
- URLs keep only `http`, `https`, `mailto`, `tel` and relative paths.
- Style values are validated per property; shadows are presets; `url()` only
  takes safe URLs.
- Custom CSS loses `<`, `@import`, `expression()`, `behavior`, `javascript:`
  and unsafe `url()`s, and is nested inside its element with CSS nesting.
- Node ids are validated, so selectors cannot be broken out of.
- Dynamic content only reads the fields a source offers (secrets and
  `redact: true` fields are left out of Ecto sources) and casts their values
  like any other value of the prop; site values are only top-level text,
  numbers and dates of `data`.

## Development

```bash
mix deps.get
mix test
```

## License

MIT. Heroicons (in `priv/heroicons`) are MIT by Tailwind Labs.
