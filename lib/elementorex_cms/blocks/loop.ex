defmodule ElementorexCms.Blocks.Loop do
  @moduledoc """
  Loop grid: repeats its content for every item of a source (products, posts…)
  in a responsive grid. The blocks inside bind their props to the fields of the
  item (see `ElementorexCms.Dynamic`), so one card designed in the editor
  becomes the card of every product.

  The query: how many items, from which one, the order and filters on the
  fields of the source. In the template of an item (a product page), *Same as
  the current item* filters and *Leave out the current item* make lists of
  related items.

  ## Pagination and visitors' filters

  The state of the loop goes in the query string of the page under its key,
  its CSS ID (*Advanced* tab) or its node id: `?catalog[page]=2`. *Filters*
  forms (`ElementorexCms.Blocks.Filters`) add the visitor's search, order and
  filters there (see `ElementorexCms.Filters`), and the loop applies them on
  top of its own query.

  *Numbers*, *Previous / Next* (or both) link to the other pages, keeping the
  filters. *Load more button* and *Infinite scroll*
  fetch the next page in the background and append its items (the runtime of
  the site: the `ElementorexRuntime` hook or `initElementorex()`); without
  JavaScript they are links to the next page. The page the loop shows comes
  from the `params` of the document:

      <ElementorexCms.Components.document document={@page.body} params={@params} />

  Numbered pages need to count the items: sources without
  `c:ElementorexCms.Source.count/2` get *Previous* and *Next* instead.

  On the canvas the first item can be edited and the others follow it; without
  items, the content is shown once with its own values as placeholders. Loops
  render inside at most one other loop, and only loops that are in no other
  loop have pages.
  """

  use ElementorexCms.Block,
    type: "loop",
    label: "Loop grid",
    icon: "squares-plus",
    category: :dynamic,
    description: "Repeats its content for every item of a collection",
    keywords:
      ~w(loop query collection list repeat products posts dynamic pagination infinite bucle coleccion productos dinamico paginacion),
    container: true,
    loop: true

  alias ElementorexCms.Blocks.Options
  alias ElementorexCms.Filters
  alias ElementorexCms.I18n
  alias ElementorexCms.Source
  alias ElementorexCms.Source.Query
  alias ElementorexCms.Sources

  @ops [
    {"Is", "eq"},
    {"Is not", "neq"},
    {"Contains", "contains"},
    {"Greater than", "gt"},
    {"At least", "gte"},
    {"Less than", "lt"},
    {"At most", "lte"},
    {"Has a value", "set"},
    {"Is empty", "unset"},
    {"Same as the current item", "same"}
  ]

  @counts ~w(1 2 3 4 5 6)
  @max_loops 2
  @nested_limit 24
  @paged ~w(numbers prev_next numbers_prev_next load_more infinite)
  @max_page 10_000

  prop(:source, :source, label: "Collection")

  prop(:limit, :integer,
    label: "Items",
    default: 6,
    min: 1,
    max: 100,
    help: "Per page when the grid has pages"
  )

  prop(:order_by, :field, label: "Order by", only: :sortable)

  prop(:order, :select,
    label: "Direction",
    options: [{"Ascending", "asc"}, {"Descending", "desc"}],
    default: "asc",
    control: :segmented,
    show_if: {:order_by, :present}
  )

  prop(:filters, :list,
    label: "Filters",
    item_label: :field,
    max_items: 8,
    default: [],
    fields: [
      {:field, :field, label: "Field", only: :filterable},
      {:op, :select, label: "Condition", options: @ops, default: "eq"},
      {:value, :string, label: "Value"}
    ]
  )

  prop(:exclude_current, :boolean,
    label: "Leave out the current item",
    default: false,
    help: "In the template of an item, for lists of related items"
  )

  prop(:offset, :integer,
    label: "Skip",
    default: 0,
    min: 0,
    max: 1000,
    help: "Items to leave out at the start"
  )

  prop(:columns, :select,
    label: "Columns",
    options: @counts,
    default: "3",
    control: :segmented,
    group: "Layout"
  )

  prop(:columns_tablet, :select,
    label: "Columns on tablet",
    options: [{"Same", "same"} | Enum.map(@counts, &{&1, &1})],
    default: "2",
    control: :segmented,
    group: "Layout"
  )

  prop(:columns_mobile, :select,
    label: "Columns on mobile",
    options: @counts,
    default: "1",
    control: :segmented,
    group: "Layout"
  )

  prop(:gap, :select,
    label: "Gap",
    options: Options.gaps(),
    default: "6",
    control: :segmented,
    group: "Layout"
  )

  prop(:empty_text, :string,
    label: "Text when there are no items",
    default: "Nothing to show yet.",
    group: "Layout"
  )

  prop(:pagination, :select,
    label: "Pagination",
    options: [
      {"None", "none"},
      {"Numbers", "numbers"},
      {"Previous / Next", "prev_next"},
      {"Numbers and Previous / Next", "numbers_prev_next"},
      {"Load more button", "load_more"},
      {"Infinite scroll", "infinite"}
    ],
    default: "none",
    group: "Pagination"
  )

  prop(:page_limit, :integer,
    label: "Page limit",
    default: 0,
    min: 0,
    max: 100,
    help: "0 for no limit",
    group: "Pagination",
    show_if: {:pagination, @paged}
  )

  prop(:prev_label, :string,
    label: "Previous text",
    default: "Previous",
    group: "Pagination",
    show_if: {:pagination, ~w(prev_next numbers_prev_next)}
  )

  prop(:next_label, :string,
    label: "Next text",
    default: "Next",
    group: "Pagination",
    show_if: {:pagination, ~w(prev_next numbers_prev_next)}
  )

  prop(:more_label, :string,
    label: "Button text",
    default: "Load more",
    group: "Pagination",
    show_if: {:pagination, ~w(load_more infinite)}
  )

  prop(:pagination_align, :select,
    label: "Alignment",
    options: Options.alignments(),
    default: "center",
    control: :segmented,
    group: "Pagination",
    show_if: {:pagination, @paged}
  )

  @desktop %{
    "1" => "grid-cols-1",
    "2" => "grid-cols-2",
    "3" => "grid-cols-3",
    "4" => "grid-cols-4",
    "5" => "grid-cols-5",
    "6" => "grid-cols-6"
  }
  @tablet %{
    "1" => "max-lg:grid-cols-1",
    "2" => "max-lg:grid-cols-2",
    "3" => "max-lg:grid-cols-3",
    "4" => "max-lg:grid-cols-4",
    "5" => "max-lg:grid-cols-5",
    "6" => "max-lg:grid-cols-6"
  }
  @mobile %{
    "1" => "max-md:grid-cols-1",
    "2" => "max-md:grid-cols-2",
    "3" => "max-md:grid-cols-3",
    "4" => "max-md:grid-cols-4",
    "5" => "max-md:grid-cols-5",
    "6" => "max-md:grid-cols-6"
  }
  @gaps %{
    "0" => "gap-0",
    "1" => "gap-1",
    "2" => "gap-2",
    "4" => "gap-4",
    "6" => "gap-6",
    "8" => "gap-8",
    "12" => "gap-12"
  }
  @justify %{"left" => "justify-start", "center" => "justify-center", "right" => "justify-end"}

  @doc "Conditions of the filters: `[{label, op}]`."
  def ops, do: @ops

  def render(assigns) do
    pager = pager(assigns)
    assigns = assign(assigns, pager: pager, result: result(assigns, pager))

    ~H"""
    <div {root(assigns, class: ["grid w-full", Map.get(desktop(), @columns), Map.get(tablet(), @columns_tablet), Map.get(mobile(), @columns_mobile), Map.get(gaps(), @gap)], attrs: anchor_attrs(@node, @ctx))}>
      <%= case @result do %>
        <% {:items, items, page} -> %>
          <div
            :for={{item_ctx, index} <- items}
            class="flex min-w-0 flex-col gap-3 [&>:only-child]:grow"
            data-ex-loop-item={index}
            data-ex-loop-copy={item_ctx.item.copy && "true"}
          >
            <.children node={@node} ctx={item_ctx} />
          </div>
          <.pagination
            :if={page}
            page={page}
            pagination={@pagination}
            prev_label={@prev_label}
            next_label={@next_label}
            more_label={@more_label}
            justify={Map.get(justify(), @pagination_align)}
            editor={editor?(assigns)}
          />
        <% {:template, template_ctx, hint} -> %>
          <div class="flex min-w-0 flex-col gap-3 [&>:only-child]:grow" data-ex-loop-item="0">
            <.children node={@node} ctx={template_ctx} placeholder="Drag here the blocks of one item" />
          </div>
          <p :if={hint} class="exr-loop-hint">{hint}</p>
        <% {:empty, text, page} -> %>
          <p :if={text != ""} class="col-span-full py-6 text-center opacity-70">{text}</p>
          <%!-- Past the last page: a way back --%>
          <.pagination
            :if={page && page.prev}
            page={%{page | next: nil, numbers: []}}
            pagination="prev_next"
            prev_label={@prev_label}
            next_label={@next_label}
            more_label={@more_label}
            justify={Map.get(justify(), @pagination_align)}
          />
      <% end %>
    </div>
    """
  end

  attr :page, :map, required: true
  attr :pagination, :string, required: true
  attr :prev_label, :string, required: true
  attr :next_label, :string, required: true
  attr :more_label, :string, required: true
  attr :justify, :string, default: nil
  attr :editor, :boolean, default: false

  # The links to the pages, or the button that loads the next one (a sentinel
  # for infinite scroll). It is the last cell of the grid, across its columns.
  defp pagination(%{pagination: mode} = assigns) when mode in ["load_more", "infinite"] do
    ~H"""
    <div
      :if={@page.next || @editor}
      class={["col-span-full flex items-center gap-3", @justify]}
      data-ex-loop-more={if(@pagination == "infinite", do: "scroll", else: "click")}
      data-ex-next={@page.next && @page.next.query}
    >
      <a class="btn btn-outline" href={@page.next && @page.next.href} rel="next" data-ex-loop-button>
        {@more_label}
      </a>
      <span class="loading loading-dots loading-md hidden" aria-hidden="true" data-ex-loop-loading></span>
      <span :if={@editor and @pagination == "infinite"} class="exr-loop-hint">
        {t("More items load as the visitor scrolls")}
      </span>
    </div>
    """
  end

  defp pagination(assigns) do
    numbers? =
      assigns.pagination in ["numbers", "numbers_prev_next"] and assigns.page.numbers != []

    assigns =
      assign(assigns,
        numbers?: numbers?,
        # Numbers without a count (the source has no count/2) become arrows
        arrows?: assigns.pagination in ["prev_next", "numbers_prev_next"] or not numbers?
      )

    ~H"""
    <nav
      :if={@page.prev || @page.next || @editor}
      class={["col-span-full flex", @justify]}
      aria-label={t("Pages")}
      data-ex-loop-pages
    >
      <div class="join">
        <%= if @arrows? do %>
          <a :if={@page.prev} class="join-item btn btn-sm" href={@page.prev.href} rel="prev">
            <.heroicon name="chevron-left" style="mini" class="size-4" />{@prev_label}
          </a>
          <span :if={!@page.prev} class="join-item btn btn-sm btn-disabled">
            <.heroicon name="chevron-left" style="mini" class="size-4" />{@prev_label}
          </span>
        <% end %>
        <%= if @numbers? do %>
          <%= for link <- @page.numbers do %>
            <%= cond do %>
              <% link == :gap -> %>
                <span class="join-item btn btn-sm btn-disabled">…</span>
              <% link.current -> %>
                <span class="join-item btn btn-sm btn-active" aria-current="page">
                  {link.number}
                </span>
              <% true -> %>
                <a
                  class="join-item btn btn-sm"
                  href={link.href}
                  aria-label={t("Page %{n}", n: link.number)}
                >
                  {link.number}
                </a>
            <% end %>
          <% end %>
        <% end %>
        <%= if @arrows? do %>
          <a :if={@page.next} class="join-item btn btn-sm" href={@page.next.href} rel="next">
            {@next_label}<.heroicon name="chevron-right" style="mini" class="size-4" />
          </a>
          <span :if={!@page.next} class="join-item btn btn-sm btn-disabled">
            {@next_label}<.heroicon name="chevron-right" style="mini" class="size-4" />
          </span>
        <% end %>
      </div>
    </nav>
    """
  end

  # What the loop shows: the items (and their page), its content once (on the
  # canvas, when there is nothing to repeat yet) or the text for no items.
  defp result(%{ctx: ctx, node: node} = assigns, pager) do
    editor? = ctx.mode == :editor
    template_ctx = %{ctx | item: nil, loops: ctx.loops + 1}
    source = Sources.fetch(ctx.sources, assigns.source)

    cond do
      ctx.loops >= @max_loops ->
        if editor?,
          do: {:template, template_ctx, I18n.t("A loop can only be inside one other loop")},
          else: {:empty, "", nil}

      editor? and node["children"] == [] ->
        {:template, template_ctx, nil}

      assigns.source == "" or source == nil ->
        if editor?,
          do: {:template, template_ctx, I18n.t("Choose a collection in the Content tab")},
          else: {:empty, "", nil}

      true ->
        case fetch(source, assigns, pager, editor?) do
          {:ok, [], _page} when editor? ->
            {:template, template_ctx,
             I18n.t("%{collection} has no items yet: the content shows its own values",
               collection: I18n.t(source.label)
             )}

          {:ok, [], page} ->
            {:empty, assigns.empty_text, page}

          {:ok, records, page} ->
            # Items are numbered across pages (CSS ids of repetitions, loaded pages)
            first = if page, do: (page.number - 1) * pager.per_page, else: 0

            items =
              records
              |> Enum.with_index(first)
              |> Enum.map(fn {record, index} ->
                item = %{
                  source: source,
                  record: record,
                  index: index,
                  copy: editor? and index > 0
                }

                {%{ctx | item: item, loops: ctx.loops + 1}, index}
              end)

            {:items, items, page}

          {:error, message} ->
            {:template, template_ctx, message}
        end
    end
  end

  # A failing source must not take the editor (and unsaved work) down.
  defp fetch(source, assigns, pager, true = _editor?) do
    fetch(source, assigns, pager, false)
  rescue
    error ->
      {:error,
       I18n.t("The collection could not be loaded: %{error}",
         error: error |> Exception.message() |> String.slice(0, 200)
       )}
  end

  defp fetch(source, %{ctx: ctx} = assigns, nil, false) do
    context = %{mode: ctx.mode, data: ctx.data}
    {:ok, Source.list(source, visitor_query(source, assigns), context), nil}
  end

  defp fetch(source, %{ctx: ctx} = assigns, pager, false) do
    context = %{mode: ctx.mode, data: ctx.data}
    query = visitor_query(source, assigns)
    per_page = pager.per_page

    # Numbered pages count the items; a source without count/2 gets arrows.
    pages =
      with true <- assigns.pagination in ["numbers", "numbers_prev_next"],
           total when is_integer(total) <- Source.count(source, query, context) do
        (total - query.offset) |> max(0) |> div_up(per_page) |> max(1) |> limit_pages(pager)
      else
        _ -> nil
      end

    number = if pages, do: min(pager.number, pages), else: pager.number

    # One more than a page tells whether there is a next one.
    paged = %{query | offset: query.offset + (number - 1) * per_page, limit: per_page + 1}
    records = Source.list(source, paged, context)

    more? =
      if pages,
        do: number < pages,
        else: length(records) > per_page and (pager.page_limit == 0 or number < pager.page_limit)

    {:ok, Enum.take(records, per_page), page(pager, number, pages, more?)}
  end

  # The loop's query with the visitor's search, order and filters (loops in
  # no other loop: the others would share them across their repetitions).
  defp visitor_query(source, %{ctx: %{loops: 0} = ctx, node: node} = assigns) do
    state = Filters.state(ctx.params, Filters.key(node))
    source |> query(assigns) |> Filters.apply(state, source)
  end

  defp visitor_query(source, assigns), do: query(source, assigns)

  defp div_up(count, per_page), do: div(count + per_page - 1, per_page)

  defp limit_pages(pages, %{page_limit: 0}), do: pages
  defp limit_pages(pages, %{page_limit: limit}), do: min(pages, limit)

  @doc false
  # The query of the loop's props for `source`, in the context of the current item.
  def query(source, %{ctx: ctx} = assigns) do
    limit = if ctx.loops > 0, do: min(assigns.limit || 6, @nested_limit), else: assigns.limit || 6

    %Query{
      limit: max(limit, 1),
      offset: max(assigns.offset || 0, 0),
      order_by: if(assigns.order_by == "", do: nil, else: assigns.order_by),
      order: if(assigns.order == "desc", do: :desc, else: :asc),
      filters: Enum.flat_map(assigns.filters, &filter(&1, ctx.item)),
      exclude: exclude(assigns.exclude_current, source, ctx.item)
    }
  end

  defp filter(%{"field" => field, "op" => "same"}, %{source: %Source{} = current, record: record})
       when field != "" do
    # The value the current item has in the same field.
    case Source.field(current, field) && Source.value(current, record, field) do
      nil -> [%{field: field, op: "unset", value: ""}]
      value -> [%{field: field, op: "eq", value: plain(value)}]
    end
  end

  defp filter(%{"op" => "same"}, _item), do: []

  defp filter(%{"field" => field, "op" => op} = item, _current) when field != "",
    do: [%{field: field, op: op, value: item["value"] || ""}]

  defp filter(_item, _current), do: []

  defp plain(value) when is_binary(value), do: value
  defp plain(value) when is_atom(value), do: Atom.to_string(value)

  defp plain(value) do
    if String.Chars.impl_for(value), do: to_string(value), else: ""
  end

  defp exclude(true, %Source{key: key} = source, %{source: %Source{key: key}, record: record}),
    do: [to_string(Source.id(source, record))]

  defp exclude(_exclude?, _source, _item), do: []

  ## Pages

  # How a paginated loop reads and links its pages, or nil. Loops inside other
  # loops have no pages: each repetition would need its own.
  defp pager(%{pagination: pagination, ctx: %{loops: 0} = ctx, node: node} = assigns)
       when pagination in @paged do
    key = Filters.key(node)
    page_limit = assigns.page_limit || 0

    %{
      key: key,
      anchor: anchor(node),
      per_page: max(assigns.limit || 6, 1),
      page_limit: page_limit,
      number: current_page(Filters.state(ctx.params, key)["page"], page_limit),
      # Links keep the filters of the loop and the state of the others
      params: ctx.params
    }
  end

  defp pager(_assigns), do: nil

  # The page comes from the address: a number from 1 to @max_page.
  defp current_page(value, page_limit) do
    page =
      case Integer.parse(to_string(value || "")) do
        {page, ""} when page > 0 -> min(page, @max_page)
        _ -> 1
      end

    if page_limit > 0, do: min(page, page_limit), else: page
  end

  defp page(pager, number, pages, more?) do
    %{
      number: number,
      prev: if(number > 1, do: link(pager, number - 1)),
      next: if(more?, do: link(pager, number + 1)),
      numbers:
        if pages do
          pages
          |> numbers(number)
          |> Enum.map(fn
            :gap -> :gap
            n -> %{link(pager, n) | current: n == number}
          end)
        else
          []
        end
    }
  end

  # 1 … 4 5 6 … 12: the first and last pages and the neighbours of the current one.
  defp numbers(pages, _current) when pages <= 7, do: Enum.to_list(1..pages)

  defp numbers(pages, current) do
    middle = Enum.to_list(max(current - 1, 2)..min(current + 1, pages - 1)//1)

    [1] ++
      if(hd(middle) > 2, do: [:gap], else: []) ++
      middle ++ if(List.last(middle) < pages - 1, do: [:gap], else: []) ++ [pages]
  end

  # `?catalog[page]=2#catalog`; page 1 leaves the param out.
  defp link(pager, number) do
    page = if number > 1, do: Integer.to_string(number)
    query = Filters.href(pager.params, pager.key, %{"page" => page})
    %{number: number, query: query, href: query <> "#" <> pager.anchor, current: false}
  end

  @doc false
  # Where links to the loop land: its CSS ID, or an id of its own.
  def anchor(node), do: get_in(node, ["attrs", "id"]) || "loop-" <> node["id"]

  # Loops in no other loop get an id of their own when they have no CSS ID:
  # pages and filters link to it.
  defp anchor_attrs(node, %{loops: 0}) do
    if get_in(node, ["attrs", "id"]), do: [], else: [{"id", anchor(node)}]
  end

  defp anchor_attrs(_node, _ctx), do: []

  defp desktop, do: @desktop
  defp tablet, do: @tablet
  defp mobile, do: @mobile
  defp gaps, do: @gaps
  defp justify, do: @justify
end
