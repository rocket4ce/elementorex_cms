defmodule ElementorexCms.Renderer do
  @moduledoc """
  Renders documents and nodes with the blocks of a registry.

  `ElementorexCms.Components.document/1` is the usual entry point in templates;
  this module is the engine underneath, plus `to_html/2` to get a string (emails,
  caches, the editor canvas).

  Every value reaches the blocks cast and sanitized again (see
  `ElementorexCms.Block.assigns/2`), and documents are normalized before being
  rendered, so a stored document cannot inject markup, script or CSS even if it
  was edited by hand.
  """

  alias ElementorexCms.Block
  alias ElementorexCms.Document
  alias ElementorexCms.Registry

  defmodule Context do
    @moduledoc """
    What a block knows about where it is rendered:

      * `mode` - `:public` (your site) or `:editor` (the canvas)
      * `registry` - the `ElementorexCms.Registry` in use
      * `data` - whatever the host passed (`data={%{brand: @brand}}`), for
        blocks that depend on the page
      * `depth` - nesting level of the node
    """
    defstruct mode: :public, registry: nil, data: %{}, depth: 0

    @type t :: %__MODULE__{
            mode: :public | :editor,
            registry: ElementorexCms.Registry.t(),
            data: map(),
            depth: non_neg_integer()
          }
  end

  @max_depth 32

  @doc """
  A render context. Options: `:mode`, `:registry` (default
  `ElementorexCms.Registry.default/0`) and `:data`.
  """
  @spec context(keyword()) :: Context.t()
  def context(opts \\ []) do
    %Context{
      mode: Keyword.get(opts, :mode, :public),
      registry: opts[:registry] || Registry.default(),
      data: Keyword.get(opts, :data, %{})
    }
  end

  @doc "Renders one node (and its children) with its block."
  @spec render_node(map(), Context.t()) :: Phoenix.LiveView.Rendered.t() | String.t()
  def render_node(node, %Context{depth: depth}) when depth > @max_depth or not is_map(node),
    do: ""

  def render_node(node, %Context{} = ctx) do
    case Registry.fetch(ctx.registry, node["type"]) do
      nil ->
        unknown(node, ctx)

      block ->
        block
        |> Block.assigns(node["props"] || %{})
        |> Map.merge(%{node: node, ctx: %{ctx | depth: ctx.depth + 1}, __changed__: nil})
        |> block.render()
    end
  end

  defp unknown(%{"id" => id, "type" => type}, %Context{mode: :editor}) do
    Phoenix.HTML.raw(
      ~s(<div data-ex-id="#{id}" data-ex-type="unknown" class="exr-unknown">) <>
        Phoenix.HTML.safe_to_string(
          Phoenix.HTML.html_escape(ElementorexCms.I18n.t("Unknown block: %{type}", type: type))
        ) <>
        "</div>"
    )
  end

  defp unknown(_node, _ctx), do: ""

  @doc """
  HTML of a whole document (its `<style>` included) or of a single node, as a
  string.

  Options: `:mode`, `:registry`, `:data` (like `context/1`), `:locale` (the
  language of the texts the blocks add, see `ElementorexCms.I18n`) and, for
  documents, `:class`.
  """
  @spec to_html(Document.t() | map(), keyword()) :: String.t()
  def to_html(doc_or_node, opts \\ [])

  def to_html(%{"root" => _} = doc, opts) do
    assigns = %{
      document: doc,
      registry: opts[:registry],
      data: Keyword.get(opts, :data, %{}),
      mode: Keyword.get(opts, :mode, :public),
      class: opts[:class],
      __changed__: nil
    }

    ElementorexCms.I18n.with_locale(opts[:locale], fn ->
      assigns
      |> ElementorexCms.Components.document()
      |> to_string_html()
    end)
  end

  def to_html(%{"type" => _} = node, opts) do
    ElementorexCms.I18n.with_locale(opts[:locale], fn ->
      node
      |> render_node(context(opts))
      |> to_string_html()
    end)
  end

  @doc false
  def to_string_html(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
