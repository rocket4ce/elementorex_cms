defmodule Example.CatalogTest do
  use Example.DataCase

  alias Example.Catalog

  describe "products" do
    alias Example.Catalog.Product

    import Example.CatalogFixtures

    @invalid_attrs %{
      name: nil,
      description: nil,
      category: nil,
      slug: nil,
      price: nil,
      image_url: nil,
      stock: nil,
      featured: nil,
      published: nil
    }

    test "list_products/0 returns all products" do
      product = product_fixture()
      assert Catalog.list_products() == [product]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()
      assert Catalog.get_product!(product.id) == product
    end

    test "create_product/1 with valid data creates a product" do
      valid_attrs = %{
        name: "some name",
        description: "some description",
        category: "some category",
        slug: "some-slug",
        price: "120.5",
        image_url: "some image_url",
        stock: 42,
        featured: true,
        published: true
      }

      assert {:ok, %Product{} = product} = Catalog.create_product(valid_attrs)
      assert product.name == "some name"
      assert product.description == "some description"
      assert product.category == "some category"
      assert product.slug == "some-slug"
      assert product.price == Decimal.new("120.5")
      assert product.image_url == "some image_url"
      assert product.stock == 42
      assert product.featured == true
      assert product.published == true
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()

      update_attrs = %{
        name: "some updated name",
        description: "some updated description",
        category: "some updated category",
        slug: "some-updated-slug",
        price: "456.7",
        image_url: "some updated image_url",
        stock: 43,
        featured: false,
        published: false
      }

      assert {:ok, %Product{} = product} = Catalog.update_product(product, update_attrs)
      assert product.name == "some updated name"
      assert product.description == "some updated description"
      assert product.category == "some updated category"
      assert product.slug == "some-updated-slug"
      assert product.price == Decimal.new("456.7")
      assert product.image_url == "some updated image_url"
      assert product.stock == 43
      assert product.featured == false
      assert product.published == false
    end

    test "update_product/2 with invalid data returns error changeset" do
      product = product_fixture()
      assert {:error, %Ecto.Changeset{}} = Catalog.update_product(product, @invalid_attrs)
      assert product == Catalog.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Catalog.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(product.id) end
    end

    test "change_product/1 returns a product changeset" do
      product = product_fixture()
      assert %Ecto.Changeset{} = Catalog.change_product(product)
    end
  end
end
