defmodule ElementorexCms.Builder do
  @moduledoc """
  Builds documents in Elixir: for templates, seeds and tests.

      import ElementorexCms.Builder

      doc([
        section([
          block("heading", %{text: "Hello", level: "h1"}, style: %{"mobile" => %{"font-size" => "28px"}}),
          block("text", %{text: "<p>Welcome!</p>"}),
          block("button", %{label: "Start", url: "/start", icon: "arrow-right"})
        ])
      ])

  Props get the defaults of their block, so only what differs needs to be given.
  Pass `registry:` to build with a custom registry.
  """

  alias ElementorexCms.Document
  alias ElementorexCms.Registry

  @doc "A document with these root children."
  @spec doc([map()], keyword()) :: Document.t()
  def doc(children, opts \\ []) do
    root =
      Document.node("root", %{},
        children: children,
        style: Keyword.get(opts, :style, %{}),
        attrs: Keyword.get(opts, :attrs, %{})
      )

    %{"version" => Document.version(), "root" => root}
  end

  @doc """
  A node of `type`. Options: `:id`, `:children`, `:style` (per state), `:attrs`
  (*Advanced* settings) and `:registry`.
  """
  @spec block(String.t(), map() | keyword(), keyword()) :: map()
  def block(type, props \\ %{}, opts \\ []) do
    props = Map.new(props, fn {key, value} -> {to_string(key), value} end)
    registry = Keyword.get_lazy(opts, :registry, &Registry.default/0)

    node_opts =
      [registry: registry]
      |> put_opt(:id, opts[:id])
      |> put_opt(:children, opts[:children])
      |> put_opt(:style, opts[:style] && stringify(opts[:style]))
      |> put_opt(:attrs, opts[:attrs] && stringify(opts[:attrs]))

    Document.node(type, props, node_opts)
  end

  @doc "A section with these children."
  def section(children, props \\ %{}, opts \\ []),
    do: block("section", props, Keyword.put(opts, :children, children))

  @doc "A flex container with these children."
  def container(children, props \\ %{}, opts \\ []),
    do: block("container", props, Keyword.put(opts, :children, children))

  @doc "A grid whose columns are the given lists of children (one container per column)."
  def columns(columns, props \\ %{}, opts \\ []) do
    children = Enum.map(columns, &container(&1, %{"gap" => "4"}))

    block(
      "grid",
      Map.put_new(
        Map.new(props, fn {k, v} -> {to_string(k), v} end),
        "columns",
        to_string(length(columns))
      ),
      Keyword.put(opts, :children, children)
    )
  end

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp stringify(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify(value)} end)
  end

  defp stringify(value), do: value
end
