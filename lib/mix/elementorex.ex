defmodule Mix.Elementorex do
  @moduledoc false
  # Helpers shared by the elementorex.* Mix tasks: names of the host app and
  # file generation with EEx templates.

  @doc "The host app: `%{app: :my_app, base: \"MyApp\", web: \"MyAppWeb\", web_path: \"my_app_web\"}`."
  def host do
    app = Mix.Project.config()[:app] || raise Mix.Error, "run this task inside a Mix project"
    base = app |> Atom.to_string() |> Macro.camelize()

    %{
      app: app,
      base: base,
      web: base <> "Web",
      app_path: Atom.to_string(app),
      web_path: "#{app}_web"
    }
  end

  @doc "Splits `Admin.Pricing` into `[\"Admin\", \"Pricing\"]` and validates each part."
  def module_parts!(name) do
    parts = String.split(name, ".")

    unless Enum.all?(parts, &(&1 =~ ~r/\A[A-Z][A-Za-z0-9]*\z/)) do
      Mix.raise("expected a module name such as Pricing or Marketing.Hero, got: #{inspect(name)}")
    end

    parts
  end

  @doc "snake_case of the last part: `Marketing.HeroBanner` → `hero_banner`."
  def underscore(parts) when is_list(parts), do: parts |> List.last() |> Macro.underscore()

  @doc "Renders `template` with `assigns` and writes it to `path` (asks before overwriting)."
  def create(path, template, assigns, opts \\ []) do
    content = EEx.eval_string(template, assigns: assigns)

    if Keyword.get(opts, :dry_run, false) do
      Mix.shell().info([:yellow, "* would create ", :reset, path])
      content
    else
      Mix.Generator.create_file(path, content, force: Keyword.get(opts, :force, false))
      content
    end
  end
end
