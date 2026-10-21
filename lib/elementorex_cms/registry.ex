defmodule ElementorexCms.Registry do
  @moduledoc """
  The set of blocks a document can use.

  `default/0` is the built-in blocks plus the ones configured by your app:

      config :elementorex_cms,
        # your blocks, added to the built-in ones (same type = replaces it)
        blocks: [MyAppWeb.Blocks.Pricing, MyAppWeb.Blocks.Whatsapp],
        # built-in types to leave out
        exclude_blocks: ["video", "mockup"]

  A registry can also be built for one editor or page with `new/2`, e.g. to offer
  fewer blocks in a modal than in a landing page:

      registry = ElementorexCms.Registry.new(only: ~w(heading text button image alert))
  """

  alias ElementorexCms.Blocks

  defstruct blocks: %{}, order: []

  @type t :: %__MODULE__{blocks: %{String.t() => module()}, order: [String.t()]}

  @builtin [
    Blocks.Root,
    Blocks.Section,
    Blocks.Container,
    Blocks.Grid,
    Blocks.Hero,
    Blocks.Spacer,
    Blocks.Divider,
    Blocks.Heading,
    Blocks.Text,
    Blocks.Button,
    Blocks.ButtonGroup,
    Blocks.Image,
    Blocks.Icon,
    Blocks.Feature,
    Blocks.List,
    Blocks.Link,
    Blocks.Alert,
    Blocks.Badge,
    Blocks.Card,
    Blocks.Stats,
    Blocks.Steps,
    Blocks.Countdown,
    Blocks.Accordion,
    Blocks.Tabs,
    Blocks.Timeline,
    Blocks.Rating,
    Blocks.Progress,
    Blocks.Avatar,
    Blocks.Chat,
    Blocks.Quote,
    Blocks.Kbd,
    Blocks.Carousel,
    Blocks.Video,
    Blocks.Mockup,
    Blocks.Html,
    Blocks.Loop,
    Blocks.Filters,
    Blocks.FilterSearch,
    Blocks.FilterChoice,
    Blocks.FilterRange,
    Blocks.FilterToggle,
    Blocks.FilterSort
  ]

  @categories [:layout, :basic, :components, :media, :dynamic, :advanced]

  @doc "Built-in block modules."
  @spec builtin() :: [module()]
  def builtin, do: @builtin

  @doc "Palette categories of the built-in blocks, in display order."
  @spec categories() :: [atom()]
  def categories, do: @categories

  @doc "The built-in blocks plus the configured ones (see the module docs)."
  @spec default() :: t()
  def default do
    extra = Application.get_env(:elementorex_cms, :blocks, [])
    exclude = Application.get_env(:elementorex_cms, :exclude_blocks, [])
    new(blocks: @builtin ++ extra, exclude: exclude)
  end

  @doc """
  Builds a registry.

    * `:blocks` - block modules (default: the built-in ones plus the configured)
    * `:only` - keep only these types (the root is always kept)
    * `:exclude` - leave out these types
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    modules =
      case Keyword.fetch(opts, :blocks) do
        {:ok, modules} -> modules
        :error -> @builtin ++ Application.get_env(:elementorex_cms, :blocks, [])
      end

    only = opts[:only] && Enum.map(opts[:only], &to_string/1)
    exclude = opts |> Keyword.get(:exclude, []) |> Enum.map(&to_string/1)

    modules
    |> Enum.map(fn module ->
      unless ElementorexCms.Block.block?(module) do
        raise ArgumentError, "#{inspect(module)} is not a block (use ElementorexCms.Block)"
      end

      module
    end)
    |> Enum.reduce(%__MODULE__{}, fn module, registry ->
      type = module.type()

      keep? =
        type == "root" or ((only == nil or type in only) and type not in exclude)

      if keep? do
        order = if type in registry.order, do: registry.order, else: registry.order ++ [type]
        %{registry | blocks: Map.put(registry.blocks, type, module), order: order}
      else
        registry
      end
    end)
  end

  @doc "The module of a block type, or `nil`."
  @spec fetch(t() | nil, String.t() | nil) :: module() | nil
  def fetch(nil, type), do: fetch(default(), type)
  def fetch(%__MODULE__{blocks: blocks}, type) when is_binary(type), do: Map.get(blocks, type)
  def fetch(_registry, _type), do: nil

  @doc "Block modules in registration order."
  @spec list(t()) :: [module()]
  def list(%__MODULE__{blocks: blocks, order: order}),
    do: Enum.map(order, &Map.fetch!(blocks, &1))

  @doc "Whether the type is a container block."
  @spec container?(t(), String.t()) :: boolean()
  def container?(registry, type) do
    case fetch(registry, type) do
      nil -> false
      block -> block.meta().container == true
    end
  end

  @doc """
  Blocks shown in the palette grouped by category: `[{category, [module]}]`,
  built-in categories first, then the custom ones in order of appearance.
  """
  @spec palette(t()) :: [{atom(), [module()]}]
  def palette(registry) do
    blocks = registry |> list() |> Enum.filter(& &1.meta().palette)
    custom = blocks |> Enum.map(& &1.meta().category) |> Enum.uniq() |> Kernel.--(@categories)

    for category <- @categories ++ custom,
        in_category = Enum.filter(blocks, &(&1.meta().category == category)),
        in_category != [] do
      {category, in_category}
    end
  end

  @doc """
  Whether a node of `child_type` may go inside a node of `parent_type`, per the
  `:children` option of the parent and the `:parents` option of the child.
  """
  @spec accepts?(t(), String.t(), String.t()) :: boolean()
  def accepts?(registry, parent_type, child_type) do
    with parent when not is_nil(parent) <- fetch(registry, parent_type),
         child when not is_nil(child) <- fetch(registry, child_type),
         true <- parent.meta().container,
         true <- child_type != "root" do
      allowed?(parent.meta().children, child_type) and allowed?(child.meta().parents, parent_type)
    else
      _ -> false
    end
  end

  defp allowed?(:any, _type), do: true
  defp allowed?(types, type) when is_list(types), do: type in Enum.map(types, &to_string/1)
end
