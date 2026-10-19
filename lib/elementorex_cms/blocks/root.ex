defmodule ElementorexCms.Blocks.Root do
  @moduledoc """
  The root of every document. It is not in the palette and cannot be removed;
  select it in the tree to style the whole document (padding, background...) or
  to write CSS for it.
  """

  use ElementorexCms.Block,
    type: "root",
    label: "Document",
    icon: "document",
    category: :layout,
    container: true,
    palette: false

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: "exr-doc flex flex-col", attrs: [{"data-ex-doc", @node["id"]}])}>
      <.children node={@node} ctx={@ctx} placeholder="Drag components here to start" />
    </div>
    """
  end
end
