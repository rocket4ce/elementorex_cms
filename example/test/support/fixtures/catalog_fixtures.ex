defmodule Example.CatalogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Example.Catalog` context.
  """

  @doc """
  Generate a unique product slug.
  """
  def unique_product_slug, do: "some-slug-#{System.unique_integer([:positive])}"

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        category: "some category",
        description: "some description",
        featured: true,
        image_url: "some image_url",
        name: "some name",
        price: "120.5",
        published: true,
        slug: unique_product_slug(),
        stock: 42
      })
      |> Example.Catalog.create_product()

    product
  end
end
