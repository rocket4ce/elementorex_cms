defmodule Mix.Tasks.Elementorex.Gen.Filter do
  @shortdoc "Generates a filter of your own for the visitors' Filters forms"

  @moduledoc """
  Generates a filter block: a field of the *Filters* form (the search and
  filters visitors use on a loop grid) written by you, and its test.

      $ mix elementorex.gen.filter PriceRanges

  Creates `lib/my_app_web/blocks/price_ranges.ex` (module
  `MyAppWeb.Blocks.PriceRanges`) and its test: a list of ranges written in the
  editor (*Under 20.000*, *20.000 to 50.000*…) that visitors pick with radio
  buttons. Change its markup at will; what makes it a filter is the name and
  value of its inputs (see `ElementorexCms.Filters`):

    * `filter_name(assigns, @field)` - `catalog[price]`, one value
    * `filter_name(assigns, [@field, ""])` - `catalog[price][]`, several
    * `filter_name(assigns, [@field, "min"])` - a bound of a range
    * values like `"20000..50000"` are ranges of number and date fields
    * `filter_value/2`, `filter_checked?/3` and `filter_options/2` read the
      visitor's choice and the values of the field

  Logic that a field cannot express (*In stock* is `stock > 0`) goes in the
  source: see `filters:` in `ElementorexCms.Source.Ecto`.

  Register it afterwards:

      config :elementorex_cms, blocks: [MyAppWeb.Blocks.PriceRanges]

  ## Options

    * `--type`, `--label`, `--icon` - stored type, name in the palette and its
      Heroicon (default `funnel`)
    * `--namespace` - default `MyAppWeb.Blocks`
    * `--no-test`, `--force`
  """

  use Mix.Task

  alias Mix.Elementorex

  @switches [
    type: :string,
    label: :string,
    icon: :string,
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
        [] -> Mix.raise("expected a name, e.g. mix elementorex.gen.filter PriceRanges")
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
      label:
        opts[:label] ||
          parts
          |> List.last()
          |> Macro.underscore()
          |> String.replace("_", " ")
          |> String.capitalize(),
      icon: opts[:icon] || "funnel"
    }

    gen = [force: opts[:force] || false, dry_run: opts[:dry_run] || false]
    Elementorex.create(path, block_template(), assigns, gen)

    if Keyword.get(opts, :test, true),
      do: Elementorex.create(test_path, test_template(), assigns, gen)

    Mix.shell().info("""

    Register the filter (config/config.exs):

        config :elementorex_cms, blocks: [#{module}]

    In the editor it is in *Dynamic*, and goes in a *Filters* block.
    """)
  end

  defp block_template do
    ~S'''
    defmodule <%= @module %> do
      @moduledoc """
      <%= @label %>: a filter of the visitors' *Filters* forms (ElementorexCms).
      Visitors pick one of the ranges written in the editor; each sends
      `min..max` for the field (`catalog[price]=20000..50000`).
      """

      use ElementorexCms.Block,
        type: "<%= @type %>",
        label: "<%= @label %>",
        icon: "<%= @icon %>",
        category: :dynamic,
        description: "Pick one of a few ranges of a field",
        parents: ["filters"]

      prop :field, :field, label: "Field", only: :filterable
      prop :label, :string, label: "Label"

      prop :ranges, :list,
        label: "Ranges",
        item_label: :label,
        default: [
          %{"label" => "Under 20.000", "min" => "", "max" => "20000"},
          %{"label" => "20.000 to 50.000", "min" => "20000", "max" => "50000"},
          %{"label" => "Over 50.000", "min" => "50000", "max" => ""}
        ],
        fields: [
          {:label, :string, label: "Text"},
          {:min, :string, label: "From"},
          {:max, :string, label: "To"}
        ]

      def render(assigns) do
        if filter_form?(assigns) and assigns.field != "" do
          ~H"""
          <fieldset {root(assigns, class: "flex flex-col gap-1")}>
            <legend :if={@label != ""} class="mb-1 text-sm font-medium">{@label}</legend>
            <label class="flex cursor-pointer items-center gap-2">
              <input
                type="radio"
                class="radio radio-sm"
                name={filter_name(assigns, @field)}
                value=""
                checked={filter_value(assigns, @field) in [nil, ""]}
              />
              <span>{t("All")}</span>
            </label>
            <label :for={range <- @ranges} class="flex cursor-pointer items-center gap-2">
              <input
                type="radio"
                class="radio radio-sm"
                name={filter_name(assigns, @field)}
                value={"#{range["min"]}..#{range["max"]}"}
                checked={filter_checked?(assigns, @field, "#{range["min"]}..#{range["max"]}")}
              />
              <span>{range["label"]}</span>
            </label>
          </fieldset>
          """
        else
          # Outside a Filters form: a hint on the canvas, nothing on the site.
          ~H"""
          <p {root(assigns, class: "text-sm opacity-60")} hidden={!editor?(assigns)}>
            {t("Put it in a Filters block that filters a loop grid")}
          </p>
          """
        end
      end
    end
    '''
  end

  defp test_template do
    ~S'''
    defmodule <%= @module %>Test do
      use ExUnit.Case, async: true

      import ElementorexCms.Builder

      alias ElementorexCms.Registry
      alias ElementorexCms.Renderer

      setup do
        %{registry: Registry.new(blocks: Registry.builtin() ++ [<%= @module %>])}
      end

      test "is a field of the filter form of a loop grid", %{registry: registry} do
        filter = block("<%= @type %>", %{field: "price"}, registry: registry)
        form = block("filters", %{}, children: [filter], registry: registry)
        grid = block("loop", %{}, attrs: %{"id" => "grid"}, registry: registry)

        html =
          Renderer.to_html(doc([form, grid]),
            registry: registry,
            params: %{"grid" => %{"price" => "20000..50000"}}
          )

        assert html =~ ~s(name="grid[price]")
        assert html =~ ~s(value="20000..50000" checked)
      end

      test "outside a filter form it shows nothing on the site", %{registry: registry} do
        node = block("<%= @type %>", %{field: "price"}, registry: registry)
        assert Renderer.to_html(node, registry: registry) =~ "hidden"
      end
    end
    '''
  end
end
