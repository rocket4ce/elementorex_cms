defmodule ElementorexCms.DocumentTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.Document
  alias ElementorexCms.Registry

  setup do
    registry = Registry.default()
    heading = Document.node("heading", %{"text" => "Hello"}, registry: registry, id: "heading1")
    button = Document.node("button", %{}, registry: registry, id: "button1")
    column = Document.node("container", %{}, registry: registry, id: "column1", children: [])
    doc = Document.new([heading, column, button])
    %{doc: doc, registry: registry, root: Document.root(doc)["id"]}
  end

  describe "node/3" do
    test "fills defaults and default children from the block", %{registry: registry} do
      grid = Document.node("grid", %{}, registry: registry)

      assert grid["props"]["columns"] == "2"
      assert [%{"type" => "container"}, %{"type" => "container"}] = grid["children"]
    end

    test "applies the block's default style", %{registry: registry} do
      section = Document.node("section", %{}, registry: registry)
      assert section["style"]["desktop"]["padding-top"] == "24px"
    end
  end

  describe "queries" do
    test "get/2, path/2 and parent/2", %{doc: doc, root: root} do
      assert Document.get(doc, "button1")["type"] == "button"
      assert Document.get(doc, "nope") == nil
      assert Enum.map(Document.path(doc, "button1"), & &1["id"]) == [root, "button1"]
      assert {:ok, %{"id" => ^root}, 2} = Document.parent(doc, "button1")
      assert Document.parent(doc, root) == :error
    end

    test "count/1 and nodes/1", %{doc: doc} do
      assert Document.count(doc) == 4

      assert doc |> Document.nodes() |> Enum.map(& &1["type"]) ==
               ~w(root heading container button)
    end
  end

  describe "insert/5" do
    test "inserts into a container at the index", %{doc: doc, registry: registry} do
      badge = Document.node("badge", %{}, registry: registry, id: "badge1")
      {:ok, doc} = Document.insert(doc, badge, "column1", 0, registry)

      assert Document.parent(doc, "badge1") |> elem(1) |> Map.get("id") == "column1"
    end

    test "clamps the index", %{doc: doc, registry: registry, root: root} do
      badge = Document.node("badge", %{}, registry: registry, id: "badge1")
      {:ok, doc} = Document.insert(doc, badge, root, 99, registry)

      assert {:ok, _, 3} = Document.parent(doc, "badge1")
    end

    test "refuses leaf parents", %{doc: doc, registry: registry} do
      badge = Document.node("badge", %{}, registry: registry)
      assert Document.insert(doc, badge, "heading1", 0, registry) == {:error, :not_allowed}
    end

    test "gives new ids to nodes whose ids are taken", %{doc: doc, registry: registry, root: root} do
      copy = Document.get(doc, "heading1")
      {:ok, doc} = Document.insert(doc, copy, root, 0, registry)

      ids = doc |> Document.nodes() |> Enum.map(& &1["id"])
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  describe "move/5" do
    test "moves inside the same parent counting the node itself", %{
      doc: doc,
      registry: registry,
      root: root
    } do
      # heading1 is at 0; dropping it after button1 (index 3 of the current list)
      {:ok, doc} = Document.move(doc, "heading1", root, 3, registry)

      assert doc |> Document.root() |> Map.fetch!("children") |> Enum.map(& &1["id"]) ==
               ~w(column1 button1 heading1)
    end

    test "moves into another container", %{doc: doc, registry: registry} do
      {:ok, doc} = Document.move(doc, "button1", "column1", 0, registry)
      assert {:ok, %{"id" => "column1"}, 0} = Document.parent(doc, "button1")
    end

    test "is a no-op when dropped where it is", %{doc: doc, registry: registry, root: root} do
      assert {:ok, ^doc} = Document.move(doc, "column1", root, 1, registry)
      assert {:ok, ^doc} = Document.move(doc, "column1", root, 2, registry)
    end

    test "cannot move a node inside itself or the root", %{
      doc: doc,
      registry: registry,
      root: root
    } do
      assert Document.move(doc, "column1", "column1", 0, registry) == {:error, :into_itself}
      assert Document.move(doc, root, "column1", 0, registry) == {:error, :root}
    end
  end

  test "remove/2 and duplicate/3", %{doc: doc, registry: registry, root: root} do
    {:ok, without} = Document.remove(doc, "heading1")
    refute Document.get(without, "heading1")
    assert Document.remove(doc, root) == {:error, :root}
    assert Document.remove(doc, "nope") == {:error, :not_found}

    {:ok, doubled, copy_id} = Document.duplicate(doc, "heading1", registry)
    assert copy_id != "heading1"
    assert {:ok, _, 1} = Document.parent(doubled, copy_id)
    assert Document.get(doubled, copy_id)["props"]["text"] == "Hello"
  end

  describe "put_style/5" do
    test "stores valid values per state and removes empty ones", %{doc: doc} do
      {:ok, doc} = Document.put_style(doc, "heading1", "mobile", "font-size", "20px")
      assert Document.get(doc, "heading1")["style"] == %{"mobile" => %{"font-size" => "20px"}}

      {:ok, doc} = Document.put_style(doc, "heading1", "mobile", "font-size", "")
      assert Document.get(doc, "heading1")["style"] == %{}
    end

    test "rejects invalid values and unknown states", %{doc: doc} do
      assert Document.put_style(doc, "heading1", "desktop", "color", "red;}body{") ==
               {:error, :invalid}

      assert Document.put_style(doc, "heading1", "print", "color", "red") == {:error, :invalid}
    end

    test "keeps shadow presets by name", %{doc: doc} do
      {:ok, doc} = Document.put_style(doc, "button1", "hover", "box-shadow", "lg")
      assert Document.get(doc, "button1")["style"]["hover"]["box-shadow"] == "lg"
    end
  end

  test "put_attr/4 validates advanced settings", %{doc: doc} do
    {:ok, doc} = Document.put_attr(doc, "heading1", "id", "1bad id")
    refute Map.has_key?(Document.get(doc, "heading1")["attrs"], "id")

    {:ok, doc} =
      Document.put_attr(doc, "heading1", "class", "shadow-lg exr-hack md:p-4 \"><script>")

    assert Document.get(doc, "heading1")["attrs"]["class"] == "shadow-lg md:p-4"

    {:ok, doc} = Document.put_attr(doc, "heading1", "hide_on", ["mobile", "tv"])
    assert Document.get(doc, "heading1")["attrs"]["hide_on"] == ["mobile"]
  end

  describe "normalize/2" do
    test "repairs broken documents" do
      doc =
        Document.normalize(%{
          "root" => %{
            "type" => "anything",
            "children" => [
              %{
                "id" => "bad id\"]",
                "type" => "heading",
                "props" => %{"text" => "<script>x</script>Hi", "level" => "h9"}
              },
              %{"id" => "same", "type" => "button", "children" => [%{"type" => "text"}]},
              %{
                "id" => "same",
                "type" => "text",
                "style" => %{"desktop" => %{"color" => "red", "behavior" => "x"}, "print" => %{}}
              },
              "not a node"
            ]
          }
        })

      [heading, button, text] = Document.root(doc)["children"]
      assert Document.root(doc)["type"] == "root"
      assert heading["id"] =~ ~r/\A[A-Za-z0-9]{10}\z/
      assert heading["props"] == %{"text" => "Hi", "level" => "h2"}
      assert button["children"] == []
      assert text["id"] != button["id"]
      assert text["style"] == %{"desktop" => %{"color" => "red"}}
    end

    test "keeps unknown blocks with their content" do
      doc =
        Document.normalize(%{
          "root" => %{"children" => [%{"type" => "legacy", "props" => %{"x" => 1}}]}
        })

      assert [%{"type" => "legacy", "props" => %{"x" => 1}}] = Document.root(doc)["children"]
    end

    test "accepts JSON and atom keys, and falls back to an empty document" do
      assert %{"root" => %{"type" => "root"}} = Document.normalize(~s({"root": {"children": []}}))

      assert %{"root" => %{"children" => [%{"type" => "text"}]}} =
               Document.normalize(%{root: %{children: [%{type: "text"}]}})

      assert Document.empty?(Document.normalize("not json"))
      assert Document.empty?(Document.normalize(nil))
    end
  end

  test "regenerate_ids/1 changes every id", %{doc: doc} do
    copy = Document.regenerate_ids(doc)
    old = doc |> Document.nodes() |> MapSet.new(& &1["id"])
    new = copy |> Document.nodes() |> MapSet.new(& &1["id"])
    assert MapSet.disjoint?(old, new)
  end
end
