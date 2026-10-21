defmodule ElementorexCms.Block do
  @moduledoc """
  Defines a block: a component that can be placed in a document, configured in
  the editor and rendered on your site.

      defmodule MyAppWeb.Blocks.Pricing do
        use ElementorexCms.Block,
          type: "pricing",
          label: "Pricing",
          icon: "currency-dollar",
          category: :components,
          description: "Plan with price and call to action",
          keywords: ~w(price plan precio)

        prop :plan, :string, default: "Pro", label: "Plan", inline: true
        prop :price, :string, default: "$9.990", label: "Price"
        prop :featured, :boolean, default: false, label: "Featured"

        def render(assigns) do
          ~H\"\"\"
          <div {root(assigns, class: ["card bg-base-100 p-6", @featured && "border-2 border-primary"])}>
            <h3 class="text-xl font-bold" {inline(assigns, :plan)}>{@plan}</h3>
            <p class="text-4xl font-black">{@price}</p>
          </div>
          \"\"\"
        end
      end

  Register it with `config :elementorex_cms, blocks: [MyAppWeb.Blocks.Pricing]`
  (see `ElementorexCms.Registry`), or generate one with `mix elementorex.gen.block`.

  ## Options of `use`

    * `:type` (required) - stable identifier stored in documents (`"pricing"`)
    * `:label`, `:description`, `:keywords` - shown and searched in the palette
    * `:icon` - Heroicons name for the palette tile
    * `:category` - palette section: `:layout`, `:basic`, `:components`,
      `:media`, `:advanced` or your own atom
    * `:container` - `true` if the block holds child blocks
    * `:children` - types allowed as children of a container (default: any)
    * `:parents` - types this block may be placed in (default: any container)
    * `:palette` - `false` to hide the block from the palette
    * `:style` - style of new nodes, e.g. `%{"desktop" => %{"padding-top" => "24px"}}`
    * `:loop` - `true` for containers that render their children once per item
      of the source in their `source` prop (like the *Loop grid*): the editor
      offers the fields of that source to the blocks inside

  ## Rendering

  `render/1` receives every prop as an assign (with its default when missing,
  and with the value of its field when the prop is bound to dynamic content,
  see `ElementorexCms.Dynamic`) plus:

    * `@node` - the node map (`"id"`, `"props"`, `"style"`, `"attrs"`, `"children"`)
    * `@ctx` - the `ElementorexCms.Renderer.Context` (`mode` is `:editor` on the
      canvas and `:public` on the site; `data` holds what the host passed)

  The root element must spread `root/2`, which adds the node id (the CSS of the
  node is scoped to it), the classes and id from the *Advanced* tab and the
  attributes the editor needs. Containers render their children with
  `<.children node={@node} ctx={@ctx} />`. See `ElementorexCms.Block.Helpers`.
  """

  alias ElementorexCms.Block.Prop

  @doc "Renders the block."
  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  Children of a new container, e.g. the two columns of a grid. Nodes are built
  with `ElementorexCms.Document.node/3`.
  """
  @callback default_children() :: [map()]

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour ElementorexCms.Block

      use Phoenix.Component

      import ElementorexCms.Block, only: [prop: 2, prop: 3]
      import ElementorexCms.Block.Helpers

      Module.register_attribute(__MODULE__, :elementorex_props, accumulate: true)
      @elementorex_opts opts
      @before_compile ElementorexCms.Block

      def default_children, do: []

      defoverridable default_children: 0
    end
  end

  @doc """
  Declares a prop of the block. See `ElementorexCms.Block.Prop` for the types
  and options.

      prop :title, :string, default: "Hello", inline: true
      prop :size, :select, options: [{"Small", "sm"}, {"Large", "lg"}], default: "sm"
      prop :items, :list, fields: [{:title, :string, default: "Item"}], item_label: :title
  """
  defmacro prop(name, type, opts \\ []) do
    quote do
      @elementorex_props ElementorexCms.Block.Prop.new(
                           unquote(name),
                           unquote(type),
                           unquote(opts)
                         )
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    opts = Module.get_attribute(env.module, :elementorex_opts)
    props = env.module |> Module.get_attribute(:elementorex_props) |> Enum.reverse()

    type = Keyword.fetch!(opts, :type) |> to_string()

    unless type =~ ~r/\A[a-z][a-z0-9_-]{0,39}\z/ do
      raise ArgumentError,
            "invalid block type #{inspect(type)} in #{inspect(env.module)}: use lowercase " <>
              "letters, digits, `_` or `-`"
    end

    duplicated = props |> Enum.frequencies_by(& &1.key) |> Enum.filter(fn {_, n} -> n > 1 end)

    if duplicated != [] do
      raise ArgumentError,
            "props declared more than once in #{inspect(env.module)}: " <>
              Enum.map_join(duplicated, ", ", &elem(&1, 0))
    end

    meta = %{
      type: type,
      module: env.module,
      label: Keyword.get(opts, :label, type),
      description: Keyword.get(opts, :description),
      icon: Keyword.get(opts, :icon, "square-3-stack-3d"),
      category: Keyword.get(opts, :category, :components),
      keywords: Keyword.get(opts, :keywords, []),
      container: Keyword.get(opts, :container, false),
      children: Keyword.get(opts, :children, :any),
      parents: Keyword.get(opts, :parents, :any),
      palette: Keyword.get(opts, :palette, true),
      style: Keyword.get(opts, :style, %{}),
      loop: Keyword.get(opts, :loop, false)
    }

    quote do
      @doc false
      def __elementorex_block__, do: true

      @doc "Type stored in documents for this block."
      def type, do: unquote(type)

      @doc "Palette and editor metadata of the block."
      def meta, do: unquote(Macro.escape(meta))

      @doc "Props of the block, in declaration order."
      def props, do: unquote(Macro.escape(props))
    end
  end

  @doc "Whether `module` is a block (defines `use ElementorexCms.Block`)."
  @spec block?(module()) :: boolean()
  def block?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__elementorex_block__, 0)
  end

  @doc "The prop of `block` with the given name (atom or string), or `nil`."
  @spec find_prop(module(), atom() | String.t()) :: Prop.t() | nil
  def find_prop(block, name) do
    key = to_string(name)
    Enum.find(block.props(), &(&1.key == key))
  end

  @doc """
  Casts a map of props (string keys, as stored) with the block's prop
  definitions: known props are cast and sanitized, unknown keys are dropped and
  missing ones are left out (their default applies when rendering).
  """
  @spec cast_props(module(), map()) :: map()
  def cast_props(block, props) when is_map(props) do
    props = Map.new(props, fn {key, value} -> {to_string(key), value} end)

    Enum.reduce(block.props(), %{}, fn prop, acc ->
      case Map.fetch(props, prop.key) do
        {:ok, value} -> Map.put(acc, prop.key, Prop.cast(prop, value))
        :error -> acc
      end
    end)
  end

  def cast_props(_block, _props), do: %{}

  @doc """
  Every prop of `block` with its default value (string keys). Text defaults
  are translated to the current locale (`ElementorexCms.I18n`), so a block
  added from a Spanish editor starts with Spanish placeholder text.
  """
  @spec default_props(module()) :: map()
  def default_props(block) do
    Map.new(block.props(), &{&1.key, Prop.localized_default(&1)})
  end

  @doc """
  Props as assigns for `render/1`: atom keys, stored values cast again (so a
  document edited by hand cannot inject anything) and defaults for the rest.
  """
  @spec assigns(module(), map()) :: map()
  def assigns(block, props) when is_map(props) do
    Map.new(block.props(), fn prop ->
      value =
        case Map.fetch(props, prop.key) do
          {:ok, value} -> Prop.cast(prop, value)
          :error -> Prop.default(prop)
        end

      {prop.name, value}
    end)
  end

  def assigns(block, _props), do: assigns(block, %{})
end
