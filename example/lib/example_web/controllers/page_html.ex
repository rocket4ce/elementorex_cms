defmodule ExampleWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use ExampleWeb, :html

  embed_templates "page_html/*"

  attr :id, :string, required: true
  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :text, :string, required: true

  defp feature_card(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@href}
      class="group flex flex-col gap-3 rounded-box border border-base-300 bg-base-100 p-6 transition hover:-translate-y-1 hover:border-primary hover:shadow-lg"
    >
      <span class="grid size-10 place-items-center rounded-field bg-primary/10 text-primary">
        <.icon name={@icon} class="size-5" />
      </span>
      <span class="flex items-center gap-1 font-semibold">
        {@title}
        <.icon
          name="hero-arrow-right-mini"
          class="size-4 opacity-0 transition group-hover:translate-x-1 group-hover:opacity-100"
        />
      </span>
      <span class="text-sm opacity-70">{@text}</span>
    </.link>
    """
  end
end
