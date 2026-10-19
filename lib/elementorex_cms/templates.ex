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
  """

  import ElementorexCms.Builder
  import ElementorexCms.I18n, only: [t: 1]

  @type template :: %{
          required(:key) => String.t(),
          required(:label) => String.t(),
          required(:nodes) => (-> [map()]),
          optional(:description) => String.t(),
          optional(:icon) => String.t()
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
