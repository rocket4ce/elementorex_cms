defmodule Mix.Tasks.Elementorex.Gen.Locale do
  @shortdoc "Generates the translations of the visual editor for your app"

  @moduledoc """
  Generates a locale module (`ElementorexCms.I18n.Locale`) per language with
  every string to translate: the labels, help texts, options and default texts
  of your blocks, the names of your templates and the names of your sources of
  dynamic content and their fields.

      $ mix elementorex.gen.locale es pt de fr it ja
      $ mix elementorex.gen.locale ko --name 한국어

  For the languages the library ships (`es`, `pt`, `de`, `fr`, `it`, `ja`) the
  module only has your app's strings; the editor is already translated. For any
  other language it also has every string of the library, so the whole editor
  can be translated. `--all` adds them for a built-in language too, pre-filled
  with the library's translation, to override some.

  Creates `lib/my_app_web/elementorex_locales/pt.ex` (module
  `MyAppWeb.ElementorexLocales.Pt`). Register the modules:

      config :elementorex_cms, locales: [MyAppWeb.ElementorexLocales.Pt]

  Untranslated strings are `nil` (they fall back to English). Run the task again
  after adding blocks: the translations already in the module, and those in the
  `:translations` config, are kept (it asks before overwriting the file).

  ## Options

    * `--all` - include the strings of the library
    * `--name` - name of the language in that language (default: the
      library's name for built-in languages, otherwise the code)
    * `--namespace` - module namespace (default `MyAppWeb.ElementorexLocales`)
    * `--force` - overwrite existing files without asking
  """

  use Mix.Task

  alias ElementorexCms.I18n
  alias Mix.Elementorex

  @switches [all: :boolean, name: :string, namespace: :string, force: :boolean, dry_run: :boolean]

  @impl true
  def run(args) do
    {opts, locales, _} = OptionParser.parse(args, strict: @switches)

    if locales == [] do
      Mix.raise("expected one or more locales: mix elementorex.gen.locale es pt ko")
    end

    Enum.each(locales, &validate_locale!/1)

    if opts[:name] && length(locales) > 1 do
      Mix.raise("--name works with a single locale")
    end

    # Your blocks, templates and sources come from the app's config.
    Mix.Task.run("app.config")

    host = Elementorex.host()
    namespace = opts[:namespace] || "#{host.web}.ElementorexLocales"
    Elementorex.module_parts!(namespace)

    app_strings =
      I18n.strings(
        Application.get_env(:elementorex_cms, :blocks, []) ++
          Application.get_env(:elementorex_cms, :templates, []) ++
          Application.get_env(:elementorex_cms, :sources, [])
      )

    gen = [force: opts[:force] || false, dry_run: opts[:dry_run] || false]

    modules =
      for locale <- locales do
        module = "#{namespace}.#{module_suffix(locale)}"
        path = Path.join(["lib", Macro.underscore(namespace), "#{file_name(locale)}.ex"])
        content = render(module, locale, app_strings, opts)
        Elementorex.create(path, "<%= @content %>", %{content: content}, gen)
        module
      end

    Mix.shell().info("""

    Register the #{if length(modules) == 1, do: "module", else: "modules"} in config/config.exs:

        config :elementorex_cms,
          locales: [#{Enum.join(modules, ", ")}]

    Translations moved from the :translations config can be removed from it.
    """)
  end

  defp validate_locale!(locale) do
    unless locale =~ ~r/\A[a-z]{2,3}([-_][A-Za-z0-9]{2,8})?\z/ do
      Mix.raise("invalid locale #{inspect(locale)}, expected a code such as pt, ja or pt-BR")
    end
  end

  defp module_suffix(locale), do: locale |> file_name() |> Macro.camelize()
  defp file_name(locale), do: locale |> String.replace("-", "_") |> String.downcase()

  ## Content

  defp render(module, locale, app_strings, opts) do
    # A regional variant ("pt-BR") builds on the built-in language ("pt").
    base = locale |> String.split(["-", "_"]) |> hd()
    builtin? = Enum.any?(I18n.builtin(), &(&1.locale() == base))
    all? = opts[:all] || not builtin?
    name = opts[:name] || language_name(locale, base)
    library = I18n.source_strings()
    previous = previous(module, locale)
    builtin = if builtin?, do: I18n.dictionary(base), else: %{}

    own = Enum.reject(app_strings, &(&1 in library))
    library_section = if all?, do: library, else: []
    kept = Map.keys(previous) -- (own ++ library_section)

    sections =
      [
        {"Blocks, templates and sources of this app", own, &previous[&1]},
        {"ElementorexCms (the editor and the built-in blocks)", library_section,
         &Map.get(previous, &1, builtin[&1])},
        {"Kept from the previous version of this module", Enum.sort(kept), &previous[&1]}
      ]
      |> Enum.reject(fn {_title, strings, _value} -> strings == [] end)

    entries =
      Enum.map_join(sections, ",\n\n", fn {title, strings, value} ->
        "# #{title}\n" <>
          Enum.map_join(
            strings,
            ",\n",
            &"#{inspect(&1, printable_limit: :infinity)} => #{inspect(value.(&1), printable_limit: :infinity)}"
          )
      end)

    """
    defmodule #{module} do
      @moduledoc \"\"\"
      #{name} (`#{inspect(locale)}`) strings of the visual editor (ElementorexCms).

      Generated by `mix elementorex.gen.locale #{locale}`. Run it again after
      adding blocks, templates or sources: the translations here are kept.
      `nil` falls back to the library's translation, then to English.
      \"\"\"

      use ElementorexCms.I18n.Locale, locale: #{inspect(locale)}, name: #{inspect(name)}

      @impl true
      def dictionary do
        %{
          #{entries}
        }
      end
    end
    """
    |> Code.format_string!()
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  defp language_name(locale, base) do
    case List.keyfind(I18n.languages(), base, 0) do
      {_, name} when locale == base -> name
      {_, name} -> "#{name} (#{locale})"
      nil -> locale
    end
  end

  # Translations to keep: the module generated before (if compiled) and the
  # :translations config.
  defp previous(module, locale) do
    configured =
      :elementorex_cms |> Application.get_env(:translations, %{}) |> Map.get(locale, %{})

    module = Module.concat([module])

    generated =
      if Code.ensure_loaded?(module) and function_exported?(module, :dictionary, 0),
        do: module.dictionary(),
        else: %{}

    generated
    |> Map.merge(configured)
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end
end
