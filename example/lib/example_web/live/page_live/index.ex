defmodule ExampleWeb.PageLive.Index do
  @moduledoc "Admin list of pages, with creation."
  use ExampleWeb, :live_view

  alias Example.Pages
  alias Example.Pages.Page

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Pages")
     |> assign(:form, to_form(Pages.change_page(%Page{})))
     |> assign(:kinds, kinds())
     |> stream(:pages, Pages.list_pages())}
  end

  @impl true
  def handle_event("validate", %{"page" => params}, socket) do
    changeset = Pages.change_page(%Page{}, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("create", %{"page" => params}, socket) do
    case Pages.create_page(params) do
      {:ok, page} ->
        {:noreply, push_navigate(socket, to: "/admin/pages/#{page.id}/edit")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    page = Pages.get_page!(id)
    {:ok, _} = Pages.delete_page(page)
    {:noreply, stream_delete(socket, :pages, page)}
  end

  # A page, or the template of the records of a source of dynamic content.
  defp kinds do
    sources = ElementorexCms.Sources.default() |> ElementorexCms.Sources.list()
    [{"Page", ""} | Enum.map(sources, &{"Template of #{&1.label}", &1.key})]
  end
end
