defmodule Mix.Tasks.Elementorex.Gen.Template do
  @shortdoc "Generates a module with ready-made sections for the editor"

  @moduledoc """
  Generates a templates module (see `ElementorexCms.Templates`): sections that
  the editor inserts from its *Templates* panel.

      $ mix elementorex.gen.template Marketing

  Creates `lib/my_app_web/editor_templates/marketing.ex`. Register it:

      config :elementorex_cms, templates: [MyAppWeb.EditorTemplates.Marketing]

  Options: `--namespace` (default `MyAppWeb.EditorTemplates`), `--force`.
  """

  use Mix.Task

  alias Mix.Elementorex

  @impl true
  def run(args) do
    {opts, argv, _} =
      OptionParser.parse(args, strict: [namespace: :string, force: :boolean, dry_run: :boolean])

    name =
      case argv do
        [name | _] -> name
        [] -> Mix.raise("expected a name, e.g. mix elementorex.gen.template Marketing")
      end

    host = Elementorex.host()
    parts = Elementorex.module_parts!(name)
    namespace = opts[:namespace] || "#{host.web}.EditorTemplates"
    module = Enum.join([namespace | parts], ".")
    key = Elementorex.underscore(parts)

    path =
      Path.join(["lib", Macro.underscore(namespace) | Enum.map(parts, &Macro.underscore/1)]) <>
        ".ex"

    Elementorex.create(path, template(), %{module: module, key: key},
      force: opts[:force] || false,
      dry_run: opts[:dry_run] || false
    )

    Mix.shell().info("""

    Register the templates (config/config.exs):

        config :elementorex_cms, templates: [#{module}]
    """)
  end

  defp template do
    ~S'''
    defmodule <%= @module %> do
      @moduledoc """
      Ready-made sections for the visual editor (ElementorexCms *Templates* panel).
      """

      @behaviour ElementorexCms.Templates

      import ElementorexCms.Builder

      @impl true
      def templates do
        [
          %{
            key: "<%= @key %>_hero",
            label: "Hero with call to action",
            description: "Headline, text and two buttons",
            icon: "sparkles",
            nodes: fn ->
              [
                section([
                  block("badge", %{text: "New"}),
                  block("heading", %{text: "Your headline", level: "h2", size: "4xl"}),
                  block("text", %{text: "<p>One or two lines that explain the offer.</p>"}),
                  block("button_group", %{})
                ])
              ]
            end
          },
          %{
            key: "<%= @key %>_features",
            label: "Three features",
            description: "Three icon boxes in a row",
            icon: "squares-2x2",
            nodes: fn ->
              [
                columns(
                  [
                    [block("feature", %{icon: "bolt", title: "Fast"})],
                    [block("feature", %{icon: "shield-check", title: "Safe"})],
                    [block("feature", %{icon: "heart", title: "Friendly"})]
                  ],
                  %{columns: "3", columns_mobile: "1"}
                )
              ]
            end
          }
        ]
      end
    end
    '''
  end
end
