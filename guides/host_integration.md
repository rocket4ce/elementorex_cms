# Integrating with your app

ElementorexCms is a set of pieces you place where they fit: the editor in your
admin, documents in your schemas and the renderer in your pages.

## Where documents live

Any schema can have one or more documents:

```elixir
field :body, ElementorexCms.Ecto.Document, default: ElementorexCms.Document.new()
```

The type normalizes on cast, so a document that arrives from a form, an import
or the editor is valid and sanitized before it is stored.

## Saving from the editor

The editor never writes to your database. *Save* sends
`{ElementorexCms.Editor, id, {:save, document}}` to the LiveView that hosts it;
persist it however your app does (authorization, versions, audit) and answer
with `ElementorexCms.Editor.saved(id)` or `save_failed(id, message)`. With
`notify_changes` you also get `{:change, document}` on every edit, e.g. for
autosave.

## Showing documents inside your own chrome

The canvas can render the real context of the content: pass your stylesheets
and a frame with `data-exr-mount` where the document goes.

```elixir
def canvas(event) do
  ElementorexCms.Canvas.new(
    stylesheets: [~p"/assets/css/app.css"],
    frame: modal_frame(%{title: event.title})
  )
end

defp modal_frame(assigns) do
  ~H"""
  <div class="grid min-h-screen place-items-center bg-black/60 p-10">
    <div class="w-full max-w-lg rounded-box bg-base-100 p-8">
      <h2 class="text-2xl font-bold">{@title}</h2>
      <div data-exr-mount></div>
    </div>
  </div>
  """
end
```

The frame can be a string or anything `Phoenix.HTML.Safe`, like the rendered
component above. On your site, render the same wrapper and put
`<ElementorexCms.Components.document>` inside it.

## Images

Implement `ElementorexCms.Media` (`store/2` and optionally `list/2`) and pass
`media={MyApp.EditorMedia}`: image fields get *Upload* (LiveView uploads) and
*Library*. Without it they take a URL.

## Fewer blocks for a given place

```elixir
registry = ElementorexCms.Registry.new(only: ~w(heading text button image alert list))
```

Pass the same registry to the editor and to `<ElementorexCms.Components.document>`.

## Data for blocks

Blocks receive `@ctx.data`, set with `data={%{brand: @brand}}` in the editor and
the document component, for blocks that depend on the page (a WhatsApp button
with the number of the current brand, prices of the current product…).

Its top-level text, numbers and dates can also be shown by any block without
code: they are the *Site* fields of the database button next to each prop.
Records of your schemas (products, posts…) are dynamic content: see the
[dynamic content guide](dynamic_content.md).

## Query params

Pass the params of the page (`params={@params}` from `mount/3`, or
`@conn.params`) to `<ElementorexCms.Components.document>`: loop grids read
their page and the visitors' search and filters there, each under its own key
(`?catalog[page]=2&catalog[category]=Shoes`). Only those keys are used and
kept in their links.

## Development with a path dependency

While developing the library next to your app (`{:elementorex_cms, path: "../elementorex_cms"}`):

- add `reloadable_apps: [:my_app, :elementorex_cms]` to your endpoint config in
  `dev.exs` so the code reloader recompiles it;
- point esbuild's `NODE_PATH` to the folder that contains the library, and the
  Tailwind `@source` to `../../../elementorex_cms/lib` (relative to
  `assets/css`). Switch both back to `deps/` when it comes from Hex.
