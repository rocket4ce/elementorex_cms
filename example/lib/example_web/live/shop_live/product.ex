defmodule ExampleWeb.ShopLive.Product do
  @moduledoc """
  The page of a product of the shop (`/shop/:slug`): the template of products
  made in the visual editor (a page whose kind is *Template of Products*),
  rendered with the product. Until there is one, the template ElementorexCms
  makes from the fields of the source.
  """
  use ExampleWeb, :live_view

  alias Example.Catalog
  alias Example.Pages

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    case Catalog.get_published_product_by_slug(slug) do
      nil ->
        raise Ecto.NoResultsError, queryable: Example.Catalog.Product

      product ->
        {:ok,
         socket
         |> assign(:page_title, product.name)
         |> assign(:product, product)
         |> assign(:params, params)
         |> assign(:document, template())}
    end
  end

  defp template do
    case Pages.get_template("products") do
      %{body: body} ->
        body

      nil ->
        ElementorexCms.Sources.default()
        |> ElementorexCms.Templates.for_sources("products")
        |> Enum.find(& &1[:single])
        |> then(&ElementorexCms.Builder.doc(&1.nodes.()))
    end
  end
end
