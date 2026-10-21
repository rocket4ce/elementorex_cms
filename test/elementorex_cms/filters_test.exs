defmodule ElementorexCms.FiltersTest do
  use ExUnit.Case, async: true

  import ElementorexCms.Builder

  alias ElementorexCms.Document
  alias ElementorexCms.Filters
  alias ElementorexCms.Renderer
  alias ElementorexCms.Source
  alias ElementorexCms.Source.Query
  alias ElementorexCms.Sources
  alias ElementorexCms.TestSource

  @sources Sources.new([TestSource])

  defp source, do: Sources.fetch(@sources, "products")

  defp html(doc, opts \\ []) do
    Renderer.to_html(doc, Keyword.merge([sources: Sources.new([TestSource])], opts))
  end

  # A filter form and the grid it filters (CSS id "catalog").
  defp shop(fields, loop_props \\ %{}) do
    card = block("card", %{}, dynamic: %{title: "name"})

    doc([
      block("filters", %{}, children: fields),
      loop("products", [card], loop_props, attrs: %{"id" => "catalog"})
    ])
  end

  defp titles(html) do
    ~r/<span[^>]*>(Red shoes|Blue shirt|Green shoes)<\/span>/
    |> Regex.scan(html, capture: :all_but_first)
    |> List.flatten()
  end

  describe "the state of a loop in the query string" do
    test "becomes filters, search and order validated against the source" do
      state = %{
        "category" => ["Shoes", " ", "Shirts"],
        "price" => %{"min" => "10000", "max" => ""},
        "featured" => "true",
        "image" => "x",
        "secret_cost" => "4000",
        "q" => " shoe ",
        "sort" => "-price",
        "page" => "2"
      }

      query =
        Filters.apply(%Query{filters: [%{field: "name", op: "set", value: ""}]}, state, source())

      assert %{field: "name", op: "set", value: ""} in query.filters
      assert %{field: "category", op: "in", value: ["Shoes", "Shirts"]} in query.filters
      assert %{field: "price", op: "gte", value: "10000"} in query.filters
      assert %{field: "featured", op: "eq", value: "true"} in query.filters
      # not filterable, or not offered at all
      refute Enum.any?(query.filters, &(&1.field in ["image", "secret_cost"]))
      refute Enum.any?(query.filters, &(&1.field == "price" and &1.op == "lte"))

      assert query.search == %{text: "shoe", fields: ~w(name description category)}
      assert {query.order_by, query.order} == {"price", :desc}
    end

    test "ranges written as min..max, and orders by fields that cannot sort are ignored" do
      query = Filters.apply(%Query{}, %{"price" => "..20000", "sort" => "category"}, source())

      assert query.filters == [%{field: "price", op: "lte", value: "20000"}]
      assert query.order_by == nil
    end

    test "custom filters of the source go as they are" do
      ecto = Source.new(ElementorexCms.TestEctoSource)
      query = Filters.apply(%Query{}, %{"in_stock" => "true"}, ecto)

      assert query.filters == [%{field: "in_stock", op: "custom", value: "true"}]
    end

    test "active?/1 tells whether anything is filtered" do
      refute Filters.active?(%{"page" => "2", "sort" => "price", "q" => " "})
      assert Filters.active?(%{"category" => ["Shoes"]})
      assert Filters.active?(%{"price" => %{"min" => "1"}})
    end
  end

  describe "links and hidden inputs" do
    @params %{
      "slug" => "shop",
      "catalog" => %{"q" => "shoe", "page" => "2"},
      "other" => %{"page" => "3", "category" => ["A", ""]}
    }

    test "href/3 keeps the loops' state and nothing else" do
      assert Filters.href(@params, "catalog", %{"page" => nil}) ==
               "?catalog[q]=shoe&other[category][]=A&other[page]=3"

      assert Filters.href(@params, "catalog", :reset) == "?other[category][]=A&other[page]=3"
      assert Filters.href(%{}, "catalog", :reset) == "?"
    end

    test "hidden_inputs/2 are the state of the other loops" do
      assert Enum.sort(Filters.hidden_inputs(@params, "catalog")) ==
               [{"other[category][]", "A"}, {"other[page]", "3"}]
    end

    test "the params of the page are kept within limits" do
      params =
        Renderer.params(%{"a" => %{"b" => %{"c" => %{"d" => "deep"}}}, "x" => 1, "y" => "ok"})

      # catalog[price][min]: two levels of maps under the page's params
      assert params == %{"a" => %{"b" => %{}}, "y" => "ok"}
    end
  end

  describe "a filter form" do
    test "filters its loop grid and shows what the visitor chose" do
      fields = [
        block("filter_search", %{placeholder: "Find…"}),
        block("filter_choice", %{field: "category", show_counts: true}),
        block("filter_range", %{field: "price", prefix: "$"}),
        block("filter_toggle", %{field: "featured", label: "Only featured"}),
        block("filter_sort", %{
          options: [%{"label" => "Cheapest", "field" => "price", "direction" => "asc"}]
        })
      ]

      html =
        html(shop(fields),
          params: %{"catalog" => %{"category" => "Shoes", "price" => %{"min" => "20000"}}}
        )

      assert titles(html) == ["Green shoes"]

      assert html =~ ~s(data-ex-filters="catalog")
      assert html =~ ~s(method="get")
      assert html =~ ~s(name="catalog[q]")
      assert html =~ ~s(placeholder="Find…")
      assert html =~ ~r/<option value="Shoes" selected>\s*Shoes \(2\)/
      assert html =~ ~s(<option value="Shirts">)
      assert html =~ ~s(name="catalog[price][min]" value="20000")
      assert html =~ ~s(name="catalog[featured]" value="true")
      assert html =~ "Only featured"
      assert html =~ ~s(<option value="price">)
      # active filters: the clear link is shown and keeps nothing of the loop
      assert html =~ ~r/<a href="\?#catalog" class="btn btn-ghost" data-ex-filters-reset>/
    end

    test "search, toggle and order" do
      fields = [block("filter_search", %{}), block("filter_toggle", %{field: "featured"})]

      assert titles(html(shop(fields), params: %{"catalog" => %{"q" => "SHIRT"}})) == [
               "Blue shirt"
             ]

      assert titles(html(shop(fields), params: %{"catalog" => %{"featured" => "true"}})) == [
               "Red shoes"
             ]

      assert titles(html(shop(fields), params: %{"catalog" => %{"sort" => "-price"}})) ==
               ["Green shoes", "Red shoes", "Blue shirt"]
    end

    test "choices: options, checkboxes and buttons" do
      checkboxes = block("filter_choice", %{field: "category", control: "checkboxes"})

      html = html(shop([checkboxes]), params: %{"catalog" => %{"category" => ["Shirts"]}})
      assert html =~ ~r/name="catalog\[category\]\[\]" value="Shirts" checked/
      assert titles(html) == ["Blue shirt"]

      manual =
        block("filter_choice", %{
          field: "category",
          control: "buttons",
          options_from: "manual",
          options: [%{"label" => "Zapatos", "value" => "Shoes"}]
        })

      html = html(shop([manual]))
      assert html =~ ~s(aria-label="Zapatos")
      refute html =~ "Shirts"
    end

    test "pages keep the filters" do
      fields = [block("filter_choice", %{field: "category"})]

      html =
        html(shop(fields, %{limit: 1, pagination: "numbers"}),
          params: %{"catalog" => %{"category" => "Shoes"}}
        )

      assert titles(html) == ["Red shoes"]
      assert html =~ ~s(href="?catalog[category]=Shoes&amp;catalog[page]=2#catalog")
    end

    test "a form keeps the state of the other loops of the page" do
      html = html(shop([block("filter_search", %{})]), params: %{"other" => %{"page" => "3"}})
      assert html =~ ~s(<input type="hidden" name="other[page]" value="3">)
    end

    test "targets a loop by node id, or the first one" do
      card = block("card", %{}, dynamic: %{title: "name"})
      first = loop("products", [card], %{}, id: "firstLoop1")
      second = loop("products", [card], %{}, id: "secondLoop")
      form = block("filters", %{target: "secondLoop"}, children: [block("filter_search", %{})])

      html = html(doc([form, first, second]))
      assert html =~ ~s(data-ex-loop="secondLoop")

      html = html(doc([block("filters", %{}, children: []), first, second]))
      assert html =~ ~s(data-ex-loop="firstLoop1")
    end

    test "without a loop grid: nothing on the site, a hint on the canvas" do
      form = doc([block("filters", %{}, children: [block("filter_search", %{})])])

      refute html(form) =~ "<form"
      assert html(form, mode: :editor) =~ "Add a loop grid to the page"

      lone = doc([block("filter_search", %{})])
      refute html(lone) =~ "<input"
      assert html(lone, mode: :editor) =~ "Put it in a Filters block"
    end

    test "copies of a form and its grid stay together" do
      grid = loop("products", [], %{}, id: "gridOne001")
      form = block("filters", %{target: "gridOne001"}, children: [])
      copy = Document.regenerate_ids(section([form, grid]))
      [form_copy, grid_copy] = copy["children"]

      refute grid_copy["id"] == "gridOne001"
      assert form_copy["props"]["target"] == grid_copy["id"]
    end
  end

  describe "sources" do
    test "values/3 of a source without values/2 come from its records" do
      assert Source.values(source(), "category", %{mode: :public, data: %{}}) ==
               [{"Shirts", 1}, {"Shoes", 2}]
    end

    test "Query.run/4 searches and takes any of several values" do
      value = fn product, key -> Map.get(product, String.to_existing_atom(key)) end
      products = TestSource.products()
      names = &Enum.map(&1, fn product -> product.name end)

      query = %Query{search: %{text: "COMFY", fields: ["description"]}}
      assert names.(Query.run(query, products, value)) == ["Red shoes"]

      query = %Query{filters: [%{field: "name", op: "in", value: ["Blue shirt", "Green shoes"]}]}
      assert names.(Query.run(query, products, value)) == ["Blue shirt", "Green shoes"]
    end

    test "Ecto: UUID keys are strings, not text to search or lowercase" do
      posts =
        Source.new(
          {ElementorexCms.Source.Ecto,
           schema: ElementorexCms.TestPost, repo: ElementorexCms.TestRepo}
        )

      assert Source.searchable(posts) == ["title"]

      uuid = Ecto.UUID.generate()

      query = %Query{
        filters: [
          %{field: "id", op: "eq", value: uuid},
          %{field: "id", op: "in", value: [uuid]},
          %{field: "id", op: "contains", value: "abc"}
        ]
      }

      Source.list(posts, query, %{mode: :public, data: %{}})
      assert_received {:repo_all, ecto_query}
      sql = inspect(ecto_query)

      refute sql =~ "lower(?)\", t0.id"
      assert sql =~ "t0.id == ^\"#{uuid}\""
      assert sql =~ "where: false"
    end

    test "Ecto: search, several values, custom filters and values" do
      source = Source.new(ElementorexCms.TestEctoSource)
      context = %{mode: :editor, data: %{}}

      assert Source.field(source, "in_stock") == nil
      assert %{custom: true, filterable: true} = Enum.find(source.fields, &(&1.key == "in_stock"))
      assert Source.searchable(source) == ~w(name slug description body_html status)

      query = %Query{
        search: %{text: "Boot", fields: ["name", "description", "stock"]},
        filters: [
          %{field: "status", op: "in", value: ["published", "nope", "draft"]},
          %{field: "name", op: "in", value: ["A", "b"]},
          %{field: "in_stock", op: "custom", value: "true"}
        ]
      }

      Source.list(source, query, context)
      assert_received {:repo_all, ecto_query}
      sql = ecto_query |> inspect() |> String.replace(~r/\s+/, " ")

      assert sql =~
               ~s|where: like(fragment("lower(?)", t0.name), ^"%boot%") or like(fragment("lower(?)", t0.description), ^"%boot%")|

      refute sql =~ "t0.stock), ^\"%boot%\""
      assert sql =~ "t0.status in ^[:published, :draft]"
      assert sql =~ ~s|fragment("lower(?)", t0.name) in ^["a", "b"]|
      assert sql =~ "t0.stock > 0"

      Process.put(:test_repo_records, [{"Shoes", 2}])
      assert Source.values(source, "name", context) == [{"Shoes", 2}]
      assert_received {:repo_all, values_query}
      assert inspect(values_query) =~ "group_by: [t0.name]"
      assert Source.values(source, "in_stock", context) == []
    end
  end
end
