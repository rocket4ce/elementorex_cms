defmodule Example.Pages do
  @moduledoc """
  Pages built with the visual editor.
  """

  import Ecto.Query, warn: false

  alias Example.Repo
  alias Example.Pages.Page

  @doc "All pages, newest first."
  def list_pages do
    Page |> order_by(desc: :updated_at) |> Repo.all()
  end

  @doc "Gets a page. Raises if it does not exist."
  def get_page!(id), do: Repo.get!(Page, id)

  @doc "The published page with `slug`, or `nil`."
  def get_published_page(slug) do
    Repo.get_by(Page, slug: slug, status: :published)
  end

  def create_page(attrs) do
    %Page{} |> Page.changeset(attrs) |> Repo.insert()
  end

  def update_page(%Page{} = page, attrs) do
    page |> Page.changeset(attrs) |> Repo.update()
  end

  @doc "Saves the document edited in the visual editor."
  def update_page_body(%Page{} = page, body) do
    page |> Page.body_changeset(body) |> Repo.update()
  end

  def delete_page(%Page{} = page), do: Repo.delete(page)

  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.changeset(page, attrs)
  end
end
