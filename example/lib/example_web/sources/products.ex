defmodule ExampleWeb.Sources.Products do
  @moduledoc """
  Products as dynamic content of the visual editor (ElementorexCms): the
  *Loop grid* lists them and blocks can show their fields.

  The fields are read from `Example.Catalog.Product` when they are needed:
  a field added to the schema (say `brand`, with its migration) is available
  to every block without touching this module.
  """

  use ElementorexCms.Source.Ecto,
    schema: Example.Catalog.Product,
    repo: Example.Repo,
    label: "Products",
    icon: "shopping-bag",
    # The page of each record, offered as "Link to the item"
    path: "/shop/:slug",
    # Settings of new bindings to these fields (see ElementorexCms.Dynamic):
    # Chilean pesos, "$19.990"
    fields: [price: [defaults: %{"before" => "$", "format" => "number", "decimals" => 0}]],
    # Filters with logic of their own, offered in loops and in the visitors'
    # Filters forms next to the fields (see filter/4 below)
    filters: [in_stock: [label: "In stock", type: :boolean]]

  # More options (see ElementorexCms.Source.Ecto):
  #
  #     except: [:internal_notes],
  #     preload: [:category],
  #     fields: [image_url: [label: "Photo"]]

  # Every list and lookup starts here: your pages only get published
  # records, the editor shows them all.
  @impl true
  def scope(query, %{mode: :public}), do: where(query, [r], r.published)
  def scope(query, _context), do: query

  # "In stock": a filter that is not a column, `stock > 0`.
  @impl true
  def filter(query, "in_stock", "true", _context), do: where(query, [r], r.stock > 0)
  def filter(query, _name, _value, _context), do: query
end
