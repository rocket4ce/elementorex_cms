defmodule Mix.Tasks.Elementorex.Gen.Block do
  @shortdoc "Generates a custom ElementorexCms block and its test"

  @moduledoc """
  Generates a block for the visual editor, with props for the inspector, its
  render function and a test.

      $ mix elementorex.gen.block Pricing
      $ mix elementorex.gen.block Marketing.HeroBanner --category layout --container --icon sparkles

  Creates `lib/my_app_web/blocks/pricing.ex` (module `MyAppWeb.Blocks.Pricing`)
  and `test/my_app_web/blocks/pricing_test.exs`. Register it afterwards:

      config :elementorex_cms, blocks: [MyAppWeb.Blocks.Pricing]

  ## Options

    * `--type` - type stored in documents (default: the snake_case name)
    * `--label` - name in the palette (default: from the module name)
    * `--icon` - Heroicons name for the palette (default `square-3-stack-3d`)
    * `--category` - `layout`, `basic`, `components`, `media`, `advanced` or
      your own (default `components`)
    * `--container` - the block holds child blocks
    * `--namespace` - module namespace (default `MyAppWeb.Blocks`)
    * `--no-test` - skip the test
    * `--force` - overwrite existing files
  """

  use Mix.Task

  alias Mix.Elementorex

  @switches [
    type: :string,
    label: :string,
    icon: :string,
    category: :string,
    container: :boolean,
    namespace: :string,
    test: :boolean,
    force: :boolean,
    dry_run: :boolean
  ]

  @impl true
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: @switches)

    name =
      case argv do
        [name | _] -> name
        [] -> Mix.raise("expected a block name, e.g. mix elementorex.gen.block Pricing")
      end

    host = Elementorex.host()
    parts = Elementorex.module_parts!(name)
    namespace = opts[:namespace] || "#{host.web}.Blocks"
    module = Enum.join([namespace | parts], ".")
    file = Elementorex.underscore(parts)
    type = opts[:type] || file

    unless type =~ ~r/\A[a-z][a-z0-9_-]{0,39}\z/ do
      Mix.raise("invalid --type #{inspect(type)}: use lowercase letters, digits, _ or -")
    end

    dir = namespace |> Macro.underscore() |> then(&Path.join("lib", &1))
    sub = parts |> Enum.drop(-1) |> Enum.map(&Macro.underscore/1)
    path = Path.join([dir | sub] ++ ["#{file}.ex"])
    test_path = Path.join(["test", Macro.underscore(namespace) | sub] ++ ["#{file}_test.exs"])

    assigns = %{
      module: module,
      type: type,
      label: opts[:label] || parts |> List.last() |> humanize(),
      icon: opts[:icon] || "square-3-stack-3d",
      category: opts[:category] || "components",
      container: Keyword.get(opts, :container, false)
    }

    gen = [force: opts[:force] || false, dry_run: opts[:dry_run] || false]
    Elementorex.create(path, block_template(), assigns, gen)

    if Keyword.get(opts, :test, true),
      do: Elementorex.create(test_path, test_template(), assigns, gen)

    Mix.shell().info("""

    Register the block (config/config.exs):

        config :elementorex_cms, blocks: [#{module}]

    Its classes reach your CSS through the `@source` of your Tailwind entry point
    (`lib/` is already scanned by Phoenix's default configuration).
    """)
  end

  defp humanize(name),
    do: name |> Macro.underscore() |> String.replace("_", " ") |> String.capitalize()

  defp block_template do
    ~S'''
    defmodule <%= @module %> do
      @moduledoc """
      <%= @label %> block for the visual editor (ElementorexCms).
      """

      use ElementorexCms.Block,
        type: "<%= @type %>",
        label: "<%= @label %>",
        icon: "<%= @icon %>",
        category: :<%= @category %>,
        description: "Describe what this block is for"<%= if @container do %>,
        container: true<% end %>

      prop :title, :string, label: "Title", default: "<%= @label %>", inline: true
      prop :text, :richtext, label: "Text", default: "<p>Write something here.</p>", inline: true

      prop :tone, :select,
        label: "Color",
        options: ElementorexCms.Blocks.Options.colors(),
        default: "primary",
        control: :swatches

      prop :icon, :icon, label: "Icon", default: "sparkles"

      # Class names must be written in full so Tailwind finds them.
      @tones %{
        "primary" => "text-primary",
        "secondary" => "text-secondary",
        "accent" => "text-accent",
        "neutral" => "text-neutral",
        "info" => "text-info",
        "success" => "text-success",
        "warning" => "text-warning",
        "error" => "text-error"
      }

      def render(assigns) do
        ~H"""
        <section {root(assigns, class: "flex flex-col gap-3 rounded-box bg-base-100 p-6")}>
          <.heroicon :if={@icon != ""} name={@icon} class={["size-8", Map.get(tones(), @tone)]} />
          <h3 class="text-xl font-bold" {inline(assigns, :title)}>{@title}</h3>
          <div class="exr-rich" {inline(assigns, :text)}>{rich(@text)}</div><%= if @container do %>
          <.children node={@node} ctx={@ctx} /><% end %>
        </section>
        """
      end

      defp tones, do: @tones
    end
    '''
  end

  defp test_template do
    ~S'''
    defmodule <%= @module %>Test do
      use ExUnit.Case, async: true

      alias ElementorexCms.Document
      alias ElementorexCms.Registry
      alias ElementorexCms.Renderer

      setup do
        %{registry: Registry.new(blocks: Registry.builtin() ++ [<%= @module %>])}
      end

      test "renders on the site and on the editor canvas", %{registry: registry} do
        node = Document.node("<%= @type %>", %{title: "Hello"}, registry: registry)

        assert Renderer.to_html(node, registry: registry) =~ "Hello"
        assert Renderer.to_html(node, registry: registry, mode: :editor) =~ ~s(data-ex-type="<%= @type %>")
      end

      test "sanitizes what it receives", %{registry: registry} do
        node = Document.node("<%= @type %>", %{text: "<p>ok</p><script>alert(1)</script>"}, registry: registry)
        refute Renderer.to_html(node, registry: registry) =~ "<script"
      end
    end
    '''
  end
end
