defmodule ElementorexCms.DynamicTest do
  use ExUnit.Case, async: true

  import ElementorexCms.Builder

  alias ElementorexCms.Document
  alias ElementorexCms.Dynamic
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer
  alias ElementorexCms.Sources
  alias ElementorexCms.Templates
  alias ElementorexCms.TestSource

  doctest Dynamic

  @sources Sources.new([TestSource])

  defp html(doc_or_node, opts \\ []) do
    Renderer.to_html(doc_or_node, Keyword.put_new(opts, :sources, @sources))
  end

  defp product(id), do: Enum.find(TestSource.products(), &(&1.id == id))

  describe "bindings in documents" do
    test "normalize keeps valid bindings of props that can be bound" do
      node = %{
        "type" => "heading",
        "props" => %{"text" => "Name"},
        "dynamic" => %{
          "text" => %{"field" => "name", "before" => "→ ", "format" => "upper", "x" => 1},
          "level" => "name",
          "nope" => "name",
          "link" => %{"field" => "Robert'); DROP"}
        }
      }

      doc = Document.normalize(%{"root" => %{"children" => [node]}})
      [heading] = Document.root(doc)["children"]

      assert heading["dynamic"] == %{
               "text" => %{"field" => "name", "before" => "→ ", "format" => "upper"},
               "level" => %{"field" => "name"}
             }
    end

    test "lists cannot be bound and empty bindings leave no key" do
      doc =
        Document.normalize(%{
          "root" => %{
            "children" => [%{"type" => "list", "dynamic" => %{"items" => "name"}}]
          }
        })

      refute Map.has_key?(hd(Document.root(doc)["children"]), "dynamic")
    end

    test "site bindings only take top-level keys" do
      assert Dynamic.normalize_binding(%{"field" => "site_name", "from" => "site"}) ==
               %{"field" => "site_name", "from" => "site"}

      assert Dynamic.normalize_binding(%{"field" => "user.email", "from" => "site"}) == nil
      assert Dynamic.normalize_binding(%{"field" => "@url", "from" => "site"}) == nil
    end

    test "put_binding/5 and drop_binding/3" do
      doc = doc([block("button", %{}, id: "b1")])

      {:ok, doc} = Document.put_binding(doc, "b1", "url", "@url")
      {:ok, doc} = Document.put_binding(doc, "b1", "label", %{field: "name", after: "!"})
      assert Document.get(doc, "b1")["dynamic"]["label"] == %{"field" => "name", "after" => "!"}

      assert Document.put_binding(doc, "b1", "label", %{field: "bad field"}) == {:error, :invalid}
      assert Document.put_binding(doc, "b1", "nope", "name") == {:error, :invalid}
      assert Document.put_binding(doc, "missing", "label", "name") == {:error, :not_found}

      {:ok, doc} = Document.drop_binding(doc, "b1", "url")
      {:ok, doc} = Document.drop_binding(doc, "b1", "label")
      refute Map.has_key?(Document.get(doc, "b1"), "dynamic")
    end

    test "the builder takes dynamic: and loop/4" do
      node =
        loop("products", [block("heading", %{}, dynamic: %{text: [field: "name"]})], %{limit: 2})

      assert node["type"] == "loop"
      assert node["props"]["source"] == "products"
      assert node["props"]["limit"] == 2
      assert hd(node["children"])["dynamic"] == %{"text" => %{"field" => "name"}}
    end
  end

  describe "rendering with a record" do
    test "bound props take the values of the record, cast and sanitized" do
      doc =
        doc([
          block("heading", %{text: "Placeholder"}, dynamic: %{text: "description"}),
          block("text", %{}, dynamic: %{text: "description"}),
          block("image", %{}, dynamic: %{src: "image", alt: "name"}),
          block("button", %{label: "Buy"}, dynamic: %{url: "@url"}),
          block("badge", %{}, dynamic: %{text: [field: "price", before: "$", format: "number"]})
        ])

      html = html(doc, record: product(1), source: "products")

      # plain text is escaped, inline headings keep one line, rich text gets paragraphs
      assert html =~ "Light &amp; comfy. For &lt;every&gt; day."
      assert html =~ "<p>Light &amp; comfy.</p><p>For &lt;every&gt; day.</p>"
      assert html =~ ~s(src="https://cdn.example.com/red.jpg")
      assert html =~ ~s(alt="Red shoes")
      assert html =~ ~s(href="/shop/red-shoes")
      assert html =~ "$19,990"
      refute html =~ "Placeholder"
    end

    test "the source is found from the record's schema" do
      sources = Sources.new([ElementorexCms.TestEctoSource])
      product = %ElementorexCms.TestProduct{name: "Cap", slug: "cap", password_hash: "secret"}

      doc =
        doc([
          block("heading", %{}, dynamic: %{text: "name"}),
          block("text", %{text: "<p>Static</p>"}, dynamic: %{text: "password_hash"})
        ])

      html = Renderer.to_html(doc, sources: sources, record: product)

      assert html =~ "Cap"
      # a field the source does not offer is never read
      refute html =~ "secret"
      refute html =~ "Static"
    end

    test "fallback, before and after, formats and locales" do
      heading = fn binding ->
        doc([block("heading", %{text: "x"}, dynamic: %{text: binding})])
        |> html(record: product(3), source: "products")
      end

      assert heading.(field: "description", fallback: "No description") =~ "No description"
      assert heading.(field: "price", before: "From ", after: " CLP") =~ "From 29990 CLP"

      es =
        html(doc([block("heading", %{}, dynamic: %{text: [field: "price", format: "number"]})]),
          record: product(3),
          source: "products",
          locale: "es"
        )

      assert es =~ "29.990"

      date =
        doc([block("heading", %{}, dynamic: %{text: [field: "released_on", format: "date"]})])
        |> html(record: product(1), source: "products")

      assert date =~ "Mar 1, 2026"
    end

    test "rich text fields keep their markup, sanitized" do
      prop = ElementorexCms.Block.find_prop(ElementorexCms.Blocks.Text, :text)
      field = ElementorexCms.Source.Field.new(:body_html, type: :html)
      html = "<p>Hi <b>there</b></p><script>x</script>"

      # text around the value goes in paragraphs of its own (no empty ones)
      assert Dynamic.to_prop(html, field, %{"after" => "Bye"}, prop) == html <> "<p>Bye</p>"

      sources =
        Sources.new([
          {ElementorexCms.Source.Ecto,
           schema: ElementorexCms.TestProduct, fields: [description: [type: :html]]}
        ])

      rendered =
        Renderer.to_html(doc([block("text", %{}, dynamic: %{text: "description"})]),
          sources: sources,
          record: %ElementorexCms.TestProduct{description: html}
        )

      assert rendered =~ "<p>Hi <b>there</b></p>"
      refute rendered =~ "<script>"
    end

    test "number and boolean props get numbers and booleans" do
      doc =
        doc([
          block("progress", %{}, dynamic: %{value: "price"}),
          block("card", %{title: "Card"}, dynamic: %{centered: "featured"})
        ])

      assert html(doc, record: product(1), source: "products") =~ "items-center text-center"
      refute html(doc, record: product(2), source: "products") =~ "items-center text-center"
    end

    test "without a record the props keep their own values" do
      doc = doc([block("heading", %{text: "Placeholder"}, dynamic: %{text: "name"})])
      assert html(doc) =~ "Placeholder"
    end

    test "site values come from data, never from structs" do
      doc =
        doc([
          block("heading", %{}, dynamic: %{text: [field: "site_name", from: "site"]}),
          block("text", %{text: "<p>Static</p>"}, dynamic: %{text: [field: "user", from: "site"]})
        ])

      html = html(doc, data: %{site_name: "My shop", user: %{email: "a@b.c"}})

      assert html =~ "My shop"
      refute html =~ "a@b.c"
      assert html =~ "Static"
    end

    test "inline editing is off for bound props on the canvas" do
      doc = doc([block("heading", %{text: "x"}, id: "h1", dynamic: %{text: "name"})])
      html = html(doc, mode: :editor)

      refute html =~ ~s(data-ex-inline="text")
    end
  end

  describe "the loop grid" do
    defp grid(props \\ %{}, opts \\ []) do
      card = block("card", %{title: "Title"}, dynamic: %{title: "name", button_url: "@url"})
      doc([loop(Map.get(props, :source, "products"), [card], props, opts)])
    end

    test "repeats its content for every item" do
      html = html(grid())

      assert html =~ "Red shoes"
      assert html =~ "Blue shirt"
      assert html =~ "Green shoes"
      assert html =~ ~s(href="/shop/blue-shirt")
      assert length(Regex.scan(~r/data-ex-loop-item=/, html)) == 3
      refute html =~ "data-ex-loop-copy"
    end

    test "limit, order and filters" do
      html =
        html(
          grid(%{
            limit: 1,
            order_by: "price",
            order: "desc",
            filters: [%{"field" => "category", "op" => "eq", "value" => "Shoes"}]
          })
        )

      assert html =~ "Green shoes"
      refute html =~ "Red shoes"
      refute html =~ "Blue shirt"
    end

    test "related items in the template of one item" do
      related =
        grid(%{
          exclude_current: true,
          filters: [%{"field" => "category", "op" => "same", "value" => ""}]
        })

      html = html(related, record: product(1), source: "products")

      assert html =~ "Green shoes"
      refute html =~ "Red shoes"
      refute html =~ "Blue shirt"
    end

    test "the text for no items, and nothing for unknown sources" do
      none = grid(%{filters: [%{"field" => "name", "op" => "eq", "value" => "zzz"}]})
      assert html(none) =~ "Nothing to show yet."

      unknown = grid(%{source: "ghosts"})
      refute html(unknown) =~ "Title"
    end

    test "on the canvas the first item is edited and the others are copies" do
      html = html(grid(), mode: :editor)

      assert length(Regex.scan(~r/data-ex-loop-copy="true"/, html)) == 2
      # copies keep the node ids, so the styles of the node apply to them
      assert length(Regex.scan(~r/data-ex-type="card"/, html)) == 3
    end

    test "on the canvas a loop without items shows its content once with a hint" do
      html = html(grid(%{source: "ghosts"}), mode: :editor)

      assert html =~ "Title"
      assert html =~ "exr-loop-hint"
      assert html =~ "Choose a collection"
    end

    test "CSS ids of the copies get a suffix" do
      card = block("card", %{}, attrs: %{"id" => "promo"})
      html = html(doc([loop("products", [card])]))

      assert html =~ ~s(id="promo")
      assert html =~ ~s(id="promo-2")
      assert html =~ ~s(id="promo-3")
    end

    test "loops render inside one other loop at most" do
      inner = fn children -> loop("products", children, %{limit: 2}) end

      deep =
        doc([
          inner.([
            inner.([
              block("heading", %{text: "Second"}),
              inner.([block("heading", %{text: "Third"})])
            ])
          ])
        ])

      html = html(deep)
      assert length(Regex.scan(~r/Second/, html)) == 4
      refute html =~ "Third"
    end

    test "passes the host's data to the source" do
      html(grid(), data: %{test_pid: self()})
      assert_received {:source_query, %ElementorexCms.Source.Query{limit: 6}}
    end
  end

  describe "pagination" do
    defp paged(props, opts \\ []) do
      card = block("card", %{}, dynamic: %{title: "name"})
      attrs = Keyword.get(opts, :attrs, %{"id" => "grid"})

      doc([
        loop(Map.get(props, :source, "products"), [card], Map.put_new(props, :limit, 1),
          attrs: attrs
        )
      ])
      |> html(
        Keyword.take(opts, [:mode])
        |> Keyword.put(:params, Keyword.get(opts, :params, %{}))
        |> Keyword.put(:sources, Sources.new([TestSource, ElementorexCms.TestUncountedSource]))
      )
    end

    defp titles(html) do
      ~r/<span[^>]*>(Red shoes|Blue shirt|Green shoes)<\/span>/
      |> Regex.scan(html, capture: :all_but_first)
      |> List.flatten()
    end

    test "numbers: the page comes from the params and the links keep the other loops" do
      html =
        paged(%{pagination: "numbers"},
          params: %{"grid" => %{"page" => "2"}, "other" => %{"page" => "3"}, "slug" => "shop"}
        )

      assert titles(html) == ["Blue shirt"]
      assert html =~ ~s(aria-current="page")
      assert html =~ ~s(href="?other[page]=3#grid")
      assert html =~ ~s(href="?grid[page]=3&amp;other[page]=3#grid")
      refute html =~ "slug"
      refute html =~ "Previous"
    end

    test "numbers: past the last page shows the last one" do
      html = paged(%{pagination: "numbers_prev_next"}, params: %{"grid" => %{"page" => "9"}})

      assert titles(html) == ["Green shoes"]
      assert html =~ ~s(href="?grid[page]=2#grid")
      assert html =~ ~s(<span class="join-item btn btn-sm btn-disabled">)
    end

    test "numbers with a page limit" do
      html = paged(%{pagination: "numbers", page_limit: 2})

      assert html =~ ~s(href="?grid[page]=2#grid")
      refute html =~ "grid[page]=3"
    end

    test "previous and next, and numbers of a source that cannot count" do
      first = paged(%{pagination: "prev_next"})
      assert titles(first) == ["Red shoes"]
      assert first =~ ~s(href="?grid[page]=2#grid")
      assert first =~ "Next"
      refute first =~ ~s(rel="prev")

      uncounted =
        paged(%{source: "uncounted", pagination: "numbers"},
          params: %{"grid" => %{"page" => "3"}}
        )

      assert titles(uncounted) == ["Green shoes"]
      assert uncounted =~ ~s(rel="prev")
      refute uncounted =~ ~s(rel="next")
      refute uncounted =~ "aria-current"
    end

    test "page numbers from the address are bounded" do
      html =
        paged(%{source: "uncounted", pagination: "prev_next"},
          params: %{"grid" => %{"page" => "99999999999999999999999"}}
        )

      assert html =~ ~s(href="?grid[page]=9999#grid")

      for junk <- ["-2", "abc", "2.5", ""] do
        assert titles(paged(%{pagination: "numbers"}, params: %{"grid" => %{"page" => junk}})) ==
                 [
                   "Red shoes"
                 ]
      end
    end

    test "past the end without a count: the empty text and a way back" do
      html =
        paged(%{source: "uncounted", pagination: "prev_next"},
          params: %{"grid" => %{"page" => "8"}}
        )

      assert html =~ "Nothing to show yet."
      assert html =~ ~s(href="?grid[page]=7#grid")
    end

    test "load more and infinite scroll link to the next page" do
      html = paged(%{pagination: "load_more"})

      assert html =~ ~s(data-ex-loop-more="click")
      assert html =~ ~s(data-ex-next="?grid[page]=2")
      assert html =~ ~s(href="?grid[page]=2#grid")

      # items are numbered across pages, the last page has no button
      last = paged(%{pagination: "load_more"}, params: %{"grid" => %{"page" => "3"}})
      assert last =~ ~s(data-ex-loop-item="2")
      refute last =~ "data-ex-loop-more"

      assert paged(%{pagination: "infinite"}) =~ ~s(data-ex-loop-more="scroll")
    end

    test "without a CSS id the node id names the param and the anchor" do
      card = block("card", %{}, dynamic: %{title: "name"})
      grid = loop("products", [card], %{limit: 1, pagination: "numbers"}, id: "shopGrid01")
      html = html(doc([grid]), params: %{"shopGrid01" => %{"page" => "2"}})

      assert titles(html) == ["Blue shirt"]
      assert html =~ ~s(id="loop-shopGrid01")
      assert html =~ ~s(href="?shopGrid01[page]=3#loop-shopGrid01")
    end

    test "loops inside loops have no pages" do
      inner =
        loop("products", [block("heading", %{}, dynamic: %{text: "name"})], %{
          limit: 1,
          pagination: "numbers"
        })

      html = html(doc([loop("products", [inner], %{limit: 1})]))

      refute html =~ "data-ex-loop-pages"
    end

    test "the canvas shows the pagination to style it" do
      editor = paged(%{pagination: "numbers", limit: 5}, mode: :editor)
      assert editor =~ "data-ex-loop-pages"

      assert paged(%{pagination: "infinite", limit: 5}, mode: :editor) =~
               "More items load as the visitor scrolls"

      # on the site a single page needs no links
      refute paged(%{pagination: "numbers", limit: 5}) =~ "data-ex-loop-pages"
    end
  end

  describe "display conditions" do
    test "are normalized with the advanced attributes" do
      attrs = %{"condition" => %{"field" => "stock", "op" => "lte", "value" => 0, "x" => 1}}

      assert Document.normalize_attrs(attrs) == %{
               "condition" => %{"field" => "stock", "op" => "lte", "value" => ""}
             }

      assert Document.normalize_attrs(%{"condition" => %{"field" => "stock", "op" => "drop"}}) ==
               %{}

      assert Document.normalize_attrs(%{"condition" => %{"field" => "", "op" => "eq"}}) == %{}
    end

    test "nodes show only for the items that match" do
      featured =
        block("badge", %{text: "Featured!"},
          attrs: %{"condition" => %{"field" => "featured", "op" => "eq", "value" => "true"}}
        )

      no_image =
        block("badge", %{text: "No photo"},
          attrs: %{"condition" => %{"field" => "image", "op" => "unset", "value" => ""}}
        )

      html =
        html(
          doc([
            loop("products", [block("heading", %{}, dynamic: %{text: "name"}), featured, no_image])
          ])
        )

      assert length(Regex.scan(~r/Featured!/, html)) == 1
      assert length(Regex.scan(~r/No photo/, html)) == 1

      # a template of one item
      assert html(doc([featured]), record: product(1), source: "products") =~ "Featured!"
      refute html(doc([featured]), record: product(2), source: "products") =~ "Featured!"
      # without an item there is nothing to check: shown
      assert html(doc([featured])) =~ "Featured!"
    end

    test "on the canvas the nodes are dimmed instead of removed" do
      badge =
        block("badge", %{text: "Featured!"},
          attrs: %{"condition" => %{"field" => "featured", "op" => "eq", "value" => "true"}}
        )

      html = html(doc([loop("products", [badge])]), mode: :editor)

      assert length(Regex.scan(~r/Featured!/, html)) == 3
      assert length(Regex.scan(~r/data-ex-off="true"/, html)) == 2
    end
  end

  describe "templates" do
    test "made from the fields of each source" do
      [single, grid, filtered, list] = Templates.for_sources(@sources, "products")

      assert single.key == "source:products:single"
      assert grid.key == "source:products:grid"
      assert filtered.key == "source:products:filtered"
      assert list.key == "source:products:list"

      for template <- [single, grid, filtered, list] do
        html = html(doc(template.nodes.()), record: product(1), source: "products")
        assert html =~ "Red shoes"
      end
    end

    test "the grid with filters: its form filters its own grid" do
      [section] =
        Templates.for_sources(@sources)
        |> Enum.find(&(&1.key == "source:products:filtered"))
        |> then(& &1.nodes.())

      [_heading, form, grid] = section["children"]

      assert form["type"] == "filters"
      assert form["props"]["target"] == grid["id"]

      assert Enum.map(form["children"], & &1["type"]) ==
               ~w(filter_search filter_choice filter_range filter_toggle filter_sort)

      key = grid["id"]
      html = html(doc([section]), params: %{key => %{"category" => "Shirts"}})
      assert html =~ "Blue shirt"
      refute html =~ "Red shoes"
    end

    test "available/3 leaves out templates of missing sources" do
      defmodule Shop do
        @behaviour ElementorexCms.Templates
        def templates do
          [
            %{key: "a", label: "A", source: "products", nodes: fn -> [] end},
            %{key: "b", label: "B", source: "ghosts", nodes: fn -> [] end}
          ]
        end
      end

      keys = Templates.available([Shop], @sources) |> Enum.map(& &1.key)

      assert "a" in keys
      refute "b" in keys
      assert "source:products:grid" in keys
      refute "source:products:single" in keys
      assert hd(Templates.available([Shop], @sources, "products")).key == "source:products:single"
    end
  end

  test "the loop block is in the dynamic category" do
    assert Registry.fetch(Registry.default(), "loop").meta().category == :dynamic
  end
end
