defmodule ExampleWeb.PageLiveTest do
  use ExampleWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Example.Pages

  setup do
    {:ok, page} = Pages.create_page(%{title: "Mi página"})
    {:ok, page} = Pages.update_page_body(page, Example.Showcase.modal())
    %{page: page}
  end

  test "lists and creates pages", %{conn: conn, page: page} do
    {:ok, view, _html} = live(conn, ~p"/admin/pages")
    assert has_element?(view, "#pages-#{page.id}")

    assert {:error, {:live_redirect, %{to: "/admin/pages/" <> _}}} =
             view |> form("#page-form", page: %{title: "Otra página"}) |> render_submit()

    assert Enum.any?(Pages.list_pages(), &(&1.slug == "otra-pagina"))
  end

  test "the editor saves the document", %{conn: conn, page: page} do
    {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}/edit")
    assert has_element?(view, "#page-editor")

    document = Example.Showcase.all_blocks()
    send(view.pid, {ElementorexCms.Editor, "page-editor", {:save, document}})
    _ = render(view)

    saved = Pages.get_page!(page.id)
    assert ElementorexCms.to_text(saved.body) == ElementorexCms.to_text(document)
  end

  test "publishing makes the public page visible", %{conn: conn, page: page} do
    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/p/#{page.slug}") end

    {:ok, view, _html} = live(conn, ~p"/admin/pages/#{page.id}/edit")
    view |> element("button[phx-click=toggle_publish]") |> render_click()

    {:ok, public, _html} = live(conn, ~p"/p/#{page.slug}")
    assert has_element?(public, "#page-content [data-ex-countdown]")
    assert has_element?(public, ~s(#page-content a[href^="https://wa.me/56987654321"]))
  end

  test "English by default, ?locale= changes the language and is remembered", %{
    conn: conn,
    page: page
  } do
    {:ok, _view, html} = live(conn, ~p"/admin/pages/#{page.id}/edit")
    assert html =~ "Save"
    assert html =~ "Publish"

    conn = get(conn, ~p"/?locale=de")
    assert get_session(conn, "locale") == "de"

    {:ok, view, html} = live(recycle(conn), ~p"/admin/pages/#{page.id}/edit")
    assert html =~ "Speichern"
    assert html =~ "Veröffentlichen"

    html = view |> form("#page-editor-locale", %{locale: "fr"}) |> render_change()
    assert html =~ "Enregistrer"
    assert html =~ "Publier"
  end

  test "unknown locales are ignored", %{conn: conn} do
    conn = get(conn, ~p"/?locale=xx")
    assert get_session(conn, "locale") == "en"
  end
end
