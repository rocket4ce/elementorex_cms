defmodule ExampleWeb.PageLive.Show do
  @moduledoc "Public page of a published page."
  use ExampleWeb, :live_view

  alias Example.Pages

  # `params` go to the document: its loops read their page and the visitor's
  # filters there (`?catalog[page]=2&catalog[category]=Shoes`).
  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    case Pages.get_published_page(slug) do
      nil ->
        raise Ecto.NoResultsError, queryable: Example.Pages.Page

      page ->
        {:ok,
         socket
         |> assign(:page_title, page.title)
         |> assign(:page, page)
         |> assign(:params, params)}
    end
  end
end
