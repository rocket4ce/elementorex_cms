defmodule ElementorexCms.I18n do
  @moduledoc """
  Translations of the editor interface and the built-in blocks.

  Every user-facing string of the library is written in English and looked up
  in the dictionary of the current locale when it is rendered. English is the
  default; the library ships Spanish (`"es"`), Portuguese (`"pt"`), German
  (`"de"`), French (`"fr"`), Italian (`"it"`) and Japanese (`"ja"`).

  The locale is per process, like Gettext's: the editor sets it from its
  `locale` attribute on every update, so the LiveView that hosts it renders in
  that language. Pages pass `locale` to `ElementorexCms.Components.document/1`.
  Elsewhere use `put_locale/1`, `with_locale/2` or configure a default:

      config :elementorex_cms, locale: "es"

  Regional codes fall back to their language: `"pt-BR"` and `"fr_CA"` use the
  `"pt"` and `"fr"` dictionaries.

  ## Your own strings and languages

  The labels of your blocks and templates are translated like the built-in
  ones. Put them in locale modules (see `ElementorexCms.I18n.Locale`), which
  `mix elementorex.gen.locale` creates with every string to translate:

      $ mix elementorex.gen.locale es pt          # your blocks in two languages
      $ mix elementorex.gen.locale ko --name 한국어  # a new language, everything

      config :elementorex_cms,
        locales: [MyAppWeb.ElementorexLocales.Es, MyAppWeb.ElementorexLocales.Pt]

  A few strings can also go straight in the config; they win over everything:

      config :elementorex_cms, :translations, %{"es" => %{"Pricing" => "Precios"}}

  Lookup order: `:translations` → the app's locale modules → the built-in
  dictionary → the English text.
  """

  alias ElementorexCms.I18n

  @key {__MODULE__, :locale}

  @builtin [I18n.Es, I18n.Pt, I18n.De, I18n.Fr, I18n.It, I18n.Ja]

  @doc "Sets the locale of the current process (`\"en\"`, `\"es\"`, `\"pt-BR\"`...)."
  @spec put_locale(String.t() | atom() | nil) :: String.t() | nil
  def put_locale(nil), do: Process.delete(@key)
  def put_locale(locale), do: Process.put(@key, to_string(locale))

  @doc "Locale of the current process, falling back to the configured default."
  @spec locale() :: String.t()
  def locale do
    Process.get(@key) || Application.get_env(:elementorex_cms, :locale, "en")
  end

  @doc """
  Runs `fun` with `locale` as the locale of the process and restores the
  previous one afterwards. `nil` keeps the current locale.

      iex> ElementorexCms.I18n.with_locale("de", fn -> ElementorexCms.I18n.t("Button") end)
      "Button"
      iex> ElementorexCms.I18n.with_locale("ja", fn -> ElementorexCms.I18n.t("Save") end)
      "保存"
  """
  @spec with_locale(String.t() | atom() | nil, (-> result)) :: result when result: var
  def with_locale(nil, fun), do: fun.()

  def with_locale(locale, fun) do
    previous = Process.get(@key)
    put_locale(locale)

    try do
      fun.()
    after
      put_locale(previous)
    end
  end

  @doc """
  Translates `text` to the current locale. `bindings` replace `%{name}`
  placeholders after the lookup.

      iex> ElementorexCms.I18n.put_locale("es")
      iex> ElementorexCms.I18n.t("Button")
      "Botón"
      iex> ElementorexCms.I18n.t("%{count} items", count: 3)
      "3 elementos"
  """
  @spec t(String.t() | nil, keyword() | map()) :: String.t()
  def t(text, bindings \\ [])
  def t(nil, _bindings), do: ""

  def t(text, bindings) when is_binary(text) do
    text
    |> lookup(resolve(locale()))
    |> interpolate(bindings)
  end

  @doc """
  Available locales: English, the built-in ones and the new languages of the
  configured locale modules.

      iex> ElementorexCms.I18n.locales()
      ["en", "es", "pt", "de", "fr", "it", "ja"]
  """
  @spec locales() :: [String.t()]
  def locales do
    Enum.uniq(["en" | Enum.map(@builtin ++ app_modules(), & &1.locale())])
  end

  @doc """
  `{locale, name}` of every available locale, with the name of each language in
  that language: for language switchers.
  """
  @spec languages() :: [{String.t(), String.t()}]
  def languages do
    names = Map.new(@builtin ++ app_modules(), &{&1.locale(), &1.name()})
    Enum.map(locales(), &{&1, Map.get(names, &1, if(&1 == "en", do: "English", else: &1))})
  end

  @doc "The built-in locale modules (see `ElementorexCms.I18n.Locale`)."
  @spec builtin() :: [module()]
  def builtin, do: @builtin

  @doc """
  The English strings of the library that are translated: the keys of every
  built-in dictionary.
  """
  @spec source_strings() :: [String.t()]
  def source_strings, do: I18n.Es.dictionary() |> Map.keys() |> Enum.sort()

  @doc """
  The effective dictionary of a locale: the built-in one, the app's locale
  modules and the `:translations` config, merged in that order (`nil` values
  are left out).
  """
  @spec dictionary(String.t()) :: %{String.t() => String.t()}
  def dictionary(locale) do
    locale = resolve(locale)
    custom = :elementorex_cms |> Application.get_env(:translations, %{}) |> Map.get(locale, %{})

    [builtin_dictionary(locale) | Enum.map(app_modules(locale), & &1.dictionary())]
    |> Enum.reduce(%{}, &Map.merge(&2, reject_nil(&1)))
    |> Map.merge(reject_nil(custom))
  end

  @doc """
  The translatable strings of block modules (`ElementorexCms.Block`) and
  template modules (`ElementorexCms.Templates`): labels, descriptions, help
  texts, groups, option names, the custom category and default texts.
  Used by `mix elementorex.gen.locale`.
  """
  @spec strings([module()]) :: [String.t()]
  def strings(modules) do
    modules
    |> Enum.flat_map(fn module ->
      cond do
        ElementorexCms.Block.block?(module) -> block_strings(module)
        function_exported?(module, :templates, 0) -> template_strings(module)
        true -> []
      end
    end)
    |> Enum.filter(&translatable?/1)
    |> Enum.uniq()
  end

  ## Lookup

  # The locale with a dictionary: "pt-BR" → "pt" unless "pt-BR" exists itself.
  defp resolve(locale) do
    locale = locale |> to_string() |> String.replace("_", "-")
    known = locales()

    cond do
      locale in known -> locale
      String.downcase(locale) in known -> String.downcase(locale)
      true -> locale |> String.split("-") |> hd() |> String.downcase()
    end
  end

  defp lookup(text, locale) do
    custom(locale, text) || app(locale, text) || builtin(locale, text) || text
  end

  defp custom(locale, text) do
    :elementorex_cms
    |> Application.get_env(:translations, %{})
    |> Map.get(locale, %{})
    |> Map.get(text)
  end

  defp app(locale, text) do
    Enum.find_value(app_modules(locale), &Map.get(&1.dictionary(), text))
  end

  defp builtin("en" <> _, _text), do: nil
  defp builtin(locale, text), do: Map.get(builtin_dictionary(locale), text)

  # A regional locale of the app ("pt-BR") uses the built-in "pt".
  defp builtin_dictionary(locale) do
    base = locale |> String.split("-") |> hd()

    case Enum.find(@builtin, &(&1.locale() == locale)) ||
           Enum.find(@builtin, &(&1.locale() == base)) do
      nil -> %{}
      module -> module.dictionary()
    end
  end

  # The app's locale modules; later ones win, so they are searched last first.
  defp app_modules, do: Application.get_env(:elementorex_cms, :locales, [])
  defp app_modules(locale), do: app_modules() |> Enum.filter(&(&1.locale() == locale))

  defp reject_nil(map), do: for({k, v} <- map, is_binary(v), into: %{}, do: {k, v})

  defp interpolate(text, []), do: text
  defp interpolate(text, bindings) when bindings == %{}, do: text

  defp interpolate(text, bindings) do
    Enum.reduce(bindings, text, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  ## Strings of blocks and templates

  @text_types [:string, :text, :richtext]

  defp block_strings(module) do
    meta = module.meta()

    category =
      if meta.category in ElementorexCms.Registry.categories(),
        do: [],
        else: [meta.category |> to_string() |> String.capitalize()]

    [meta.label, meta[:description]] ++ category ++ Enum.flat_map(module.props(), &prop_strings/1)
  end

  defp prop_strings(prop) do
    options = for {label, _value} <- prop.options || [], do: label

    fields =
      for field <- prop.fields || [], text <- prop_strings(field), do: text

    item_texts =
      for item <- List.wrap(prop.type == :list && prop.default),
          is_map(item),
          field <- prop.fields || [],
          field.type in @text_types,
          do: item[to_string(field.name)]

    default = if prop.type in @text_types, do: [prop.default], else: []

    [prop.label, prop.help, prop.group, prop.placeholder] ++
      options ++ fields ++ item_texts ++ default
  end

  defp template_strings(module) do
    Enum.flat_map(module.templates(), &[&1[:label], &1[:description]])
  end

  defp translatable?(text),
    do: is_binary(text) and text =~ ~r/\p{L}/u and not (text =~ ~r/^https?:/)
end
