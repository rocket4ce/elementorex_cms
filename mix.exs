defmodule ElementorexCms.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/rocket4ce/elementorex_cms"

  def project do
    [
      app: :elementorex_cms,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "ElementorexCms",
      description:
        "A visual, drag & drop content builder for Phoenix LiveView (in the spirit of " <>
          "Elementor): an editor with live canvas, DOM tree, inspector and HTML/CSS view, " <>
          "a JSON document model, daisyUI 5 + Heroicons blocks, safe server-side rendering " <>
          "and generators for custom blocks and templates.",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.1"},
      {:jason, "~> 1.4"},
      {:ecto, "~> 3.10", optional: true},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["rocket4ce"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib assets/js priv/static package.json mix.exs README.md CHANGELOG.md LICENSE
                .formatter.exs guides)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "guides/blocks.md",
        "guides/host_integration.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [Guides: ["guides/blocks.md", "guides/host_integration.md"]],
      groups_for_modules: [
        Documents: [
          ElementorexCms.Document,
          ElementorexCms.Builder,
          ElementorexCms.Ecto.Document
        ],
        Blocks: [
          ElementorexCms.Block,
          ElementorexCms.Block.Prop,
          ElementorexCms.Block.Helpers,
          ElementorexCms.Registry,
          ~r/ElementorexCms\.Blocks\./
        ],
        Rendering: [
          ElementorexCms.Renderer,
          ElementorexCms.Components,
          ElementorexCms.Style,
          ElementorexCms.CSS,
          ElementorexCms.HTML.Sanitizer,
          ElementorexCms.URL,
          ElementorexCms.Heroicons
        ],
        Editor: [
          ElementorexCms.Editor,
          ElementorexCms.Canvas,
          ElementorexCms.Media,
          ElementorexCms.Templates,
          ElementorexCms.I18n
        ]
      ]
    ]
  end
end
