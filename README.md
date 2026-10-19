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
- **34 blocks** built with **daisyUI 5** and **Heroicons** (inline SVG, so any
  icon picked at runtime works): sections, flex containers, responsive grids,
  hero, headings, rich text, buttons, icon boxes, lists, alerts, badges, cards,
  stats, steps, countdown, accordion, tabs, timeline, rating, progress, avatar,
  chat, testimonials, carousel, video, mockups, HTML…
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
- English and Spanish UI (`ElementorexCms.I18n`), extensible.

## Installation

```elixir
# mix.exs
def deps do
  [
    {:elementorex_cms, "~> 0.1"}
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
countdowns ticking on your site). Pages rendered by controllers can call
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
  locale="es"
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
  <ElementorexCms.Components.document document={@page.body} />
</div>
```

Or generate all of it: `mix elementorex.gen.cms Pages Page pages`.

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
`locale`, `notify_changes`, `fullscreen` (default `true`), `inline_css`,
`remount_key`. Slots: `:status`, `:actions`. See `ElementorexCms.Editor`.

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
and the rules for class names.

## Generators

| Task | Creates |
| --- | --- |
| `mix elementorex.gen.cms Pages Page pages` | migration, schema, context, admin list, editor page and public page |
| `mix elementorex.gen.block Pricing` | a block and its test |
| `mix elementorex.gen.template Marketing` | a module of ready-made sections |
| `mix elementorex.install` | nothing: checks the setup and prints what is missing |

## Configuration

```elixir
config :elementorex_cms,
  locale: "es",                          # default UI language
  blocks: [MyAppWeb.Blocks.Pricing],     # added to the built-in ones
  exclude_blocks: ["video"],             # built-in types to leave out
  templates: [MyAppWeb.EditorTemplates.Marketing],
  time_zone: "America/Santiago",         # of countdown targets (needs a tz database, e.g. :tz)
  translations: %{"es" => %{"Pricing" => "Precios"}}
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

## Development

```bash
mix deps.get
mix test
```

## License

MIT. Heroicons (in `priv/heroicons`) are MIT by Tailwind Labs.
