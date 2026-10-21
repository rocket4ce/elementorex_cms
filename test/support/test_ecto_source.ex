defmodule ElementorexCms.TestEctoSource do
  @moduledoc false
  use ElementorexCms.Source.Ecto,
    schema: ElementorexCms.TestProduct,
    repo: ElementorexCms.TestRepo,
    label: "Catalog",
    icon: "shopping-bag",
    path: "/shop/:slug",
    preload: [:category],
    filters: [in_stock: [label: "In stock", type: :boolean]],
    fields: [
      price: [defaults: %{"before" => "$", "format" => "number"}],
      image_url: [label: "Photo"]
    ]

  @impl true
  def scope(query, %{mode: :public}), do: where(query, [p], p.status == :published)
  def scope(query, _context), do: query

  @impl true
  def filter(query, "in_stock", "true", _context), do: where(query, [p], p.stock > 0)
  def filter(query, _name, _value, _context), do: query
end
