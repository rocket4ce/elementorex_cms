defmodule ExampleWeb.Blocks.PriceRangesTest do
  use ExUnit.Case, async: true

  import ElementorexCms.Builder

  alias ElementorexCms.Registry
  alias ElementorexCms.Renderer

  setup do
    %{registry: Registry.new(blocks: Registry.builtin() ++ [ExampleWeb.Blocks.PriceRanges])}
  end

  test "is a field of the filter form of a loop grid", %{registry: registry} do
    filter = block("price_ranges", %{field: "price"}, registry: registry)
    form = block("filters", %{}, children: [filter], registry: registry)
    grid = block("loop", %{}, attrs: %{"id" => "grid"}, registry: registry)

    html =
      Renderer.to_html(doc([form, grid]),
        registry: registry,
        params: %{"grid" => %{"price" => "20000..50000"}}
      )

    assert html =~ ~s(name="grid[price]")
    assert html =~ ~s(value="20000..50000" checked)
  end

  test "outside a filter form it shows nothing on the site", %{registry: registry} do
    node = block("price_ranges", %{field: "price"}, registry: registry)
    assert Renderer.to_html(node, registry: registry) =~ "hidden"
  end
end
