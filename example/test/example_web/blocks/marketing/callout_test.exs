defmodule ExampleWeb.Blocks.Marketing.CalloutTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.Document
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer

  @blocks [ExampleWeb.Blocks.Marketing.Callout, ExampleWeb.Blocks.Whatsapp]

  setup do
    %{registry: Registry.new(blocks: Registry.builtin() ++ @blocks)}
  end

  test "renders its children", %{registry: registry} do
    text = Document.node("text", %{text: "<p>Inside</p>"}, registry: registry)
    node = Document.node("callout", %{title: "Hello"}, registry: registry, children: [text])
    html = Renderer.to_html(node, registry: registry)

    assert html =~ "Hello"
    assert html =~ "Inside"
  end

  test "accepts only some blocks inside", %{registry: registry} do
    assert Registry.accepts?(registry, "callout", "whatsapp")
    assert Registry.accepts?(registry, "callout", "text")
    refute Registry.accepts?(registry, "callout", "image")
    refute Registry.accepts?(registry, "callout", "section")
  end

  test "drops unsafe background images", %{registry: registry} do
    node = Document.node("callout", %{image: "javascript:alert(1)"}, registry: registry)
    refute Renderer.to_html(node, registry: registry) =~ "javascript:"
  end
end
