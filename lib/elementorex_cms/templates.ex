defmodule ElementorexCms.Templates do
  @moduledoc """
  Ready-made sections the editor can insert (*Templates* panel).

  Add your own with a module that implements this behaviour and list it in the
  config (or pass `templates={...}` to the editor):

      defmodule MyApp.EditorTemplates do
        @behaviour ElementorexCms.Templates
        import ElementorexCms.Builder

        @impl true
        def templates do
          [
            %{
              key: "promo",
              label: "Promotion",
              description: "Headline, countdown and button",
              icon: "megaphone",
              nodes: fn -> [block("heading", %{text: "Black Friday"}), block("countdown")] end
            }
          ]
        end
      end

      config :elementorex_cms, templates: [MyApp.EditorTemplates]

  `nodes` is a function so every insertion gets fresh ids.

  ## Dynamic templates

  Templates can repeat the items of a source and bind blocks to their fields
  (`ElementorexCms.Builder.loop/4` and `dynamic:`). Give them a `:source` key
  and the editor only offers them when that source is available:

      %{
        key: "featured_products",
        label: "Featured products",
        source: "products",
        nodes: fn ->
          [loop("products", [block("card", %{}, dynamic: %{title: "name"})], %{limit: 3})]
        end
      }

  The editor also makes templates from the fields of every source on its own
  (`for_sources/2`): a grid and a list of its items and, in a template for the
  pages of a source, the page of one item.
  """

  import ElementorexCms.Builder
  import ElementorexCms.I18n, only: [t: 1, t: 2]

  alias ElementorexCms.Source
  alias ElementorexCms.Sources

  @type template :: %{
          required(:key) => String.t(),
          required(:label) => String.t(),
          required(:nodes) => (-> [map()]),
          optional(:description) => String.t(),
          optional(:icon) => String.t(),
          optional(:source) => String.t(),
          optional(:group) => atom()
        }

  @doc "Templates offered by the module."
  @callback templates() :: [template()]

  @doc "Built-in templates followed by the configured ones."
  @spec all([module()] | nil) :: [template()]
  def all(modules \\ nil) do
    modules = modules || Application.get_env(:elementorex_cms, :templates, [])
    builtin() ++ Enum.flat_map(modules, & &1.templates())
  end

  @doc "The template with `key`, or `nil`."
  @spec get(String.t(), [module()] | nil) :: template() | nil
  def get(key, modules \\ nil), do: Enum.find(all(modules), &(&1.key == key))

  @doc """
  The templates for an editor: `all/1` without those of sources that are not
  available, plus `for_sources/2`.
  """
  @spec available([module()] | nil, Sources.t() | nil, String.t() | nil) :: [template()]
  def available(modules, sources, document_source \\ nil) do
    keys = sources |> Sources.list() |> MapSet.new(& &1.key)

    generated = for_sources(sources, document_source)
    {single, generated} = Enum.split_with(generated, &(&1[:single] == true))

    single ++
      Enum.filter(all(modules), &(&1[:source] == nil or MapSet.member?(keys, &1[:source]))) ++
      generated
  end

  @doc """
  The templates whose blocks are all in the registry: a registry with fewer
  blocks (`ElementorexCms.Registry.new(only: ...)`) doesn't offer templates
  that would insert blocks it can't render.
  """
  @spec usable([template()], ElementorexCms.Registry.t() | nil) :: [template()]
  def usable(templates, nil), do: templates

  def usable(templates, registry) do
    Enum.filter(templates, fn template ->
      template.nodes.() |> Enum.all?(&known_types?(&1, registry))
    end)
  end

  defp known_types?(%{"type" => type} = node, registry) do
    ElementorexCms.Registry.fetch(registry, type) != nil and
      Enum.all?(node["children"] || [], &known_types?(&1, registry))
  end

  defp known_types?(_node, _registry), do: false

  @doc """
  Templates made from the fields of each source (see `ElementorexCms.Source.role/2`):
  a grid of cards and a list of its items, linked to their page when the
  source has one. With `document_source` (the source of a template for single
  items) also the page of one item, with a list of related items.
  """
  @spec for_sources(Sources.t() | nil, String.t() | nil) :: [template()]
  def for_sources(sources, document_source \\ nil) do
    sources = Sources.list(sources)

    single =
      case Enum.find(sources, &(&1.key == document_source)) do
        nil -> []
        source -> [single_template(source)]
      end

    single ++
      Enum.flat_map(sources, &[grid_template(&1), filtered_template(&1), list_template(&1)])
  end

  defp grid_template(source) do
    %{
      key: "source:#{source.key}:grid",
      label: t("%{collection}: grid", collection: t(source.label)),
      description: "Cards with the fields of each item",
      icon: source.icon,
      source: source.key,
      group: :dynamic,
      nodes: fn ->
        [
          section([
            block("heading", %{text: t(source.label), level: "h2"}),
            loop(source.key, [card(source, "top")], %{limit: 6, columns: "3"})
          ])
        ]
      end
    }
  end

  # A grid with visitors' filters made from the fields of the source.
  defp filtered_template(source) do
    %{
      key: "source:#{source.key}:filtered",
      label: t("%{collection}: grid with filters", collection: t(source.label)),
      description: "Search, filters and order above a grid with pages",
      icon: "funnel",
      source: source.key,
      group: :dynamic,
      nodes: fn ->
        grid =
          loop(source.key, [card(source, "top")], %{
            limit: 9,
            columns: "3",
            pagination: "numbers_prev_next"
          })

        [
          section([
            block("heading", %{text: t(source.label), level: "h2"}),
            block("filters", %{target: grid["id"]}, children: filter_fields(source)),
            grid
          ])
        ]
      end
    }
  end

  @choice_names ~w(category categories type kind brand collection color size genre tag tags status)
  @toggle_names ~w(featured on_sale sale available new)

  defp filter_fields(source) do
    fields = Enum.filter(source.fields, & &1.filterable)
    title = Source.role(source, :title)
    price = Source.role(source, :price)

    choice =
      Enum.find(fields, &(&1.key in @choice_names and &1.type == :string and not &1.custom))

    toggle =
      Enum.find(fields, &(&1.custom and &1.type == :boolean)) ||
        Enum.find(fields, &(&1.key in @toggle_names and &1.type == :boolean))

    newest = Enum.find(source.fields, &(&1.key == "inserted_at" and &1.sortable))

    sort =
      [
        title && %{"label" => t("Name"), "field" => title.key, "direction" => "asc"},
        price &&
          %{"label" => t("Price: low to high"), "field" => price.key, "direction" => "asc"},
        price &&
          %{"label" => t("Price: high to low"), "field" => price.key, "direction" => "desc"},
        newest && %{"label" => t("Newest"), "field" => newest.key, "direction" => "desc"}
      ]
      |> Enum.filter(& &1)

    [
      Source.searchable(source) != [] && block("filter_search", %{}),
      choice && block("filter_choice", %{field: choice.key}),
      price &&
        block("filter_range", %{field: price.key, prefix: price.defaults["before"] || ""}),
      toggle && block("filter_toggle", %{field: toggle.key}),
      sort != [] && block("filter_sort", %{options: sort})
    ]
    |> Enum.filter(& &1)
  end

  defp list_template(source) do
    %{
      key: "source:#{source.key}:list",
      label: t("%{collection}: list", collection: t(source.label)),
      description: "One item per row, picture on the side",
      icon: "queue-list",
      source: source.key,
      group: :dynamic,
      nodes: fn ->
        [
          section([
            block("heading", %{text: t(source.label), level: "h2"}),
            loop(source.key, [card(source, "side")], %{
              limit: 6,
              columns: "1",
              columns_tablet: "1",
              gap: "4"
            })
          ])
        ]
      end
    }
  end

  defp single_template(source) do
    title = Source.role(source, :title)
    image = Source.role(source, :image)
    description = Source.role(source, :description)
    price = Source.role(source, :price)

    %{
      key: "source:#{source.key}:single",
      label: t("Page of one item of %{collection}", collection: t(source.label)),
      description: "Picture, title, price and description, and related items",
      icon: "document-text",
      source: source.key,
      group: :dynamic,
      single: true,
      nodes: fn ->
        details =
          [
            title &&
              block("heading", %{text: t("Item title"), level: "h1", size: "4xl"},
                dynamic: %{text: bind(title)}
              ),
            price &&
              block("heading", %{text: "0", level: "p", size: "2xl", weight: "semibold"},
                dynamic: %{text: bind(price, %{"format" => "number"})}
              ),
            description &&
              block("text", %{}, dynamic: %{text: bind(description)}),
            block("button", %{label: t("Buy now"), size: "lg", icon: "shopping-cart"})
          ]
          |> Enum.filter(& &1)

        [
          section([
            columns(
              [
                if(image,
                  do: [
                    block("image", %{width: "full", aspect: "square", rounded: "box"},
                      dynamic: %{src: bind(image)}
                    )
                  ],
                  else: []
                ),
                details
              ],
              %{columns: "2", columns_tablet: "2", gap: "8", align: "start"}
            )
          ]),
          section([
            block("heading", %{text: t("You may also like"), level: "h2", size: "2xl"}),
            loop(source.key, [card(source, "top")], %{
              limit: 3,
              columns: "3",
              exclude_current: true
            })
          ])
        ]
      end
    }
  end

  # A card bound to the fields with a role, linked to the page of the item.
  defp card(source, position) do
    title = Source.role(source, :title)
    image = Source.role(source, :image)
    description = Source.role(source, :description)
    price = Source.role(source, :price)
    link? = Source.url?(source)

    dynamic =
      [
        title: title && bind(title),
        image: image && bind(image),
        text: description && bind(description, %{"format" => "excerpt", "length" => 120}),
        badge: price && bind(price, %{"format" => "number"}),
        button_url: link? && "@url"
      ]
      |> Enum.filter(fn {_prop, binding} -> binding end)
      |> Map.new()

    block(
      "card",
      %{
        title: t("Item title"),
        text: if(description, do: t("<p>A short description of the item.</p>"), else: ""),
        badge: if(price, do: "0", else: ""),
        button_label: if(link?, do: t("View"), else: ""),
        image_position: position
      },
      dynamic: dynamic
    )
  end

  # A binding to `field` with the field's own defaults (a price's "$"…).
  defp bind(field, settings \\ %{}) do
    settings
    |> Map.merge(field.defaults)
    |> Map.put("field", field.key)
  end

  @doc "The built-in templates."
  @spec builtin() :: [template()]
  def builtin do
    [
      %{
        key: "announcement",
        label: t("Announcement"),
        description: "Badge, headline, text and two buttons",
        icon: "megaphone",
        nodes: fn ->
          [
            section([
              block("badge", %{text: t("New"), color: "primary"}),
              block("heading", %{text: t("Something new is here"), level: "h2", size: "4xl"}),
              block("text", %{
                text: t("<p>Tell your visitors what changed and why it matters to them.</p>")
              }),
              block("button_group", %{})
            ])
          ]
        end
      },
      %{
        key: "countdown",
        label: t("Promotion with countdown"),
        description: "Headline, countdown to a date and a button",
        icon: "clock",
        nodes: fn ->
          [
            section([
              block("heading", %{
                text: t("The offer ends soon"),
                level: "h2",
                size: "4xl",
                align: "center"
              }),
              block("text", %{
                text: t("<p>Sign up before the countdown reaches zero.</p>"),
                align: "center"
              }),
              block("countdown", %{}),
              block("button", %{
                label: t("I want it"),
                align: "center",
                size: "lg",
                icon: "arrow-right"
              })
            ])
          ]
        end
      },
      %{
        key: "benefits",
        label: t("Benefits"),
        description: "Headline and three icon boxes",
        icon: "squares-2x2",
        nodes: fn ->
          [
            section([
              block("heading", %{text: t("Why choose us"), level: "h2", align: "center"}),
              columns(
                [
                  [
                    block("feature", %{
                      icon: "bolt",
                      title: t("Fast"),
                      text: t("<p>Ready in minutes.</p>")
                    })
                  ],
                  [
                    block("feature", %{
                      icon: "shield-check",
                      title: t("Safe"),
                      text: t("<p>Backed by the best.</p>")
                    })
                  ],
                  [
                    block("feature", %{
                      icon: "heart",
                      title: t("Human"),
                      text: t("<p>Real people to help you.</p>")
                    })
                  ]
                ],
                %{columns: "3", columns_tablet: "3", columns_mobile: "1"}
              )
            ])
          ]
        end
      },
      %{
        key: "notice",
        label: t("Important notice"),
        description: "Alert, explanation and a button",
        icon: "exclamation-triangle",
        nodes: fn ->
          [
            section([
              block("alert", %{
                kind: "warning",
                title: t("Important"),
                text: t("<p>Read this before you continue.</p>")
              }),
              block("text", %{text: t("<p>Add the details here.</p>")}),
              block("button", %{label: t("More information"), variant: "outline"})
            ])
          ]
        end
      },
      %{
        key: "faq",
        label: t("Frequently asked questions"),
        description: "Headline and an accordion",
        icon: "question-mark-circle",
        nodes: fn ->
          [
            section([
              block("heading", %{text: t("Frequently asked questions"), level: "h2"}),
              block("accordion", %{})
            ])
          ]
        end
      },
      %{
        key: "image_text",
        label: t("Image and text"),
        description: "Two columns: picture on one side, text on the other",
        icon: "photo",
        nodes: fn ->
          [
            section([
              columns(
                [
                  [block("image", %{width: "full"})],
                  [
                    block("heading", %{text: t("Tell a story"), level: "h2"}),
                    block("text", %{}),
                    block("list", %{}),
                    block("button", %{})
                  ]
                ],
                %{align: "center"}
              )
            ])
          ]
        end
      },
      %{
        key: "testimonials",
        label: t("Testimonials"),
        description: "Two quotes side by side",
        icon: "chat-bubble-left-right",
        nodes: fn ->
          [
            section([
              block("heading", %{text: t("What our customers say"), level: "h2", align: "center"}),
              columns([
                [block("quote", %{})],
                [block("quote", %{author: t("Juan Soto"), role: t("Customer since 2025")})]
              ])
            ])
          ]
        end
      },
      %{
        key: "stats",
        label: t("Figures"),
        description: "Key figures in a row",
        icon: "chart-bar",
        nodes: fn -> [section([block("stats", %{})])] end
      }
    ]
  end
end
