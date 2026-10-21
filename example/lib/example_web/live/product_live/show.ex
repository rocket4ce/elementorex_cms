defmodule ExampleWeb.ProductLive.Show do
  use ExampleWeb, :live_view

  alias Example.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} locale={@locale}>
      <.header>
        Product {@product.id}
        <:subtitle>This is a product record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/products"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/products/#{@product}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit product
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@product.name}</:item>
        <:item title="Slug">{@product.slug}</:item>
        <:item title="Description">{@product.description}</:item>
        <:item title="Price">{@product.price}</:item>
        <:item title="Image url">{@product.image_url}</:item>
        <:item title="Category">{@product.category}</:item>
        <:item title="Stock">{@product.stock}</:item>
        <:item title="Featured">{@product.featured}</:item>
        <:item title="Published">{@product.published}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Product")
     |> assign(:product, Catalog.get_product!(id))}
  end
end
