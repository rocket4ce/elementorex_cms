defmodule ExampleWeb.PageLive.Show do
  @moduledoc "Public page of a published page."
  use ExampleWeb, :live_view

  alias Example.Pages

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Pages.get_published_page(slug) do
      nil -> raise Ecto.NoResultsError, queryable: Example.Pages.Page
      page -> {:ok, socket |> assign(:page_title, page.title) |> assign(:page, page)}
    end
  end
end
