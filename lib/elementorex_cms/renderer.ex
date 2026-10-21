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
  alias ElementorexCms.Dynamic
  alias ElementorexCms.Registry
  alias ElementorexCms.Source
  alias ElementorexCms.Sources

  defmodule Context do
    @moduledoc """
    What a block knows about where it is rendered:

      * `mode` - `:public` (your site) or `:editor` (the canvas)
      * `registry` - the `ElementorexCms.Registry` in use
      * `data` - whatever the host passed (`data={%{brand: @brand}}`), for
        blocks that depend on the page
      * `depth` - nesting level of the node
      * `sources` - the `ElementorexCms.Sources` of dynamic content
      * `item` - the current item of dynamic content, or `nil`:
        `%{source: source, record: record, index: index, copy: copy?}`.
        `index` is its position in a loop (0 for the first) and `copy` is
        `true` on the canvas for the repetitions after the first one, which
        are shown but not edited
      * `loops` - how many loops the node is in
      * `params` - the query params of the page (string keys): loops read
        their page, search, sort and filters in theirs (`catalog[page]`)
      * `doc` - the document being rendered (when known): filter forms find
        the loop grid they filter in it
      * `form` - inside a filter form, what its fields need (see
        `ElementorexCms.Filters`)
    """
    defstruct mode: :public,
              registry: nil,
              data: %{},
              depth: 0,
              sources: nil,
              item: nil,
              loops: 0,
              params: %{},
              doc: nil,
              form: nil

    @type t :: %__MODULE__{
            mode: :public | :editor,
            registry: ElementorexCms.Registry.t(),
            data: map(),
            depth: non_neg_integer(),
            sources: ElementorexCms.Sources.t() | nil,
            item: map() | nil,
            loops: non_neg_integer(),
            params: map(),
            doc: map() | nil,
            form: map() | nil
          }
  end

  @max_depth 32

  @doc """
  A render context. Options: `:mode`, `:registry` (default
  `ElementorexCms.Registry.default/0`), `:data`, `:sources` (default
  `ElementorexCms.Sources.default/0`), `:params` (the query params of the
  page, for paginated loops) and, for documents that show one record (the
  template of a product page…), `:record` with its `:source` (a key, a source
  or a module; found from the record's schema when missing).
  """
  @spec context(keyword()) :: Context.t()
  def context(opts \\ []) do
    sources = Sources.new(opts[:sources])

    %Context{
      mode: Keyword.get(opts, :mode, :public),
      registry: opts[:registry] || Registry.default(),
      data: Keyword.get(opts, :data, %{}),
      sources: sources,
      item: item(sources, opts[:source], opts[:record]),
      params: params(opts[:params]),
      doc: opts[:doc]
    }
  end

  # The query params as they come from Plug (`catalog[price][min]` is nested
  # maps), keeping only text, lists of text and maps of them, within limits.
  @doc false
  def params(params, depth \\ 0)

  def params(%{} = params, depth) when depth < 3 do
    params
    |> Enum.take(100)
    |> Enum.flat_map(fn {key, value} ->
      case param(value, depth) do
        nil -> []
        value -> [{to_string(key), value}]
      end
    end)
    |> Map.new()
  end

  def params(_params, _depth), do: %{}

  defp param(value, _depth) when is_binary(value) do
    if String.valid?(value), do: String.slice(value, 0, 500)
  end

  defp param(values, _depth) when is_list(values) do
    values |> Enum.filter(&(is_binary(&1) and String.valid?(&1))) |> Enum.take(50)
  end

  defp param(%{} = value, depth) when depth < 2, do: params(value, depth + 1)
  defp param(_value, _depth), do: nil

  defp item(_sources, _source, nil), do: nil

  defp item(sources, source, record) do
    source =
      case source do
        %Source{} = source -> source
        nil -> Sources.for_record(sources, record)
        key when is_binary(key) -> Sources.fetch(sources, key)
        module when is_atom(module) -> Source.new(module)
        {_adapter, _opts} = spec -> Source.new(spec)
      end

    %{source: source, record: record, index: 0, copy: false}
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
        # A display condition that fails removes the node from the site; the
        # canvas keeps it, dimmed (see ElementorexCms.Block.Helpers.root/2).
        if ctx.mode == :editor or Dynamic.visible?(node, ctx) do
          block
          |> Block.assigns(Dynamic.resolve(node, block, ctx))
          |> Map.merge(%{node: node, ctx: %{ctx | depth: ctx.depth + 1}, __changed__: nil})
          |> block.render()
        else
          ""
        end
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

  Options: `:mode`, `:registry`, `:data`, `:sources`, `:record`, `:source` and
  `:params` (like `context/1`), `:locale` (the language of the texts the blocks add, see
  `ElementorexCms.I18n`) and, for documents, `:class`.
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
      sources: opts[:sources],
      record: opts[:record],
      source: opts[:source],
      params: opts[:params],
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
