defmodule ElementorexCms.EditorTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest, only: [build_conn: 0]
  import Phoenix.LiveViewTest

  alias ElementorexCms.Builder
  alias ElementorexCms.Document

  @endpoint ElementorexCms.TestEndpoint

  defp mount_editor(opts \\ []) do
    doc =
      Keyword.get_lazy(opts, :document, fn ->
        Builder.doc([
          Builder.block("heading", %{text: "Hello"}, id: "heading1"),
          Builder.block("container", %{}, id: "box1", children: [])
        ])
      end)

    session = %{
      "test_pid" => self(),
      "document" => doc,
      "fail" => Keyword.get(opts, :fail, false),
      "locale" => Keyword.get(opts, :locale, "en")
    }

    {:ok, view, html} =
      live_isolated(build_conn(), ElementorexCms.TestEditorLive, session: session)

    {view, html}
  end

  defp hook(view, event, payload \\ %{}),
    do: view |> element("#editor") |> render_hook(event, payload)

  defp current_doc(view) do
    receive_last_change() || flunk("no change received for #{inspect(view)}")
  end

  defp receive_last_change(last \\ nil) do
    receive do
      {:changed, doc} -> receive_last_change(doc)
    after
      50 -> last
    end
  end

  test "renders the chrome, the slots and the structure" do
    {view, html} = mount_editor()

    assert html =~ "Test page"
    assert has_element?(view, "#status-slot")
    assert has_element?(view, "#publish")
    assert has_element?(view, ~s([data-exr-block="heading"]))
    assert has_element?(view, ~s([data-exr-tree-id="heading1"]))
    assert has_element?(view, ".exr-insp-empty")
  end

  test "pushes the canvas HTML when the iframe is ready" do
    {view, _html} = mount_editor()
    hook(view, "canvas_ready")

    assert_push_event(view, "exr:editor:render", %{html: html, css: css})
    assert html =~ ~s(data-ex-id="heading1")
    assert html =~ ~s(data-ex-inline="text")
    assert css =~ ".exr-rich"
  end

  test "selecting shows the inspector of the block" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "heading1"})

    assert has_element?(view, ".exr-insp-title b", "Heading")
    assert has_element?(view, ~s(textarea[name="props[text]"]))
    assert has_element?(view, ~s(.exr-tree-row.is-selected[data-exr-tree-id="heading1"]))
  end

  test "adding a block from the palette inserts it after the selection and selects it" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "heading1"})
    hook(view, "add", %{"type" => "button"})

    doc = current_doc(view)
    [heading, button, box] = Document.root(doc)["children"]
    assert {heading["id"], button["type"], box["id"]} == {"heading1", "button", "box1"}
    assert has_element?(view, ~s(.exr-tree-row.is-selected[data-exr-tree-id="#{button["id"]}"]))
  end

  test "dropping inserts and moves where the indicator says" do
    {view, _html} = mount_editor()
    root = render(view) |> then(&Regex.run(~r/data-root="([^"]+)"/, &1)) |> List.last()

    hook(view, "insert", %{"type" => "badge", "parent" => "box1", "index" => 0})
    doc = current_doc(view)
    assert [%{"type" => "badge"}] = Document.get(doc, "box1")["children"]

    hook(view, "move", %{"id" => "heading1", "parent" => "box1", "index" => 1})
    doc = current_doc(view)
    assert Enum.map(Document.get(doc, "box1")["children"], & &1["type"]) == ~w(badge heading)
    assert Enum.map(Document.root(doc)["children"], & &1["id"]) == ["box1"]
    assert root
  end

  test "an impossible drop leaves the document and shows a notice" do
    {view, _html} = mount_editor()
    hook(view, "move", %{"id" => "box1", "parent" => "box1", "index" => 0})

    assert has_element?(view, ".exr-notice.is-error")
    refute_received {:changed, _}
  end

  test "editing props, undo and redo" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "heading1"})

    hook(view, "props", %{
      "_target" => ["props", "text"],
      "node" => "heading1",
      "props" => %{"text" => "Hola <b>mundo</b><script>x</script>"}
    })

    assert Document.get(current_doc(view), "heading1")["props"]["text"] == "Hola <b>mundo</b>"

    hook(view, "undo")
    assert Document.get(current_doc(view), "heading1")["props"]["text"] == "Hello"

    hook(view, "redo")
    assert Document.get(current_doc(view), "heading1")["props"]["text"] == "Hola <b>mundo</b>"
  end

  test "inline edits are cast like any other value" do
    {view, _html} = mount_editor()

    hook(view, "inline", %{
      "id" => "heading1",
      "prop" => "text",
      "value" => "<i>New</i><img src=x onerror=1>"
    })

    assert Document.get(current_doc(view), "heading1")["props"]["text"] == "<i>New</i>"
  end

  test "styles: linked sides, plain numbers in px, per device and invalid values" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "box1"})
    hook(view, "tab", %{"tab" => "style"})

    hook(view, "style", %{
      "_target" => ["style", "padding-top"],
      "node" => "box1",
      "style" => %{"padding-top" => "12"}
    })

    desktop = Document.get(current_doc(view), "box1")["style"]["desktop"]

    assert Map.take(desktop, ~w(padding-top padding-right padding-bottom padding-left))
           |> Map.values()
           |> Enum.uniq() == ["12px"]

    hook(view, "toggle_link", %{"group" => "padding"})
    hook(view, "device", %{"device" => "mobile"})

    hook(view, "style", %{
      "_target" => ["style", "padding-left"],
      "node" => "box1",
      "style" => %{"padding-left" => "4px"}
    })

    style = Document.get(current_doc(view), "box1")["style"]
    assert style["mobile"] == %{"padding-left" => "4px"}

    hook(view, "style", %{
      "_target" => ["style", "color__swatch"],
      "node" => "box1",
      "style" => %{"color__swatch" => "var(--color-primary)"}
    })

    assert Document.get(current_doc(view), "box1")["style"]["mobile"]["color"] ==
             "var(--color-primary)"

    hook(view, "style", %{
      "_target" => ["style", "color"],
      "node" => "box1",
      "style" => %{"color" => "red;}"}
    })

    assert has_element?(view, ".exr-notice.is-error")
  end

  test "advanced settings" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "heading1"})

    hook(view, "attrs", %{
      "_target" => ["attrs", "hide_on"],
      "node" => "heading1",
      "attrs" => %{"hide_on" => ["", "mobile"]}
    })

    hook(view, "attrs", %{
      "_target" => ["attrs", "animation_delay"],
      "node" => "heading1",
      "attrs" => %{"animation_delay" => "300"}
    })

    attrs = Document.get(current_doc(view), "heading1")["attrs"]
    assert attrs["hide_on"] == ["mobile"]
    assert attrs["animation_delay"] == 300
  end

  test "delete, duplicate, copy and paste" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "heading1"})
    hook(view, "duplicate")
    assert length(Document.root(current_doc(view))["children"]) == 3

    hook(view, "copy")
    hook(view, "paste")
    assert length(Document.root(current_doc(view))["children"]) == 4

    hook(view, "select", %{"id" => "heading1"})
    hook(view, "delete")
    doc = current_doc(view)
    refute Document.get(doc, "heading1")
    assert length(Document.root(doc)["children"]) == 3
  end

  test "repeaters add, move and remove items" do
    {view, _html} = mount_editor()
    hook(view, "insert", %{"type" => "accordion", "parent" => "box1", "index" => 0})
    [accordion] = Document.get(current_doc(view), "box1")["children"]

    hook(view, "select", %{"id" => accordion["id"]})
    hook(view, "list_add", %{"prop" => "items"})
    items = Document.get(current_doc(view), accordion["id"])["props"]["items"]
    assert length(items) == 4

    hook(view, "list_move", %{"prop" => "items", "index" => "3", "dir" => "up"})
    moved = Document.get(current_doc(view), accordion["id"])["props"]["items"]
    assert Enum.at(moved, 2)["id"] == Enum.at(items, 3)["id"]

    hook(view, "list_remove", %{"prop" => "items", "index" => "0"})
    assert length(Document.get(current_doc(view), accordion["id"])["props"]["items"]) == 3
  end

  test "icon picker and media library set values" do
    {view, _html} = mount_editor()
    hook(view, "insert", %{"type" => "button", "parent" => "box1", "index" => 0})
    [button] = Document.get(current_doc(view), "box1")["children"]
    hook(view, "select", %{"id" => button["id"]})

    hook(view, "picker_open", %{"prop" => "icon"})
    hook(view, "picker_search", %{"q" => "regalo"})
    assert has_element?(view, ~s(.exr-icon-cell[phx-value-name="gift"]))
    hook(view, "picker_pick", %{"name" => "gift"})
    assert Document.get(current_doc(view), button["id"])["props"]["icon"] == "gift"

    hook(view, "insert", %{"type" => "image", "parent" => "box1", "index" => 0})
    [image | _] = Document.get(current_doc(view), "box1")["children"]
    hook(view, "select", %{"id" => image["id"]})
    hook(view, "library_open", %{"prop" => "src"})
    assert has_element?(view, ".exr-media-cell", "a.png")
    hook(view, "library_pick", %{"url" => "/uploads/a.png"})
    assert Document.get(current_doc(view), image["id"])["props"]["src"] == "/uploads/a.png"
  end

  test "templates are inserted with fresh ids" do
    {view, _html} = mount_editor()
    hook(view, "apply_template", %{"key" => "faq"})
    hook(view, "apply_template", %{"key" => "faq"})

    doc = current_doc(view)
    ids = doc |> Document.nodes() |> Enum.map(& &1["id"])
    assert length(ids) == length(Enum.uniq(ids))
    assert Enum.count(Document.nodes(doc), &(&1["type"] == "accordion")) == 2
  end

  test "the code panel shows the HTML, CSS and JSON of the selection" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "heading1"})
    hook(view, "code_tab", %{"tab" => "html"})
    assert has_element?(view, ".exr-code-line", "Hello")

    hook(view, "code_tab", %{"tab" => "json"})
    assert has_element?(view, ".exr-code-line", "heading1")
  end

  test "the preview button switches the canvas to preview and back" do
    {view, _html} = mount_editor()

    view |> element("#editor-preview") |> render_click()
    assert has_element?(view, ~s(#editor[data-preview="true"]))
    assert has_element?(view, "#editor-preview", "Exit preview")

    view |> element("#editor-preview") |> render_click()
    assert has_element?(view, ~s(#editor[data-preview="false"]))
    refute has_element?(view, "#editor-preview", "Exit preview")
    assert has_element?(view, "#editor-preview", "Preview")
  end

  test "undoing back to the saved document is not an unsaved change" do
    {view, _html} = mount_editor()
    hook(view, "add", %{"type" => "badge"})
    assert has_element?(view, "#editor[data-dirty=true]")

    hook(view, "undo")
    assert has_element?(view, "#editor[data-dirty=false]")

    hook(view, "redo")
    hook(view, "save")
    assert_receive {:saved, _}
    assert has_element?(view, "#editor[data-dirty=false]")

    hook(view, "undo")
    assert has_element?(view, "#editor[data-dirty=true]")
  end

  test "saving sends the document to the host and shows the result" do
    {view, _html} = mount_editor()
    hook(view, "save")
    assert_receive {:saved, %{"root" => _}}
    assert render(view) =~ "Saved"

    {view, _html} = mount_editor(fail: true)
    hook(view, "save")
    assert_receive {:saved, _}
    assert has_element?(view, ".exr-notice.is-error", "Could not save")
  end

  test "speaks Spanish" do
    {view, html} = mount_editor(locale: "es")
    assert html =~ "Guardar"
    assert html =~ "Buscar componente…"
    assert has_element?(view, ~s([data-exr-block="heading"]), "Título")
  end

  test "documents from outside are normalized before editing" do
    doc = %{
      "root" => %{
        "children" => [
          %{
            "id" => "evil\"]",
            "type" => "text",
            "props" => %{"text" => "<script>x</script><p>ok</p>"}
          }
        ]
      }
    }

    {view, _html} = mount_editor(document: doc)
    hook(view, "canvas_ready")

    assert_push_event(view, "exr:editor:render", %{html: html})
    refute html =~ "<script"
    refute html =~ "evil"
    assert html =~ "<p>ok</p>"
  end

  test "unknown ids and events are ignored" do
    {view, _html} = mount_editor()
    hook(view, "select", %{"id" => "nope"})

    hook(view, "props", %{
      "_target" => ["props", "text"],
      "node" => "nope",
      "props" => %{"text" => "x"}
    })

    hook(view, "whatever")
    refute_received {:changed, _}
  end
end
