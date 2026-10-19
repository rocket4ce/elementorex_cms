# Changelog

## 0.1.0 (unreleased)

First version.

- Document model (`ElementorexCms.Document`), builder and Ecto type.
- Block DSL (`ElementorexCms.Block`, `ElementorexCms.Block.Prop`) and 34
  built-in blocks with daisyUI 5 and inline Heroicons.
- Safe server rendering: props cast on render, allow-list HTML sanitizer, CSS
  value grammar, scoped custom CSS with nesting, URL allow-list.
- Responsive styles (desktop, tablet, mobile) and `:hover`, hide per device,
  entrance animations.
- Visual editor (LiveComponent + hook): palette, DOM tree, canvas iframe with the
  host's CSS, inspector (Content/Style/Advanced), inline editing, drag and drop,
  HTML/CSS/JSON drawer, undo/redo and history, templates, uploads and media
  library, keyboard shortcuts.
- English and Spanish interface.
- Mix tasks: `elementorex.install`, `elementorex.gen.cms`,
  `elementorex.gen.block`, `elementorex.gen.template`.
