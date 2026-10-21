defmodule ElementorexCms.EditorDynamicTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.LiveViewTest

  alias ElementorexCms.Builder
  alias ElementorexCms.Document

  @endpoint ElementorexCms.TestEndpoint

  defp mount_editor(opts) do
    doc =
      Keyword.get_lazy(opts, :document, fn ->
        Builder.doc([
          Builder.block("heading", %{text: "Title"}, id: "title1"),
          Builder.loop(
            "products",
            [Builder.block("heading", %{text: "Name"}, id: "name1")],
            %{filters: [%{"field" => "name", "op" => "contains", "value" => "s"}]},
            id: "loop1"
          )
        ])
      end)

    session = %{
      "test_pid" => self(),
      "document" => doc,
      "sources" => Keyword.get(opts, :sources, [ElementorexCms.TestSource]),
      "source" => opts[:source],
      "data" => Keyword.get(opts, :data, %{})
    }

    {:ok, view, _html} =
      live_isolated(build_conn(), ElementorexCms.TestEditorLive, session: session)

    view
  end

  defp hook(view, event, payload \\ %{}),
    do: view |> element("#editor") |> render_hook(event, payload)

  defp last_change(last \\ nil) do
    receive do
      {:changed, doc} -> last_change(doc)
    after
      50 -> last
    end
  end

  # The last HTML pushed to the canvas.
  defp canvas(view, last \\ nil) do
    %{proxy: {ref, _topic, _pid}} = view

    receive do
      {^ref, {:push_event, "exr:editor:render", %{html: html}}} -> canvas(view, html)
    after
      50 -> last
    end
  end

  test "without sources the loop is not offered" do
    view = mount_editor(sources: [], document: Builder.doc([]))

    refute has_element?(view, ~s([data-exr-block="loop"]))
    assert has_element?(view, ~s([data-exr-block="heading"]))
  end

  test "with sources: the palette, the tree and the loop's own settings" do
    view = mount_editor([])

    assert has_element?(view, ~s([data-exr-block="loop"]))
    assert has_element?(view, ~s([data-exr-tree-id="loop1"] .exr-tree-tag), "Products")

    hook(view, "select", %{"id" => "loop1"})

    assert has_element?(view, ~s(select[name="props[source]"] option[value="products"][selected]))
    assert has_element?(view, ~s(select[name="props[order_by]"] option[value="price"]))
    # only sortable fields can order
    refute has_element?(view, ~s(select[name="props[order_by]"] option[value="image"]))
    # filters are titled by the name of their field
    assert has_element?(view, ".exr-rep-title", "Name")

    assert has_element?(
             view,
             ~s(select[name="props[filters][0][field]"] option[value="category"])
           )
  end

  test "pagination: the options of each kind and the preview on the canvas" do
    view = mount_editor([])
    hook(view, "canvas_ready")
    canvas(view)
    hook(view, "select", %{"id" => "loop1"})

    assert has_element?(view, ~s(select[name="props[pagination]"] option[value="infinite"]))
    refute has_element?(view, ~s(input[name="props[page_limit]"]))

    hook(view, "props", %{
      "_target" => ["props", "pagination"],
      "node" => "loop1",
      "props" => %{"pagination" => "numbers_prev_next"}
    })

    assert Document.get(last_change(), "loop1")["props"]["pagination"] == "numbers_prev_next"
    assert has_element?(view, ~s(input[name="props[page_limit]"]))
    assert has_element?(view, ~s(input[name="props[prev_label]"]))
    refute has_element?(view, ~s(input[name="props[more_label]"]))
    assert canvas(view) =~ "data-ex-loop-pages"

    hook(view, "props", %{
      "_target" => ["props", "pagination"],
      "node" => "loop1",
      "props" => %{"pagination" => "load_more"}
    })

    assert has_element?(view, ~s(input[name="props[more_label]"]))
    assert canvas(view) =~ ~s(data-ex-loop-more="click")
  end

  test "filter forms: their loop grid and the fields of its source" do
    doc =
      Builder.doc([
        Builder.block("filters", %{},
          id: "form1",
          children: [
            Builder.block("filter_choice", %{}, id: "choice1"),
            Builder.block("filter_sort", %{options: [%{"label" => "Price"}]}, id: "sort1")
          ]
        ),
        Builder.loop("products", [], %{}, id: "loop1", attrs: %{"label" => "Catalog"})
      ])

    view = mount_editor(document: doc)
    hook(view, "canvas_ready")
    assert canvas(view) =~ ~s(data-ex-filters="loop1")

    hook(view, "select", %{"id" => "form1"})
    assert has_element?(view, ~s(select[name="props[target]"] option[value="loop1"]), "Catalog")

    hook(view, "select", %{"id" => "choice1"})
    assert has_element?(view, ~s(select[name="props[field]"] option[value="category"]))
    assert has_element?(view, ~s(select[name="props[field]"] option[value="featured"]))
    refute has_element?(view, ~s(select[name="props[field]"] option[value="image"]))

    hook(view, "props", %{
      "_target" => ["props", "field"],
      "node" => "choice1",
      "props" => %{"field" => "category"}
    })

    assert canvas(view) =~ ~s(name="loop1[category]")

    # the options of a sort choose among the sortable fields
    hook(view, "select", %{"id" => "sort1"})
    assert has_element?(view, ~s(select[name="props[options][0][field]"] option[value="price"]))

    refute has_element?(
             view,
             ~s(select[name="props[options][0][field]"] option[value="category"])
           )
  end

  test "a new loop starts with the first source" do
    view = mount_editor(document: Builder.doc([]))
    hook(view, "add", %{"type" => "loop"})

    [loop] = Document.root(last_change())["children"]
    assert loop["props"]["source"] == "products"
  end

  test "binding a prop inside a loop to a field of its items" do
    view = mount_editor([])
    hook(view, "canvas_ready")
    assert canvas(view) =~ "Name"

    hook(view, "select", %{"id" => "name1"})
    assert has_element?(view, ".exr-dyn-scope", "Item of Products")
    assert has_element?(view, ~s([data-exr-dyn="text"]))

    hook(view, "dynamic_open", %{"prop" => "text"})
    assert has_element?(view, ~s(#exr-field-picker [data-exr-field="name"].is-suggested))
    assert has_element?(view, ~s(#exr-field-picker [data-exr-field="@url"]))

    hook(view, "dynamic_pick", %{"field" => "name", "from" => "item"})
    refute has_element?(view, "#exr-field-picker")

    doc = last_change()
    assert Document.get(doc, "name1")["dynamic"] == %{"text" => %{"field" => "name"}}
    assert has_element?(view, ".exr-binding b", "Name")

    html = canvas(view)
    assert html =~ "Red shoes"
    assert html =~ "Blue shirt"
    assert html =~ ~s(data-ex-loop-copy="true")
  end

  test "binding settings, defaults of the field and removing the binding" do
    view = mount_editor([])
    hook(view, "select", %{"id" => "name1"})
    hook(view, "dynamic_open", %{"prop" => "text"})
    hook(view, "dynamic_pick", %{"field" => "price", "from" => "item"})

    # the field's defaults come with it
    assert Document.get(last_change(), "name1")["dynamic"]["text"] == %{
             "field" => "price",
             "before" => "$",
             "format" => "number",
             "decimals" => 0
           }

    hook(view, "props", %{
      "_target" => ["dynamic", "text", "after"],
      "node" => "name1",
      "dynamic" => %{"text" => %{"before" => "", "after" => " CLP", "format" => "number"}}
    })

    assert Document.get(last_change(), "name1")["dynamic"]["text"] == %{
             "field" => "price",
             "after" => " CLP",
             "format" => "number"
           }

    assert canvas(view) =~ "19,990 CLP"

    hook(view, "dynamic_clear", %{"prop" => "text"})
    refute Map.has_key?(Document.get(last_change(), "name1"), "dynamic")
    assert has_element?(view, ~s(textarea[name="props[text]"]))
  end

  test "a display condition from the Advanced tab" do
    view = mount_editor([])
    hook(view, "select", %{"id" => "name1"})
    hook(view, "tab", %{"tab" => "advanced"})

    assert has_element?(view, ~s(select[name="attrs[condition][field]"] option[value="featured"]))

    hook(view, "attrs", %{
      "_target" => ["attrs", "condition", "field"],
      "node" => "name1",
      "attrs" => %{"condition" => %{"field" => "featured"}}
    })

    assert Document.get(last_change(), "name1")["attrs"]["condition"] ==
             %{"field" => "featured", "op" => "eq", "value" => ""}

    hook(view, "attrs", %{
      "_target" => ["attrs", "condition", "value"],
      "node" => "name1",
      "attrs" => %{"condition" => %{"field" => "featured", "op" => "eq", "value" => "true"}}
    })

    assert canvas(view) =~ ~s(data-ex-off="true")
    assert has_element?(view, ~s([data-exr-tree-id="name1"] .exr-tree-dyn))

    hook(view, "attrs", %{
      "_target" => ["attrs", "condition", "field"],
      "node" => "name1",
      "attrs" => %{"condition" => %{"field" => ""}}
    })

    refute Map.has_key?(Document.get(last_change(), "name1")["attrs"], "condition")
  end

  test "fields that are not offered cannot be bound" do
    view = mount_editor([])
    hook(view, "select", %{"id" => "name1"})
    hook(view, "dynamic_open", %{"prop" => "text"})
    hook(view, "dynamic_pick", %{"field" => "secret_cost", "from" => "item"})

    refute last_change()
  end

  test "outside a loop, only site values can be bound" do
    view = mount_editor(data: %{site_name: "My shop", user: %{id: 1}})
    hook(view, "select", %{"id" => "title1"})
    refute has_element?(view, ".exr-dyn-scope")

    hook(view, "dynamic_open", %{"prop" => "text"})
    assert has_element?(view, ~s(#exr-field-picker [data-exr-field="site_name"]))
    refute has_element?(view, ~s(#exr-field-picker [data-exr-field="user"]))
    refute has_element?(view, ~s(#exr-field-picker [data-exr-field="name"]))

    hook(view, "dynamic_pick", %{"field" => "site_name", "from" => "site"})
    assert Document.get(last_change(), "title1")["dynamic"]["text"]["from"] == "site"
    assert canvas(view) =~ "My shop"
  end

  test "a template of a source: bind to its fields and pick the item to preview" do
    view = mount_editor(source: "products")
    hook(view, "canvas_ready")
    canvas(view)

    assert has_element?(view, ~s(select[name="record"] option), "Red shoes")

    hook(view, "select", %{"id" => "title1"})
    assert has_element?(view, ".exr-dyn-scope", "Item of Products")
    hook(view, "dynamic_open", %{"prop" => "text"})
    hook(view, "dynamic_pick", %{"field" => "name", "from" => "item"})
    assert canvas(view) =~ ~r/<span[^>]*>Red shoes<\/span>/

    view |> element("form[phx-change=preview_record]") |> render_change(%{"record" => "2"})
    assert canvas(view) =~ ~r/<span[^>]*>Blue shirt<\/span>/
  end

  test "templates made from the sources" do
    view = mount_editor(source: "products", document: Builder.doc([]))
    hook(view, "panel", %{"panel" => "templates"})

    assert has_element?(view, ".exr-template-group", "Dynamic content")
    assert has_element?(view, ~s(.exr-template.is-dynamic[phx-value-key="source:products:grid"]))

    hook(view, "apply_template", %{"key" => "source:products:single"})
    doc = last_change()

    assert Enum.any?(Document.nodes(doc), &(&1["type"] == "loop"))
    assert Enum.any?(Document.nodes(doc), &(&1["dynamic"]["text"]["field"] == "name"))
  end
end
