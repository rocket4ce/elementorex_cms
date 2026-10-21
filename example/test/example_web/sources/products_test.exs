defmodule ExampleWeb.Sources.ProductsTest do
  use Example.DataCase, async: true

  import Example.CatalogFixtures

  alias ElementorexCms.Source
  alias ElementorexCms.Source.Query

  @public %{mode: :public, data: %{}}
  @editor %{mode: :editor, data: %{}}

  setup do
    shoes = product_fixture(name: "Shoes", slug: "shoes", category: "Shoes", price: "39990")
    boots = product_fixture(name: "Boots", slug: "boots", category: "Shoes", price: "89990")
    tee = product_fixture(name: "Tee", slug: "tee", category: "Shirts", price: "9990")
    draft = product_fixture(name: "Draft", slug: "draft", published: false, price: "1")

    %{
      source: Source.new(ExampleWeb.Sources.Products),
      shoes: shoes,
      boots: boots,
      tee: tee,
      draft: draft
    }
  end

  defp names(products), do: Enum.map(products, & &1.name)

  test "the fields come from the schema made by phx.gen.live", %{source: source} do
    types = Map.new(source.fields, &{&1.key, &1.type})

    assert types["name"] == :string
    assert types["price"] == :number
    assert types["image_url"] == :image
    assert types["description"] == :text
    assert types["stock"] == :integer
    assert types["featured"] == :boolean
    assert Source.field(source, "price").defaults["before"] == "$"
    assert Source.field(source, "@url").label == "Link to the item"
  end

  test "pages only get published products, the editor all of them", %{source: source} do
    refute "Draft" in names(Source.list(source, %Query{limit: 50}, @public))
    assert "Draft" in names(Source.list(source, %Query{limit: 50}, @editor))
  end

  test "filters, order, limit and exclude run in the database", %{source: source, boots: boots} do
    query = %Query{
      filters: [%{field: "category", op: "eq", value: "shoes"}],
      order_by: "price",
      order: :desc
    }

    assert names(Source.list(source, query, @public)) == ["Boots", "Shoes"]

    query = %Query{filters: [%{field: "price", op: "lt", value: "50000"}], order_by: "price"}
    assert names(Source.list(source, query, @public)) == ["Tee", "Shoes"]

    query = %Query{filters: [%{field: "name", op: "contains", value: "OO"}], exclude: [boots.id]}
    assert names(Source.list(source, query, @public)) == []

    assert length(Source.list(source, %Query{limit: 2}, @public)) == 2
  end

  test "get, url and title", %{source: source, tee: tee, draft: draft} do
    assert Source.get(source, tee.id, @public).id == tee.id
    assert Source.get(source, draft.id, @public) == nil
    assert Source.get(source, "not-a-uuid", @public) == nil
    assert Source.url(source, tee) == "/shop/tee"
    assert Source.title(source, tee) == "Tee"
  end
end
