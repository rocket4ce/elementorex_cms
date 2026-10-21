defmodule ExampleWeb.Blocks.WhatsappTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.Document
  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer

  setup do
    %{registry: Registry.new(blocks: Registry.builtin() ++ [ExampleWeb.Blocks.Whatsapp])}
  end

  test "uses the number of the site from the data", %{registry: registry} do
    node = Document.node("whatsapp", %{message: "Hola"}, registry: registry)
    html = Renderer.to_html(node, registry: registry, data: %{whatsapp: "+56 9 1111 2222"})

    assert html =~ "https://wa.me/56911112222?text=Hola"
  end

  test "its own phone wins over the data", %{registry: registry} do
    node = Document.node("whatsapp", %{phone: "+1 555 0100"}, registry: registry)
    html = Renderer.to_html(node, registry: registry, data: %{whatsapp: "+56 9 1111 2222"})

    assert html =~ "https://wa.me/15550100"
  end

  test "without a number it renders no link", %{registry: registry} do
    node = Document.node("whatsapp", %{}, registry: registry)
    refute Renderer.to_html(node, registry: registry) =~ "href="
  end

  test "floats only on the site", %{registry: registry} do
    node = Document.node("whatsapp", %{floating: true}, registry: registry)

    assert Renderer.to_html(node, registry: registry) =~ "fixed"
    refute Renderer.to_html(node, registry: registry, mode: :editor) =~ "fixed"
  end
end
