defmodule ExampleWeb.PlaygroundLive do
  @moduledoc """
  The editor embedded in a page (not full screen), for content that lives
  inside someone else's chrome: a promotional modal.

  It exercises what the CMS pages do not:

    * `fullscreen={false}` and a canvas whose `frame` is the real modal
    * a registry with fewer blocks (`ElementorexCms.Registry.new(only: ...)`),
      shared by the editor and the preview
    * `notify_changes`: every edit updates the live preview, the plain text
      (`ElementorexCms.to_text/1`) and the HTML (`ElementorexCms.to_html/2`)
    * `ElementorexCms.Editor.replace_document/2`, `save_failed/2` and the
      `locale` attribute switched at runtime (editor, preview and `to_html/2`)

  The document lives in memory: reloading the page starts over.
  """
  use ExampleWeb, :live_view

  alias ElementorexCms.Editor

  @editor "modal-editor"
  @blocks ~w(heading text button button_group image badge alert list countdown divider spacer icon whatsapp)

  @impl true
  def mount(_params, _session, socket) do
    document = Example.Showcase.modal()

    {:ok,
     socket
     |> assign(:page_title, "Playground")
     |> assign(:editor, @editor)
     |> assign(:registry, ElementorexCms.Registry.new(only: @blocks))
     |> assign(:canvas, canvas())
     |> assign(:initial, document)
     |> assign(:saved_at, nil)
     |> assign(:dirty?, false)
     |> assign_document(document)}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    document = Example.Showcase.modal()
    Editor.replace_document(@editor, document)
    {:noreply, socket |> assign_document(document) |> assign(:dirty?, false)}
  end

  def handle_event("clear", _params, socket) do
    document = ElementorexCms.Document.new()
    Editor.replace_document(@editor, document)
    {:noreply, socket |> assign_document(document) |> assign(:dirty?, true)}
  end

  def handle_event("locale", %{"locale" => locale}, socket) do
    if locale in ElementorexCms.I18n.locales(),
      do:
        {:noreply, socket |> assign(:locale, locale) |> assign_document(socket.assigns.document)},
      else: {:noreply, socket}
  end

  @impl true
  def handle_info({Editor, @editor, {:change, document}}, socket) do
    {:noreply, socket |> assign_document(document) |> assign(:dirty?, true)}
  end

  def handle_info({Editor, @editor, {:save, document}}, socket) do
    if ElementorexCms.Document.root(document)["children"] == [] do
      Editor.save_failed(@editor, tr("An empty modal cannot be saved", socket.assigns.locale))
      {:noreply, socket}
    else
      Editor.saved(@editor)

      {:noreply,
       socket
       |> assign_document(document)
       |> assign(:dirty?, false)
       |> assign(:saved_at, Time.utc_now() |> Time.truncate(:second))}
    end
  end

  defp assign_document(socket, document) do
    html =
      ElementorexCms.to_html(document,
        registry: socket.assigns.registry,
        locale: socket.assigns.locale
      )

    socket
    |> assign(:document, document)
    |> assign(:text, ElementorexCms.to_text(document))
    |> assign(:html_size, byte_size(html))
  end

  # The canvas shows the document inside the same modal as the preview below.
  defp canvas do
    ElementorexCms.Canvas.new(
      stylesheets: [~p"/assets/css/app.css"],
      html_attrs: %{"data-theme" => "light"},
      frame: modal_frame(%{inner_block: [], mount: true, class: "min-h-screen py-6"}),
      widths: %{"desktop" => 1100, "tablet" => 768, "mobile" => 390}
    )
  end

  attr :mount, :boolean, default: false
  attr :class, :string, default: "py-16"
  slot :inner_block

  defp modal_frame(assigns) do
    ~H"""
    <div class={["grid place-items-center bg-neutral/70 px-6 max-md:px-3", @class]}>
      <div class="relative w-full max-w-lg rounded-box bg-base-100 p-8 shadow-2xl max-md:p-5">
        <span class="btn btn-circle btn-ghost btn-sm absolute top-3 right-3" aria-hidden="true">✕</span>
        <div :if={@mount} data-exr-mount></div>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
