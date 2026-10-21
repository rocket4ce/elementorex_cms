defmodule ExampleWeb.Locale do
  @moduledoc """
  The language of the editor and of the documents' own texts.

  As a plug it takes `?locale=` (any of `ElementorexCms.I18n.locales/0`),
  keeps it in the session and assigns `@locale`; as an `on_mount` hook it
  assigns the session's locale to LiveViews. English by default.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    locale =
      [conn.params["locale"], get_session(conn, "locale")]
      |> Enum.find("en", &(&1 in ElementorexCms.I18n.locales()))

    conn
    |> put_session("locale", locale)
    |> assign(:locale, locale)
  end

  @doc """
  Translates `text` to `locale` with the editor's dictionaries, which include
  the strings this app added to its locale modules (`ExampleWeb.ElementorexLocales`).
  """
  def tr(text, locale),
    do: ElementorexCms.I18n.with_locale(locale, fn -> ElementorexCms.I18n.t(text) end)

  def on_mount(:default, _params, session, socket) do
    locale = session["locale"]
    locale = if locale in ElementorexCms.I18n.locales(), do: locale, else: "en"
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end
end
