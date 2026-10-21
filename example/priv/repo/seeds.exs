# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# It is idempotent: pages are matched by slug and their documents rebuilt.

alias Example.Pages
alias Example.Pages.Page
alias Example.Repo

pages = [
  %{
    title: "Every block",
    slug: "every-block",
    status: :published,
    body: Example.Showcase.all_blocks()
  },
  %{
    title: "Templates",
    slug: "templates",
    status: :published,
    body: Example.Showcase.templates()
  },
  %{
    title: "Empty draft",
    slug: "draft",
    status: :draft,
    body: ElementorexCms.Document.new()
  }
]

for %{body: body} = attrs <- pages do
  page =
    case Repo.get_by(Page, slug: attrs.slug) do
      nil -> %Page{}
      page -> page
    end

  {:ok, page} = page |> Page.changeset(Map.delete(attrs, :body)) |> Repo.insert_or_update()
  {:ok, _page} = Pages.update_page_body(page, body)
end
