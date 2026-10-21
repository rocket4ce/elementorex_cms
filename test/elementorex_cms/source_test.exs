defmodule ElementorexCms.SourceTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.Source
  alias ElementorexCms.Source.Field
  alias ElementorexCms.Source.Query
  alias ElementorexCms.Sources
  alias ElementorexCms.TestProduct

  doctest ElementorexCms.Source.Field
  doctest ElementorexCms.Source.Query

  describe "Field" do
    test "labels in words, with acronyms and paths" do
      assert Field.new(:image_url).label == "Image URL"
      assert Field.new("category.name").label == "Category · Name"
      assert Field.new(:inserted_at).label == "Created at"
      assert Field.new(:sku).label == "SKU"
    end

    test "rejects unknown types and keeps valid default settings" do
      assert_raise ArgumentError, fn -> Field.new(:x, type: :money) end

      field = Field.new(:price, defaults: %{before: "$", format: "nope", decimals: 9})
      assert field.defaults == %{"before" => "$"}
    end
  end

  describe "a source implemented by hand" do
    setup do
      %{source: Source.new(ElementorexCms.TestSource)}
    end

    test "new/1 reads the module", %{source: source} do
      assert %Source{key: "products", label: "Products", icon: "shopping-bag"} = source
      assert Enum.map(source.fields, & &1.key) |> Enum.take(3) == ~w(name price image)
    end

    test "@url is offered when records have a page", %{source: source} do
      assert %Field{type: :url, label: "Link to the item"} = Source.field(source, "@url")
      [product | _] = ElementorexCms.TestSource.products()
      assert Source.value(source, product, "@url") == "/shop/red-shoes"
    end

    test "count/3 when the source can count", %{source: source} do
      assert Source.count(source, %Query{limit: 1}, %{mode: :public, data: %{}}) == 3

      no_count = Source.new(ElementorexCms.TestUncountedSource)
      assert Source.count(no_count, %Query{}, %{mode: :public, data: %{}}) == nil
    end

    test "id, title and get without get/2", %{source: source} do
      [product | _] = ElementorexCms.TestSource.products()
      assert Source.id(source, product) == 1
      assert Source.title(source, product) == "Red shoes"
      assert Source.get(source, "2", %{mode: :public, data: %{}}).name == "Blue shirt"
    end

    test "roles come from the fields", %{source: source} do
      assert Source.role(source, :title).key == "name"
      assert Source.role(source, :image).key == "image"
      assert Source.role(source, :description).key == "description"
      assert Source.role(source, :price).key == "price"
    end

    test "read/2 follows paths and never creates atoms" do
      record = %{"a" => %{b: 1}, c: nil}
      assert Source.read(record, "a.b") == 1
      assert Source.read(record, "c") == nil
      assert Source.read(record, "zzz_not_an_atom_#{System.unique_integer([:positive])}") == nil
      assert Source.read(nil, "a") == nil
    end

    test "rejects modules that are not sources" do
      assert_raise ArgumentError, ~r/not a source/, fn -> Source.new(String) end
    end
  end

  describe "Sources" do
    test "keeps the order and finds by key and by record" do
      sources = Sources.new([ElementorexCms.TestSource, ElementorexCms.TestEctoSource])

      assert Enum.map(Sources.list(sources), & &1.key) == ["products"]
      assert Sources.fetch(sources, "products").label == "Catalog"
      assert Sources.fetch(sources, "nope") == nil
      assert Sources.for_record(sources, %TestProduct{}).key == "products"
      assert Sources.for_record(sources, %{}) == nil
    end

    test "default/0 reads the config" do
      assert Sources.empty?(Sources.default())
    end
  end

  describe "Query.run/4" do
    setup do
      value = fn product, key -> Map.get(product, String.to_existing_atom(key)) end
      %{value: value, products: ElementorexCms.TestSource.products()}
    end

    test "filters, excludes, orders and pages", %{value: value, products: products} do
      names = &Enum.map(&1, fn product -> product.name end)

      query = %Query{filters: [%{field: "category", op: "eq", value: "shoes"}]}
      assert names.(Query.run(query, products, value)) == ["Red shoes", "Green shoes"]

      query = %Query{order_by: "price", order: :desc, limit: 2}
      assert names.(Query.run(query, products, value)) == ["Green shoes", "Red shoes"]

      query = %Query{filters: [%{field: "price", op: "lt", value: "20000"}], exclude: ["1"]}
      assert names.(Query.run(query, products, value)) == ["Blue shirt"]

      query = %Query{filters: [%{field: "image", op: "unset", value: ""}]}
      assert names.(Query.run(query, products, value)) == ["Green shoes"]

      query = %Query{filters: [%{field: "name", op: "contains", value: "SHO"}], offset: 1}
      assert names.(Query.run(query, products, value)) == ["Green shoes"]
    end

    test "count/4 ignores the page", %{value: value, products: products} do
      query = %Query{
        limit: 1,
        offset: 1,
        filters: [%{field: "category", op: "eq", value: "Shoes"}]
      }

      assert Query.count(query, products, value) == 2
      assert Query.count(%Query{exclude: ["1"]}, products, value) == 2
    end

    test "empty values go last in both directions", %{value: value, products: products} do
      asc = Query.run(%Query{order_by: "released_on"}, products, value)
      desc = Query.run(%Query{order_by: "released_on", order: :desc}, products, value)

      assert List.last(asc).name == "Green shoes"
      assert List.last(desc).name == "Green shoes"
      assert hd(desc).name == "Blue shirt"
    end
  end

  describe "Ecto sources" do
    setup do
      %{
        source: Source.new(ElementorexCms.TestEctoSource),
        bare: Source.new(TestProduct),
        context: %{mode: :editor, data: %{}}
      }
    end

    test "a schema works as it is", %{bare: bare} do
      assert bare.key == "products"
      assert bare.label == "Products"
      assert bare.impl == {ElementorexCms.Source.Ecto, [schema: TestProduct]}
      refute Source.url?(bare)
    end

    test "fields and types come from the schema and the names", %{source: source} do
      types = Map.new(source.fields, &{&1.key, &1.type})

      assert types["name"] == :string
      assert types["price"] == :number
      assert types["image_url"] == :image
      assert types["description"] == :text
      assert types["body_html"] == :html
      assert types["stock"] == :integer
      assert types["featured"] == :boolean
      assert types["status"] == :string
      assert types["released_on"] == :date
      assert types["inserted_at"] == :datetime
      assert types["tags"] == :list
      assert types["category.name"] == :string
    end

    test "secrets, redacted fields and maps are left out", %{source: source} do
      keys = Enum.map(source.fields, & &1.key)

      for key <- ~w(password_hash api_token meta category.secret_token),
          do: refute(key in keys, "#{key} should not be offered")
    end

    test "options: labels, defaults, only and except", %{source: source} do
      assert Source.field(source, "image_url").label == "Photo"
      assert Source.field(source, "price").defaults == %{"before" => "$", "format" => "number"}

      only =
        Source.new(
          {ElementorexCms.Source.Ecto, schema: TestProduct, only: [:name, :password_hash]}
        )

      assert Enum.map(only.fields, & &1.key) == ~w(name password_hash)

      except = Source.new({ElementorexCms.Source.Ecto, schema: TestProduct, except: [:name]})
      refute Source.field(except, "name")
    end

    test "list/3 builds the query from the loop", %{source: source, context: context} do
      query = %Query{
        limit: 3,
        offset: 1,
        order_by: "price",
        order: :desc,
        filters: [
          %{field: "category", op: "eq", value: "x"},
          %{field: "featured", op: "eq", value: "true"},
          %{field: "name", op: "contains", value: "Shoe"},
          %{field: "price", op: "gte", value: "10"},
          %{field: "", op: "eq", value: "unfinished"}
        ],
        exclude: ["7"]
      }

      Source.list(source, query, context)
      assert_received {:repo_all, ecto_query}
      assert_received {:repo_preload, [:category]}
      sql = inspect(ecto_query)

      assert sql =~ "t0.featured == ^true"
      assert sql =~ ~s|like(fragment("lower(?)", t0.name), ^"%shoe%")|
      assert sql =~ ~s|t0.price >= ^Decimal.new("10")|
      assert sql =~ "t0.id not in ^[7]"
      assert sql =~ "order_by: [desc: t0.price, asc: t0.id]"
      assert sql =~ "limit: ^3"
      assert sql =~ "offset: ^1"
      # `category` is not a column: only `category.name`, which cannot be filtered
      refute sql =~ "category"
    end

    test "count/3 counts what the loop would list, without order nor page", %{
      source: source,
      context: context
    } do
      Process.put(:test_repo_count, 12)

      query = %Query{
        limit: 3,
        offset: 6,
        order_by: "price",
        filters: [%{field: "featured", op: "eq", value: "true"}],
        exclude: ["7"]
      }

      assert Source.count(source, query, context) == 12
      assert_received {:repo_count, ecto_query}
      sql = inspect(ecto_query)

      assert sql =~ "t0.featured == ^true"
      assert sql =~ "t0.id not in ^[7]"
      refute sql =~ "order_by"
      refute sql =~ "limit"
    end

    test "invalid values match nothing and the scope restricts", %{source: source} do
      query = %Query{filters: [%{field: "price", op: "eq", value: "cheap"}]}

      Source.list(source, query, %{mode: :public, data: %{}})
      assert_received {:repo_all, ecto_query}
      sql = inspect(ecto_query)

      assert sql =~ "where: t0.status == :published"
      assert sql =~ "where: false"
    end

    test "default order: newest first", %{source: source, context: context} do
      Source.list(source, %Query{}, context)
      assert_received {:repo_all, ecto_query}
      assert inspect(ecto_query) =~ "order_by: [desc: t0.inserted_at, asc: t0.id]"
    end

    test "UUID keys: what is not a UUID never reaches the database", %{context: context} do
      posts =
        Source.new(
          {ElementorexCms.Source.Ecto,
           schema: ElementorexCms.TestPost, repo: ElementorexCms.TestRepo}
        )

      assert Source.get(posts, "not-a-uuid", context) == nil
      refute_received {:repo_one, _}

      uuid = Ecto.UUID.generate()
      Source.list(posts, %Query{exclude: ["nope", uuid]}, context)
      assert_received {:repo_all, ecto_query}
      assert inspect(ecto_query) =~ ~s|t0.id not in ^["#{uuid}"]|
    end

    test "schemas without a primary key", %{context: context} do
      tags =
        Source.new(
          {ElementorexCms.Source.Ecto,
           schema: ElementorexCms.TestTag, repo: ElementorexCms.TestRepo}
        )

      Source.list(tags, %Query{order_by: "name", exclude: ["1"]}, context)
      assert_received {:repo_all, ecto_query}
      assert inspect(ecto_query) =~ "order_by: [asc: t0.name]"
      refute inspect(ecto_query) =~ "not in"

      assert Source.get(tags, "1", context) == nil
      assert Source.id(tags, %ElementorexCms.TestTag{name: "x"}) == nil
    end

    test "get/3, id, title and url", %{source: source, context: context} do
      product = %TestProduct{id: 5, name: "Cap", slug: "blue cap"}
      Process.put(:test_repo_one, product)

      assert Source.get(source, "5", context) == product
      assert_received {:repo_one, ecto_query}
      assert inspect(ecto_query) =~ "t0.id == ^5"
      assert Source.get(source, "not-an-id", context) == nil

      assert Source.id(source, product) == 5
      assert Source.title(source, product) == "Cap"
      assert Source.url(source, product) == "/shop/blue%20cap"
      assert Source.value(source, product, "@url") == "/shop/blue%20cap"
    end
  end
end
