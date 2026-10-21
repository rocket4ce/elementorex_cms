defmodule ExampleWeb.PageLive.Editor do
  @moduledoc "Visual editor of a page (ElementorexCms)."
  use ExampleWeb, :live_view

  alias ElementorexCms.Editor
  alias Example.Pages

  @editor "page-editor"

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    page = Pages.get_page!(id)

    {:ok,
     socket
     |> assign(:page_title, page.title)
     |> assign(:page, page)
     |> assign(:editor, @editor)
     |> assign(:canvas, canvas())}
  end

  @impl true
  def handle_event("locale", %{"locale" => locale}, socket) do
    if locale in ElementorexCms.I18n.locales(),
      do: {:noreply, assign(socket, :locale, locale)},
      else: {:noreply, socket}
  end

  def handle_event("toggle_publish", _params, socket) do
    page = socket.assigns.page
    status = if page.status == :published, do: :draft, else: :published
    {:ok, page} = Pages.update_page(page, %{status: status})
    {:noreply, assign(socket, :page, page)}
  end

  @impl true
  def handle_info({Editor, @editor, {:save, document}}, socket) do
    case Pages.update_page_body(socket.assigns.page, document) do
      {:ok, page} ->
        Editor.saved(@editor)
        {:noreply, assign(socket, :page, page)}

      {:error, _changeset} ->
        Editor.save_failed(@editor, tr("Could not save", socket.assigns.locale))
        {:noreply, socket}
    end
  end

  # The canvas renders the document with the same stylesheet and wrapper as
  # the public page (`PageLive.Show`).
  defp canvas do
    ElementorexCms.Canvas.new(
      stylesheets: [~p"/assets/css/app.css"],
      html_attrs: %{"data-theme" => "light"},
      body_class: "bg-base-100",
      frame: ~s(<main class="mx-auto max-w-6xl px-4 py-10 sm:px-6" data-exr-mount></main>)
    )
  end
end
