defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  alias Example.Pages

  def home(conn, _params) do
    render(conn, :home,
      pages: Pages.list_pages(),
      promo: Example.Showcase.modal(),
      version: ElementorexCms.version()
    )
  end
end
