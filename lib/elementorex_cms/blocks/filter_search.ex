defmodule ElementorexCms.Blocks.FilterSearch do
  @moduledoc """
  Search box of a *Filters* form: visitors look for a text in the searchable
  fields of the loop grid's source (`ElementorexCms.Source.searchable/1`).
  """

  use ElementorexCms.Block,
    type: "filter_search",
    label: "Search box",
    icon: "magnifying-glass",
    category: :dynamic,
    description: "Visitors search the loop grid by text",
    keywords: ~w(search query find text buscar busqueda texto),
    parents: ["filters"]

  alias ElementorexCms.Blocks.FilterField

  prop(:label, :string, label: "Label")
  prop(:placeholder, :string, label: "Placeholder", default: "Search…")

  def render(assigns) do
    if filter_form?(assigns) do
      ~H"""
      <label {root(assigns, class: "flex min-w-48 grow flex-col gap-1")}>
        <span :if={@label != ""} class="text-sm font-medium">{@label}</span>
        <span class="input w-full">
          <.heroicon name="magnifying-glass" class="size-4 opacity-60" />
          <input
            type="search"
            name={filter_name(assigns, "q")}
            value={filter_value(assigns, "q")}
            placeholder={@placeholder}
            autocomplete="off"
            class="grow"
            data-ex-filter-input="text"
          />
        </span>
      </label>
      """
    else
      FilterField.outside(%{assigns: assigns, __changed__: nil})
    end
  end
end
