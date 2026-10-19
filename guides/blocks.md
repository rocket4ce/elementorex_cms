# Writing blocks

A block is a module with `use ElementorexCms.Block`, its props and a `render/1`
function component. Generate one with `mix elementorex.gen.block Name`.

## Options of `use`

| Option | Meaning |
| --- | --- |
| `:type` | stable id stored in documents (required; lowercase, `_`, `-`) |
| `:label`, `:description`, `:keywords` | shown and searched in the palette (translated with `ElementorexCms.I18n`) |
| `:icon` | Heroicons name of the palette tile |
| `:category` | `:layout`, `:basic`, `:components`, `:media`, `:advanced` or your own |
| `:container` | the block holds children |
| `:children` / `:parents` | restrict which types go inside / where it can go |
| `:style` | style of new nodes, e.g. `%{"desktop" => %{"padding-top" => "24px"}}` |
| `:palette` | `false` to hide it from the palette |

## Props

```elixir
prop :title, :string, label: "Title", default: "Hello", inline: true
prop :size, :select, options: [{"Small", "sm"}, {"Large", "lg"}], default: "sm", control: :segmented
prop :items, :list,
  item_label: :title,
  fields: [{:title, :string, default: "Item"}, {:done, :boolean}]
```

Types: `:string`, `:text`, `:richtext` (`policy: :inline` for one line),
`:html`, `:select`, `:boolean`, `:integer`, `:number`, `:url`, `:image`, `:icon`,
`:color`, `:datetime`, `:list`. Each one has a default control in the
inspector; `control:` changes it (`:textarea`, `:segmented`, `:swatches`,
`:range`, `:code`…). `group:` puts controls under a heading and `show_if:`
shows a control only when another prop matches (`{:icon, :present}`,
`{:variant, "outline"}`, `{:size, ["lg", "xl"]}`).

Values are cast and sanitized when they are stored and again when they are
rendered, so `render/1` can trust its assigns.

## Rendering

Every prop is an assign, plus `@node` and `@ctx` (`mode` is `:editor` on the
canvas, `:public` on the site; `data` has what the host passed).

- Spread `root/2` on the root element: `<div {root(assigns, class: [...])}>`. It
  adds the node id (styles are scoped to it), the *Advanced* classes and id, and
  what the editor needs.
- Mark inline-editable props with `inline/2`: `<h2 {inline(assigns, :title)}>`.
- Containers render their children with `<.children node={@node} ctx={@ctx} />`
  (on the canvas an empty container shows a drop zone).
- `heroicon/1`, `rich/1`, `rich_inline/1`, `link_attrs/2`, `style/1` and
  `editor?/1` are imported too (see `ElementorexCms.Block.Helpers`).

## Class names and Tailwind

Tailwind only generates classes it finds written in full in your source. Map
options to complete class names instead of building them:

```elixir
@sizes %{"sm" => "btn-sm", "lg" => "btn-lg"}   # good
"btn-#{@size}"                                  # Tailwind never sees btn-lg
```

Values that are not classes (a width in pixels, a background image) go through
`style/1`, which validates each declaration.
