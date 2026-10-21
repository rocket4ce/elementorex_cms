defmodule ExampleWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ExampleWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :locale, :string, default: "en", doc: "the current language (see ExampleWeb.Locale)"

  attr :width, :atom,
    default: :narrow,
    values: [:narrow, :wide, :full],
    doc: "width of the main column (`:full` leaves the layout to the page)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 border-b border-base-300 bg-base-100/80 backdrop-blur">
      <nav class="navbar mx-auto max-w-6xl gap-2 px-4 sm:px-6">
        <div class="flex-1">
          <.link navigate={~p"/"} class="group flex w-fit items-center gap-2">
            <span class="grid size-8 place-items-center rounded-lg bg-primary text-primary-content transition-transform group-hover:rotate-6">
              <.icon name="hero-squares-plus" class="size-5" />
            </span>
            <span class="font-semibold tracking-tight">Elementorex
            <span class="opacity-50">example</span></span>
          </.link>
        </div>
        <ul class="flex items-center gap-1">
          <li><.link navigate={~p"/admin/pages"} class="btn btn-ghost btn-sm">Pages</.link></li>
          <li><.link navigate={~p"/playground"} class="btn btn-ghost btn-sm">Playground</.link></li>
          <li><.language_menu locale={@locale} /></li>
          <li class="ml-2"><.theme_toggle /></li>
        </ul>
      </nav>
    </header>

    <main class={[
      @width == :narrow && "mx-auto max-w-4xl px-4 py-12 sm:px-6",
      @width == :wide && "mx-auto max-w-6xl px-4 py-12 sm:px-6"
    ]}>
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Dropdown with the languages of the editor. A full page load (`?locale=`)
  so `ExampleWeb.Locale` keeps the choice in the session.
  """
  attr :locale, :string, required: true

  def language_menu(assigns) do
    assigns = assign(assigns, :languages, ElementorexCms.I18n.languages())

    ~H"""
    <div id="language-menu" class="dropdown dropdown-end">
      <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1">
        <.icon name="hero-language" class="size-4" />
        <span class="uppercase">{@locale}</span>
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu z-50 mt-2 w-44 rounded-box border border-base-300 bg-base-100 p-1 shadow-lg"
      >
        <li :for={{code, name} <- @languages}>
          <a
            id={"language-#{code}"}
            href={"?locale=#{code}"}
            class={["justify-between", code == @locale && "menu-active"]}
          >
            {name} <span class="text-xs uppercase opacity-50">{code}</span>
          </a>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  A `<select>` of languages styled for the editor's top bar (its `:actions`
  slot). Sends `"locale"` with `%{"locale" => code}` to the LiveView.
  """
  attr :id, :string, required: true
  attr :locale, :string, required: true

  def language_select(assigns) do
    assigns = assign(assigns, :languages, ElementorexCms.I18n.languages())

    ~H"""
    <form id={@id} phx-change="locale">
      <select
        name="locale"
        class="exr-input exr-select"
        aria-label={ElementorexCms.I18n.t("Language")}
      >
        <option :for={{code, name} <- @languages} value={code} selected={code == @locale}>
          {name}
        </option>
      </select>
    </form>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
