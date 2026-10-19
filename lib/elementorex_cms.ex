defmodule ElementorexCms do
  @moduledoc """
  A visual, drag & drop content builder for Phoenix LiveView.

  The pieces:

    * `ElementorexCms.Document` - the content: a JSON tree of nodes you store in
      a `jsonb` column (`ElementorexCms.Ecto.Document`)
    * `ElementorexCms.Block` - the components a document is made of. The
      library ships 34 blocks built with daisyUI 5 and Heroicons; write your own
      with `mix elementorex.gen.block`
    * `ElementorexCms.Components.document/1` - renders a document on your site,
      with its CSS, safely (everything is sanitized again on render)
    * `ElementorexCms.Editor` - the editor, a LiveComponent: palette, DOM tree,
      canvas with your site's CSS in an iframe, inspector (*Content*, *Style*,
      *Advanced*), HTML/CSS/JSON view, undo and redo

  See the README for the installation steps and `mix elementorex.install` to
  check them.
  """

  @version Mix.Project.config()[:version]

  @doc "Version of the library."
  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Renders a document to an HTML string (with its `<style>`). Shortcut for
  `ElementorexCms.Renderer.to_html/2`.
  """
  @spec to_html(map(), keyword()) :: String.t()
  defdelegate to_html(document, opts \\ []), to: ElementorexCms.Renderer

  @doc """
  Plain text of a document (for excerpts and search). Text of headings,
  paragraphs, buttons and list items, in order.
  """
  @spec to_text(map()) :: String.t()
  def to_text(%{"root" => _} = document) do
    document
    |> ElementorexCms.Document.normalize()
    |> ElementorexCms.Document.nodes()
    |> Enum.flat_map(&texts/1)
    |> Enum.map(&ElementorexCms.HTML.Sanitizer.text/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  def to_text(_document), do: ""

  @text_props ~w(text label title badge caption author role)

  defp texts(%{"props" => props}) do
    direct = for key <- @text_props, value = props[key], is_binary(value), do: value

    items =
      for {_key, items} <- props,
          is_list(items),
          item <- items,
          is_map(item),
          {field, value} <- item,
          field in ["text", "title", "label", "content", "value"],
          is_binary(value),
          do: value

    direct ++ items
  end
end
