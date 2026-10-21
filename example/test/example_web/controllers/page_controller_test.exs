defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  test "GET / links the demos and renders a document on the server", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    for id <- ~w(home-pages home-showcase home-playground home-promo) do
      refute LazyHTML.query(document, "##{id}") |> Enum.empty?()
    end

    refute LazyHTML.query(document, "#home-promo [data-ex-countdown]") |> Enum.empty?()
  end
end
