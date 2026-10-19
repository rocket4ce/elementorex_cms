defmodule ElementorexCms.Block.Helpers do
  @moduledoc """
  Helpers imported into every block (`use ElementorexCms.Block`).

  The important one is `root/2`: spread it on the root element of the block.

      <a href={@url} {root(assigns, class: ["btn", @wide && "btn-block"])}>...</a>
  """

  use Phoenix.Component

  alias ElementorexCms.Heroicons
  alias ElementorexCms.HTML.Sanitizer
  alias ElementorexCms.I18n
  alias ElementorexCms.Renderer

  @doc """
  Attributes for the root element of a block.

    * `data-ex-id` - the node id; the node's CSS is scoped to it
    * `id` and `class` from the *Advanced* tab, merged with `:class`
    * on the canvas, `data-ex-type` and `data-ex-container` for the editor

  Options:

    * `:class` - classes of the block (string, list, `nil`/`false` are skipped)
    * `:style` - inline style string, written as is (build it from validated
      values only)
    * `:attrs` - extra attributes (`[{"role", "alert"}]`)
  """
  @spec root(map(), keyword()) :: [{String.t(), term()}]
  def root(assigns, opts \\ []) do
    node = assigns.node
    ctx = assigns.ctx
    attrs = node["attrs"] || %{}

    classes = class_list([opts[:class], attrs["class"]])

    editor =
      if ctx.mode == :editor do
        meta = ctx.registry |> ElementorexCms.Registry.fetch(node["type"]) |> meta_of()

        [{"data-ex-type", node["type"]}] ++
          if(meta[:container], do: [{"data-ex-container", "true"}], else: []) ++
          if(attrs["label"] not in [nil, ""], do: [{"data-ex-label", attrs["label"]}], else: [])
      else
        []
      end

    [{"data-ex-id", node["id"]}] ++
      editor ++
      if(attrs["id"] not in [nil, ""], do: [{"id", attrs["id"]}], else: []) ++
      if(classes != "", do: [{"class", classes}], else: []) ++
      if(opts[:style] not in [nil, false, ""], do: [{"style", opts[:style]}], else: []) ++
      Keyword.get(opts, :attrs, [])
  end

  defp meta_of(nil), do: %{}
  defp meta_of(block), do: block.meta()

  @doc """
  Marks the element that holds an inline-editable prop: on the canvas the user
  double-clicks it to type. Outside the editor it adds nothing.

      <h2 {inline(assigns, :text)}>{@text}</h2>
  """
  @spec inline(map(), atom() | String.t()) :: [{String.t(), String.t()}]
  def inline(%{ctx: %{mode: :editor} = ctx, node: node}, prop) do
    kind =
      with block when not is_nil(block) <-
             ElementorexCms.Registry.fetch(ctx.registry, node["type"]),
           %{type: :richtext, policy: policy} <- ElementorexCms.Block.find_prop(block, prop) do
        if policy == :inline, do: "inline", else: "rich"
      else
        _ -> "text"
      end

    [{"data-ex-inline", to_string(prop)}, {"data-ex-inline-kind", kind}]
  end

  def inline(_assigns, _prop), do: []

  @doc "Whether the block is being rendered on the editor canvas."
  @spec editor?(map()) :: boolean()
  def editor?(%{ctx: %{mode: :editor}}), do: true
  def editor?(_assigns), do: false

  @doc """
  Renders the children of a container. On the canvas, an empty container shows a
  drop zone.
  """
  attr :node, :map, required: true
  attr :ctx, :any, required: true
  attr :placeholder, :string, default: nil

  def children(assigns) do
    assigns = assign(assigns, :nodes, assigns.node["children"] || [])

    ~H"""
    <%= for child <- @nodes do %>
      {Renderer.render_node(child, @ctx)}
    <% end %>
    <div :if={@nodes == [] and @ctx.mode == :editor} class="exr-empty" data-ex-placeholder>
      {I18n.t(@placeholder || "Drag a component here")}
    </div>
    """
  end

  @doc """
  An icon from Heroicons, inline SVG (works with any icon name chosen in the
  editor, see `ElementorexCms.Heroicons`).
  """
  attr :name, :string, required: true
  attr :style, :string, default: "outline"
  attr :class, :any, default: nil
  attr :rest, :global

  def heroicon(assigns) do
    ~H"""
    <Heroicons.icon :if={@name not in [nil, ""]} name={@name} style={@style} class={@class} {@rest} />
    """
  end

  @doc "Sanitized rich text (`:rich` policy) as safe HTML."
  @spec rich(String.t() | nil) :: Phoenix.HTML.safe()
  def rich(html), do: Phoenix.HTML.raw(Sanitizer.sanitize(html || "", :rich))

  @doc "Sanitized inline HTML (`:inline` policy) as safe HTML."
  @spec rich_inline(String.t() | nil) :: Phoenix.HTML.safe()
  def rich_inline(html), do: Phoenix.HTML.raw(Sanitizer.sanitize(html || "", :inline))

  @doc """
  `href`, `target` and `rel` for a link. An empty URL gives no `href` (on the
  canvas links never navigate anyway).
  """
  @spec link_attrs(String.t() | nil, boolean()) :: [{String.t(), String.t()}]
  def link_attrs(url, new_tab \\ false)
  def link_attrs(url, _new_tab) when url in [nil, ""], do: []

  def link_attrs(url, true),
    do: [{"href", url}, {"target", "_blank"}, {"rel", "noopener noreferrer"}]

  def link_attrs(url, _new_tab), do: [{"href", url}]

  @doc "Translates a string of the block (see `ElementorexCms.I18n`)."
  @spec t(String.t(), keyword()) :: String.t()
  def t(text, bindings \\ []), do: I18n.t(text, bindings)

  @doc "Joins classes, skipping `nil`, `false` and empty strings."
  @spec class_list(term()) :: String.t()
  def class_list(classes) do
    classes
    |> List.wrap()
    |> List.flatten()
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.join(" ")
  end

  @doc """
  Inline style from validated declarations: `[{"max-width", "640px"}]` →
  `"max-width:640px"`. Invalid values are dropped (see `ElementorexCms.CSS`).
  """
  @spec style(list()) :: String.t()
  def style(declarations) do
    declarations
    |> Enum.flat_map(fn {property, value} ->
      case ElementorexCms.CSS.value(to_string(property), value) do
        nil -> []
        valid -> ["#{property}:#{valid}"]
      end
    end)
    |> Enum.join(";")
  end
end
