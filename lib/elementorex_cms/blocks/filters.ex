defmodule ElementorexCms.Blocks.Filters do
  @moduledoc """
  Filters: a form with which visitors search, filter and order a loop grid of
  the page (*Loop grid*, `ElementorexCms.Blocks.Loop`).

  Its fields are blocks: *Search box*, *Choice filter* (a dropdown, radio
  buttons, checkboxes or buttons with the values of a field), *Range filter*,
  *Toggle filter* and *Sort*, next to headings, text or blocks of your own (see
  `ElementorexCms.Filters` to write them). It applies on every change or with
  a button, and can have a button to clear the filters.

  The form sends the filters in the query string (`?catalog[category]=Shoes`):
  without JavaScript the page reloads with them; with the runtime of the site
  only the loop grid is replaced. Its target is a loop grid of the same
  document (the first one when none is chosen).
  """

  use ElementorexCms.Block,
    type: "filters",
    label: "Filters",
    icon: "funnel",
    category: :dynamic,
    description: "Search and filters visitors use on a loop grid",
    keywords: ~w(filter filters search form facets sort buscador filtros busqueda ordenar),
    container: true

  alias ElementorexCms.Blocks.Loop
  alias ElementorexCms.Blocks.Options
  alias ElementorexCms.Filters

  prop(:target, :loop, label: "Loop grid", help: "Empty: the first loop grid of the page")

  prop(:submit, :select,
    label: "Apply",
    options: [{"On every change", "change"}, {"With a button", "button"}],
    default: "change",
    control: :segmented
  )

  prop(:button_label, :string, label: "Button text", default: "Filter")

  prop(:reset, :boolean, label: "Clear button", default: true)

  prop(:reset_label, :string,
    label: "Clear text",
    default: "Clear filters",
    show_if: {:reset, true}
  )

  prop(:layout, :select,
    label: "Layout",
    options: [{"Row", "row"}, {"Column", "column"}],
    default: "row",
    control: :segmented,
    group: "Look"
  )

  prop(:gap, :select,
    label: "Gap",
    options: Options.gaps(),
    default: "4",
    control: :segmented,
    group: "Look"
  )

  @layouts %{"row" => "flex-row flex-wrap items-end", "column" => "flex-col items-stretch"}
  @gaps %{
    "0" => "gap-0",
    "1" => "gap-1",
    "2" => "gap-2",
    "4" => "gap-4",
    "6" => "gap-6",
    "8" => "gap-8",
    "12" => "gap-12"
  }

  def render(assigns) do
    target = Filters.target(assigns.ctx, assigns.target)

    assigns =
      if target do
        form = Filters.form(assigns.ctx, target)

        assign(assigns,
          target: target,
          form_ctx: %{assigns.ctx | form: form},
          hidden: Filters.hidden_inputs(assigns.ctx.params, target.key),
          active?: Filters.active?(form.state),
          reset_href:
            Filters.href(assigns.ctx.params, target.key, :reset) <>
              "#" <> Loop.anchor(target.node)
        )
      else
        assign(assigns,
          target: nil,
          form_ctx: assigns.ctx,
          hidden: [],
          active?: false,
          reset_href: nil
        )
      end

    ~H"""
    <%!-- Without a loop grid to filter, nothing on the site --%>
    <div :if={!@target and !editor?(assigns)} {root(assigns, attrs: [{"hidden", true}])}></div>
    <form
      :if={@target || editor?(assigns)}
      {root(assigns,
        class: ["flex w-full", Map.get(layouts(), @layout), Map.get(gaps(), @gap)],
        attrs: form_attrs(@target, @submit)
      )}
    >
      <input :for={{name, value} <- @hidden} type="hidden" name={name} value={value} />
      <.children node={@node} ctx={@form_ctx} placeholder="Drag here the fields of the filters" />
      <div class="flex flex-wrap items-center gap-2">
        <button :if={@submit == "button"} type="submit" class="btn btn-primary" data-ex-filters-button>
          {@button_label}
        </button>
        <%!-- Without JavaScript, a form that applies on change needs a button --%>
        <noscript :if={@submit == "change"}>
          <button type="submit" class="btn btn-primary">{@button_label}</button>
        </noscript>
        <a
          :if={@reset}
          href={@reset_href}
          class="btn btn-ghost"
          hidden={!@active? and !editor?(assigns)}
          data-ex-filters-reset
        >
          <.heroicon name="x-mark" class="size-4" />{@reset_label}
        </a>
      </div>
      <p :if={!@target} class="exr-loop-hint">
        {t("Add a loop grid to the page: the filters work on it")}
      </p>
    </form>
    """
  end

  defp form_attrs(nil, _submit), do: [{"role", "search"}]

  defp form_attrs(target, submit) do
    [
      {"method", "get"},
      {"role", "search"},
      {"data-ex-filters", target.key},
      {"data-ex-loop", target.node["id"]},
      {"data-ex-filters-submit", submit}
    ]
  end

  defp layouts, do: @layouts
  defp gaps, do: @gaps
end
