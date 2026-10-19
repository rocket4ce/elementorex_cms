defmodule Mix.Tasks.Elementorex.Install do
  @shortdoc "Checks (and explains) the ElementorexCms setup of your app"

  @moduledoc """
  Checks the steps that connect ElementorexCms to a Phoenix app and prints the
  snippet for any missing one. It does not modify files.

      $ mix elementorex.install

  What it checks:

    1. the editor hooks are registered in a JS entry point
       (`import {hooks as Elementorex} from "elementorex_cms"`)
    2. esbuild resolves the package from `deps/` (`NODE_PATH` in `config.exs`)
    3. the CSS that renders documents scans the blocks
       (`@source "../../deps/elementorex_cms/lib"`)
    4. optionally, the public runtime (countdown) is registered

  Options: `--js` and `--css` to point to other entry points (globs).
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [js: :string, css: :string])

    js = Path.wildcard(opts[:js] || "assets/js/**/*.{js,ts}")
    css = Path.wildcard(opts[:css] || "assets/css/**/*.css")
    config = Path.wildcard("config/*.exs")

    checks = [
      {"Editor hooks registered in your JS",
       any_contains?(js, ~r/from\s+["']elementorex_cms["']/),
       """
       // assets/js/app.js (or your admin entry point)
       import {hooks as Elementorex} from "elementorex_cms"
       const liveSocket = new LiveSocket("/live", Socket, {hooks: {...colocatedHooks, ...Elementorex}})
       """},
      {"esbuild resolves packages from deps/ (NODE_PATH)", any_contains?(config, ~r/NODE_PATH/),
       """
       # config/config.exs
       config :esbuild,
         my_app: [
           args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js),
           cd: Path.expand("../assets", __DIR__),
           env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
         ]
       """},
      {"Tailwind scans the blocks (@source)",
       any_contains?(css, ~r/@source\s+["'][^"']*elementorex_cms\/lib["']/),
       """
       /* assets/css/app.css, after @import "tailwindcss" */
       @source "../../deps/elementorex_cms/lib";
       """},
      {"Public runtime for the countdown (optional)",
       any_contains?(js, ~r/elementorex_cms\/runtime|ElementorexRuntime/),
       """
       // assets/js/app.js
       import {ElementorexRuntime} from "elementorex_cms/runtime"
       // hooks: {..., ElementorexRuntime}, and phx-hook="ElementorexRuntime" around the document
       """}
    ]

    Mix.shell().info([:bright, "ElementorexCms #{ElementorexCms.version()}", :reset, "\n"])

    for {label, ok?, snippet} <- checks do
      if ok? do
        Mix.shell().info([:green, "  ✓ ", :reset, label])
      else
        Mix.shell().info([:yellow, "  ✗ ", :reset, label, "\n\n", indent(snippet)])
      end
    end

    Mix.shell().info("""

    daisyUI 5 must be loaded by the CSS that renders documents (blocks use its
    component classes). Next steps:

      * the editor: <.live_component module={ElementorexCms.Editor} id="editor" document={...} />
      * your site: <ElementorexCms.Components.document document={...} />
      * a full CMS: mix elementorex.gen.cms Pages Page pages
      * your own blocks: mix elementorex.gen.block Pricing
    """)
  end

  defp any_contains?(paths, regex) do
    Enum.any?(paths, fn path -> path |> File.read!() |> String.match?(regex) end)
  end

  defp indent(text) do
    text |> String.split("\n") |> Enum.map_join("\n", &("      " <> &1))
  end
end
