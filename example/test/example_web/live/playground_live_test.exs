defmodule ExampleWeb.PlaygroundLiveTest do
  use ExampleWeb.ConnCase

  import Phoenix.LiveViewTest

  alias ElementorexCms.Editor

  @editor "modal-editor"

  test "changes update the preview and the plain text", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")
    assert has_element?(view, "#modal-editor")
    assert has_element?(view, "#playground-preview [data-ex-countdown]")

    document =
      ElementorexCms.Builder.doc([
        ElementorexCms.Builder.block("heading", %{text: "Nuevo título"})
      ])

    send(view.pid, {Editor, @editor, {:change, document}})

    assert view |> element("#playground-text") |> render() =~ "Nuevo título"
    assert has_element?(view, "#playground-dirty")
    refute has_element?(view, "#playground-preview [data-ex-countdown]")
  end

  test "saving clears the unsaved state, and an empty modal is refused", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")

    send(view.pid, {Editor, @editor, {:save, Example.Showcase.modal()}})
    assert has_element?(view, "#playground-saved")

    view |> element("#playground-clear") |> render_click()
    send(view.pid, {Editor, @editor, {:save, ElementorexCms.Document.new()}})
    refute has_element?(view, "#playground-saved")
    assert view |> element("#playground-text") |> render() =~ "(empty)"
  end

  test "reset brings the example back", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/playground")

    view |> element("#playground-clear") |> render_click()
    view |> element("#playground-reset") |> render_click()
    assert view |> element("#playground-text") |> render() =~ "Black Friday"
  end

  test "the language changes the editor, the app's buttons and the preview", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/playground")
    assert html =~ "Save"
    assert view |> element("#playground-preview") |> render() =~ ">days<"

    html = view |> form("#playground-locale", %{locale: "ja"}) |> render_change()

    assert html =~ "保存"
    assert view |> element("#playground-reset") |> render() =~ "リセット"
    assert view |> element("#playground-preview") |> render() =~ ">日<"
    refute view |> element("#playground-preview") |> render() =~ ">days<"
  end
end
