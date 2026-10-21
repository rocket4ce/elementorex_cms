defmodule ElementorexCms.TestSource do
  @moduledoc false
  # Products kept in memory: a source implemented by hand (no Ecto), with a
  # page per product. Its `list/2` sends the query to the test process when
  # the context's data has a `:test_pid`.
  @behaviour ElementorexCms.Source

  alias ElementorexCms.Source.Field
  alias ElementorexCms.Source.Query

  @products [
    %{
      id: 1,
      name: "Red shoes",
      slug: "red-shoes",
      price: 19_990,
      image: "https://cdn.example.com/red.jpg",
      description: "Light & comfy.\n\nFor <every> day.",
      category: "Shoes",
      featured: true,
      released_on: ~D[2026-03-01],
      secret_cost: 4_000
    },
    %{
      id: 2,
      name: "Blue shirt",
      slug: "blue-shirt",
      price: 9_990,
      image: "https://cdn.example.com/blue.jpg",
      description: "Cotton.",
      category: "Shirts",
      featured: false,
      released_on: ~D[2026-05-20],
      secret_cost: 2_000
    },
    %{
      id: 3,
      name: "Green shoes",
      slug: "green-shoes",
      price: 29_990,
      image: nil,
      description: nil,
      category: "Shoes",
      featured: false,
      released_on: nil,
      secret_cost: 9_000
    }
  ]

  def products, do: @products

  @impl true
  def key, do: "products"

  @impl true
  def label, do: "Products"

  @impl true
  def icon, do: "shopping-bag"

  @impl true
  def fields do
    [
      Field.new(:name, role: :title, sortable: true, filterable: true),
      Field.new(:price,
        type: :number,
        sortable: true,
        filterable: true,
        defaults: %{"before" => "$", "format" => "number", "decimals" => 0}
      ),
      Field.new(:image, type: :image),
      Field.new(:description, type: :text),
      Field.new(:category, filterable: true),
      Field.new(:featured, type: :boolean, filterable: true),
      Field.new(:released_on, type: :date, sortable: true)
    ]
  end

  @impl true
  def list(%Query{} = query, context) do
    if pid = get_in(context, [:data, :test_pid]), do: send(pid, {:source_query, query})

    Query.run(query, @products, fn product, key ->
      Map.get(product, String.to_existing_atom(key))
    end)
  end

  @impl true
  def count(%Query{} = query, _context) do
    Query.count(query, @products, fn product, key ->
      Map.get(product, String.to_existing_atom(key))
    end)
  end

  @impl true
  def url(product), do: "/shop/#{product.slug}"
end
