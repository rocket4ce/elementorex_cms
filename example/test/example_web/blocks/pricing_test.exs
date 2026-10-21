defmodule ExampleWeb.Blocks.PricingTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.Document
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer

  setup do
    %{registry: Registry.new(blocks: Registry.builtin() ++ [ExampleWeb.Blocks.Pricing])}
  end

  test "renders on the site and on the editor canvas", %{registry: registry} do
    node = Document.node("pricing", %{plan: "Hello"}, registry: registry)

    assert Renderer.to_html(node, registry: registry) =~ "Hello"
    assert Renderer.to_html(node, registry: registry, mode: :editor) =~ ~s(data-ex-type="pricing")
  end

  test "shows the badge only when featured", %{registry: registry} do
    plain = Document.node("pricing", %{badge: "Top"}, registry: registry)
    featured = Document.node("pricing", %{badge: "Top", featured: true}, registry: registry)

    refute Renderer.to_html(plain, registry: registry) =~ "Top"
    assert Renderer.to_html(featured, registry: registry) =~ "Top"
  end

  test "sanitizes what it receives", %{registry: registry} do
    node =
      Document.node(
        "pricing",
        %{text: "<p>ok</p><script>alert(1)</script>", url: "javascript:alert(1)"},
        registry: registry
      )

    html = Renderer.to_html(node, registry: registry)
    refute html =~ "<script"
    refute html =~ "javascript:"
  end
end
