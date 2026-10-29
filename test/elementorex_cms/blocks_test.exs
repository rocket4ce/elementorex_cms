defmodule ElementorexCms.BlocksTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias ElementorexCms.Builder
  alias ElementorexCms.Document
  alias ElementorexCms.Heroicons
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer
  alias ElementorexCms.Templates

  setup do
    %{registry: Registry.default()}
  end

  describe "every built-in block" do
    test "renders on the site and on the canvas, rooted at its node", %{registry: registry} do
      for block <- Registry.list(registry), block.type() != "root", mode <- [:public, :editor] do
        node = Document.node(block.type(), %{}, registry: registry)
        html = Renderer.to_html(node, registry: registry, mode: mode)

        doc = LazyHTML.from_fragment(html)

        assert LazyHTML.filter(doc, ~s([data-ex-id="#{node["id"]}"])) |> Enum.count() == 1,
               "#{block.type()} (#{mode}) must put data-ex-id on its root: #{html}"

        if mode == :editor do
          assert html =~ ~s(data-ex-type="#{block.type()}")
        else
          refute html =~ "data-ex-type"
          refute html =~ "data-ex-inline"
        end
      end
    end

    test "has a label, an icon that exists and a valid category", %{registry: registry} do
      for block <- Registry.list(registry) do
        meta = block.meta()
        assert is_binary(meta.label)
        assert Heroicons.exists?(meta.icon), "#{meta.type} icon #{meta.icon}"
        assert is_atom(meta.category)
      end
    end
  end

  test "buttons drop unsafe links and keep safe ones", %{registry: registry} do
    bad = Document.node("button", %{"url" => "javascript:alert(1)"}, registry: registry)
    good = Document.node("button", %{"url" => "/precios", "new_tab" => true}, registry: registry)

    refute Renderer.to_html(bad, registry: registry) =~ "href"

    assert Renderer.to_html(good, registry: registry) =~
             ~s(href="/precios" target="_blank" rel="noopener noreferrer")
  end

  test "stored props are sanitized again when rendering", %{registry: registry} do
    node = %{
      "id" => "abc1234567",
      "type" => "heading",
      "props" => %{"text" => "<img src=x onerror=alert(1)>Hi", "level" => "script"},
      "style" => %{},
      "attrs" => %{},
      "children" => []
    }

    html = Renderer.to_html(node, registry: registry)
    refute html =~ "onerror"
    assert html =~ "<h2"
  end

  test "editor placeholders only show on the canvas", %{registry: registry} do
    image = Document.node("image", %{}, registry: registry)
    container = Document.node("container", %{}, registry: registry)

    assert Renderer.to_html(image, registry: registry, mode: :editor) =~ "exr-image-placeholder"
    refute Renderer.to_html(image, registry: registry) =~ "exr-image-placeholder"
    assert Renderer.to_html(container, registry: registry, mode: :editor) =~ "exr-empty"
    refute Renderer.to_html(container, registry: registry) =~ "exr-empty"
  end

  test "videos embed only canonical players and are previews on the canvas", %{registry: registry} do
    node =
      Document.node("video", %{"url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
        registry: registry
      )

    assert Renderer.to_html(node, registry: registry) =~
             "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"

    refute Renderer.to_html(node, registry: registry, mode: :editor) =~ "<iframe"
  end

  test "the countdown carries a UTC instant for the runtime", %{registry: registry} do
    node = Document.node("countdown", %{"target" => "2031-01-01T00:00"}, registry: registry)

    assert Renderer.to_html(node, registry: registry) =~
             ~s(data-ex-countdown="2031-01-01T00:00:00Z")
  end

  test "unknown blocks render nothing on the site and a notice on the canvas", %{
    registry: registry
  } do
    node = %{
      "id" => "zzz1234567",
      "type" => "legacy",
      "props" => %{},
      "style" => %{},
      "attrs" => %{},
      "children" => []
    }

    assert Renderer.to_html(node, registry: registry) == ""
    assert Renderer.to_html(node, registry: registry, mode: :editor) =~ "exr-unknown"
  end

  test "the document component renders the stylesheet and the root" do
    doc =
      Builder.doc([
        Builder.block("text", %{text: "<p>Hola</p>"},
          style: %{"desktop" => %{"color" => "#123456"}}
        )
      ])

    html =
      rendered_to_string(
        ElementorexCms.Components.document(%{
          document: doc,
          registry: nil,
          data: %{},
          mode: :public,
          class: "my-doc",
          __changed__: nil
        })
      )

    assert html =~ "<style data-ex-style"
    assert html =~ "color:#123456"
    assert html =~ "my-doc"
    assert html =~ "<p>Hola</p>"
    assert ElementorexCms.to_text(doc) == "Hola"
  end

  test "every template builds nodes the registry accepts", %{registry: registry} do
    for template <- Templates.builtin() do
      nodes = template.nodes.()
      doc = Document.normalize(Builder.doc(nodes), registry)
      assert Document.count(doc) > 1, template.key

      assert Document.root(doc)["children"] |> Enum.all?(&Registry.fetch(registry, &1["type"])),
             template.key
    end
  end

  describe "registry" do
    test "only/exclude and the root is always kept" do
      registry = Registry.new(only: ~w(heading text))

      assert Enum.map(Registry.list(registry), & &1.type()) |> Enum.sort() ==
               ~w(heading root text)

      registry = Registry.new(exclude: ~w(video))
      refute Registry.fetch(registry, "video")
    end

    test "accepts?/3 follows containers" do
      registry = Registry.default()
      assert Registry.accepts?(registry, "container", "button")
      refute Registry.accepts?(registry, "button", "text")
      refute Registry.accepts?(registry, "container", "root")
    end

    test "palette groups by category" do
      categories = Registry.default() |> Registry.palette() |> Enum.map(&elem(&1, 0))
      assert categories == [:layout, :basic, :components, :charts, :media, :dynamic, :advanced]
    end
  end

  describe "Heroicons" do
    test "search by name and by Spanish synonym" do
      assert "gift" in Heroicons.search("regalo")
      assert "arrow-right" in Heroicons.search("arrow right")
      assert Heroicons.search("", 3) |> length() == 3
    end

    test "svg/3 renders the three styles and nothing for unknown names" do
      assert Heroicons.svg("gift") =~ ~s(stroke="currentColor")
      assert Heroicons.svg("gift", "solid") =~ ~s(fill="currentColor")
      assert Heroicons.svg("gift", "mini") =~ ~s(viewBox="0 0 20 20")
      assert Heroicons.svg("nope") == ""
    end
  end
end
