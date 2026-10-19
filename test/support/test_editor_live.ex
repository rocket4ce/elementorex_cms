defmodule ElementorexCms.TestEditorLive do
  @moduledoc false
  # Hosts the editor in tests. The test process id comes in the session and
  # receives the editor messages ({:save, doc}, {:change, doc}).
  use Phoenix.LiveView

  alias ElementorexCms.Editor

  @impl true
  def mount(_params, session, socket) do
    doc = session["document"] || ElementorexCms.Document.new()

    {:ok,
     assign(socket,
       test_pid: session["test_pid"],
       document: doc,
       saves: 0,
       fail: session["fail"] || false,
       locale: session["locale"] || "en"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={Editor}
      id="editor"
      document={@document}
      title="Test page"
      subtitle="Subtitle"
      back="/back"
      locale={@locale}
      notify_changes
      media={ElementorexCms.TestMedia}
      media_context={%{test_pid: @test_pid}}
    >
      <:status><span id="status-slot">Draft</span></:status>
      <:actions><button id="publish">Publish</button></:actions>
    </.live_component>
    """
  end

  @impl true
  def handle_info({Editor, "editor", {:save, doc}}, socket) do
    send(socket.assigns.test_pid, {:saved, doc})

    if socket.assigns.fail do
      Editor.save_failed("editor", "Could not save")
    else
      Editor.saved("editor")
    end

    {:noreply, update(socket, :saves, &(&1 + 1))}
  end

  def handle_info({Editor, "editor", {:change, doc}}, socket) do
    send(socket.assigns.test_pid, {:changed, doc})
    {:noreply, socket}
  end
end
