defmodule ElementorexCms.Blocks.FilterField do
  @moduledoc false
  # What the fields of a filter form share: their label and what they show
  # outside a form (nothing on the site, a hint on the canvas).

  use Phoenix.Component

  import ElementorexCms.Block.Helpers

  @doc "The label of a field: the one written, or the name of the field of the source."
  def label(assigns, field_key) do
    case assigns[:label] do
      label when is_binary(label) and label != "" ->
        label

      _ ->
        case field_key && filter_field(assigns, field_key) do
          nil -> ""
          field -> t(field.label)
        end
    end
  end

  @doc """
  A field of a filter form that is in no form (or whose form has no loop
  grid): a hint on the canvas, an empty hidden element on the site.
  """
  attr :assigns, :map, required: true

  def outside(%{assigns: block} = assigns) do
    assigns = assign(assigns, :editor?, editor?(block))

    ~H"""
    <p :if={@editor?} {root(@assigns, class: "exr-loop-hint")}>
      {t("Put it in a Filters block that filters a loop grid")}
    </p>
    <div :if={!@editor?} {root(@assigns, attrs: [{"hidden", true}])}></div>
    """
  end
end
