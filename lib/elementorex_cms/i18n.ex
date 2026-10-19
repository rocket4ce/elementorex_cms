defmodule ElementorexCms.I18n do
  @moduledoc """
  Translations of the editor interface and the built-in blocks.

  Every user-facing string of the library is written in English and looked up
  in the dictionary of the current locale when it is rendered. The library ships
  Spanish (`"es"`); English is the default.

  The locale is per process, like Gettext's: the editor sets it from its
  `locale` attribute on every update, so the LiveView that hosts it renders in
  that language. Outside the editor use `put_locale/1` or configure a default:

      config :elementorex_cms, locale: "es"

  Strings can be added or overridden per locale (for example the labels of your
  own blocks, or a whole new language):

      config :elementorex_cms, :translations, %{
        "es" => %{"Pricing table" => "Tabla de precios"},
        "pt" => %{"Button" => "Botão"}
      }
  """

  @key {__MODULE__, :locale}

  @doc "Sets the locale of the current process (`\"en\"`, `\"es\"`, ...)."
  @spec put_locale(String.t() | atom() | nil) :: String.t() | nil
  def put_locale(nil), do: Process.delete(@key)
  def put_locale(locale), do: Process.put(@key, to_string(locale))

  @doc "Locale of the current process, falling back to the configured default."
  @spec locale() :: String.t()
  def locale do
    Process.get(@key) || Application.get_env(:elementorex_cms, :locale, "en")
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
    |> lookup(locale())
    |> interpolate(bindings)
  end

  @doc "Locales with a built-in dictionary."
  @spec locales() :: [String.t()]
  def locales, do: ["en", "es"]

  defp lookup(text, "en"), do: custom("en", text) || text

  defp lookup(text, locale) do
    custom(locale, text) || Map.get(dictionary(locale), text, text)
  end

  defp custom(locale, text) do
    :elementorex_cms
    |> Application.get_env(:translations, %{})
    |> Map.get(locale, %{})
    |> Map.get(text)
  end

  defp dictionary("es"), do: ElementorexCms.I18n.Es.dictionary()
  defp dictionary(_locale), do: %{}

  defp interpolate(text, []), do: text
  defp interpolate(text, bindings) when bindings == %{}, do: text

  defp interpolate(text, bindings) do
    Enum.reduce(bindings, text, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end
