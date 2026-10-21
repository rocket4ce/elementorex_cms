# Used by "mix format"
locals_without_parens = [prop: 2, prop: 3]

[
  import_deps: [:phoenix, :phoenix_live_view],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"],
  locals_without_parens: locals_without_parens,
  # Apps that list the library in `import_deps` write `prop :title, :string`
  export: [locals_without_parens: locals_without_parens]
]
