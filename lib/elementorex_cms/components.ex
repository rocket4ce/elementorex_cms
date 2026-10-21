defmodule ElementorexCms.Components do
  @moduledoc """
  Components to show documents on your site.

      import ElementorexCms.Components

      <.document document={@page.body} />

  The document is normalized (see `ElementorexCms.Document.normalize/2`) and
  rendered with its stylesheet. Blocks use daisyUI 5 and Tailwind classes, so
  your Tailwind build has to scan the library (see the README).
  """

  use Phoenix.Component

  alias ElementorexCms.Document
  alias ElementorexCms.Renderer
  alias ElementorexCms.Style

  @doc """
  Renders a document.

  ## Attributes

    * `document` - the document map (`nil` renders nothing)
    * `registry` - blocks to use (default `ElementorexCms.Registry.default/0`)
    * `data` - extra data for blocks that need it (`@ctx.data` in the block)
    * `class` - classes for the root element
    * `locale` - language of the texts the blocks add themselves (countdown
      units, placeholders…); default: the locale of the process (see
      `ElementorexCms.I18n`)
  """
  attr :document, :map, default: nil
  attr :registry, :any, default: nil
  attr :data, :map, default: %{}
  attr :mode, :atom, default: :public, values: [:public, :editor]
  attr :class, :any, default: nil
  attr :locale, :string, default: nil

  def document(%{document: nil} = assigns), do: ~H""

  # Blocks translate while they render, so with a given locale the document is
  # rendered here, inside it, instead of lazily by LiveView.
  def document(%{locale: locale} = assigns) when is_binary(locale) do
    html =
      ElementorexCms.I18n.with_locale(locale, fn ->
        assigns |> Map.put(:locale, nil) |> document() |> Renderer.to_string_html()
      end)

    assigns = assign(assigns, :html, Phoenix.HTML.raw(html))

    ~H"{@html}"
  end

  def document(assigns) do
    ctx = Renderer.context(mode: assigns.mode, registry: assigns.registry, data: assigns.data)
    doc = Document.normalize(assigns.document, ctx.registry)

    root =
      doc
      |> Document.root()
      |> update_in(["attrs"], fn attrs ->
        class = [attrs["class"], assigns.class] |> List.flatten() |> Enum.filter(&is_binary/1)
        Map.put(attrs, "class", Enum.join(class, " "))
      end)

    assigns =
      assigns
      |> assign(:css, Style.css(doc, mode: assigns.mode))
      |> assign(:root, root)
      |> assign(:ctx, ctx)

    ~H"""
    <style :if={@css != ""} data-ex-style={@root["id"]}>
      <%= Phoenix.HTML.raw(@css) %>
    </style>
    {Renderer.render_node(@root, @ctx)}
    """
  end
end
