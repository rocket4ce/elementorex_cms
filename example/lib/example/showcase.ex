defmodule Example.Showcase do
  @moduledoc """
  Documents built in code with `ElementorexCms.Builder` that use every feature
  of the library, so the editor and the renderer can be checked at a glance:

    * `all_blocks/0` - every built-in block plus the app's own ones, with
      responsive and `:hover` styles and the *Advanced* settings (CSS id,
      classes, hide per device, entrance animations, scoped custom CSS, names)
    * `templates/0` - every template of the *Templates* panel, one after the
      other (built-in and `ExampleWeb.EditorTemplates.Marketing`)
    * `modal/0` - a short document for the modal playground

  Used by `priv/repo/seeds.exs` and by the *Reset* actions of the playground.
  """

  import ElementorexCms.Builder

  @doc "A page with every block."
  def all_blocks do
    doc(
      [
        hero(),
        layout(),
        basic(),
        components(),
        media(),
        advanced(),
        custom()
      ],
      attrs: %{"css" => "selector { scroll-behavior: smooth }"}
    )
  end

  @doc "A page made of every template, in order."
  def templates do
    ElementorexCms.Templates.all()
    |> Enum.flat_map(fn template ->
      [block("divider", %{text: template.label}) | template.nodes.()]
    end)
    |> doc()
  end

  @doc "A short document for the modal playground."
  def modal do
    doc([
      block("badge", %{text: "Today only", color: "accent", align: "center"}),
      block("heading", %{
        text: "Black Friday: 40% off",
        level: "h2",
        size: "3xl",
        align: "center"
      }),
      block("countdown", %{target: target(3), size: "4xl", align: "center"}),
      block("text", %{
        text: "<p>Get the discount on every yearly plan.</p>",
        align: "center",
        muted: true
      }),
      block("button", %{label: "Get the discount", wide: true, icon: "arrow-right"}),
      block("whatsapp", %{label: "Questions? Write to us", size: "sm"},
        style: %{"desktop" => %{"margin-left" => "auto", "margin-right" => "auto"}}
      )
    ])
  end

  # Sections ------------------------------------------------------------------

  defp hero do
    block(
      "hero",
      %{
        image: image("hero", 1600, 900),
        overlay: true,
        min_height: "md",
        content_width: "3xl"
      },
      attrs: %{"id" => "top", "label" => "Hero"},
      children: [
        block("badge", %{text: "ElementorexCms", color: "primary", icon: "sparkles"},
          attrs: %{"animation" => "fade-down"}
        ),
        block("heading", %{text: "Every block on one page", level: "h1", size: "5xl"},
          style: %{"mobile" => %{"font-size" => "36px"}},
          attrs: %{"animation" => "fade-up", "animation_delay" => 150}
        ),
        block(
          "text",
          %{
            text:
              "<p>This page was built in code with <code>ElementorexCms.Builder</code>. " <>
                "Open it in the editor to try every block.</p>",
            size: "lg"
          },
          attrs: %{"animation" => "fade-up", "animation_delay" => 300}
        ),
        block(
          "button_group",
          %{
            items: [
              %{"label" => "See the blocks", "url" => "#layout", "color" => "primary"},
              %{"label" => "Go to the admin", "url" => "/admin/pages", "variant" => "outline"}
            ]
          },
          attrs: %{"animation" => "zoom-in", "animation_delay" => 450}
        )
      ]
    )
  end

  defp layout do
    section(
      [
        title("Layout", "section · container · grid · spacer · divider"),
        container(
          [
            box("Row 1", "primary"),
            box("Row 2", "secondary"),
            box("Row 3", "accent")
          ],
          %{direction: "row", justify: "between", gap: "4", stack_on_mobile: true, wrap: true}
        ),
        block("spacer", %{height: 24}),
        block("divider", %{text: "grid of 4 / 2 / 1 columns", color: "primary"}),
        columns(
          for(n <- 1..4, do: [box("Column #{n}", "neutral")]),
          %{columns: "4", columns_tablet: "2", columns_mobile: "1", gap: "4"}
        ),
        block("divider", %{text: "Visible on desktop only"},
          attrs: %{"hide_on" => ["tablet", "mobile"]}
        ),
        block("divider", %{text: "Visible on tablet and mobile only"},
          attrs: %{"hide_on" => ["desktop"]}
        )
      ],
      %{gap: "6"},
      attrs: %{"id" => "layout", "label" => "Layout"}
    )
  end

  defp basic do
    section(
      [
        title("Basic", "heading · text · button · link · icon · feature · list · badge · kbd"),
        columns([
          [
            block(
              "heading",
              %{text: "Heading with <em>emphasis</em>", level: "h2", weight: "black"},
              style: %{
                "desktop" => %{"color" => "var(--color-primary)"},
                "hover" => %{"color" => "var(--color-secondary)"}
              }
            ),
            block("text", %{
              text:
                "<p>Rich text with <strong>bold</strong>, <em>italics</em>, " <>
                  "<a href=\"https://hexdocs.pm\">links</a> and lists:</p>" <>
                  "<ul><li>One</li><li>Two</li></ul>"
            }),
            container(
              [
                block("button", %{label: "Primary", icon: "bolt", icon_position: "start"}),
                block("button", %{label: "Outline", color: "secondary", variant: "outline"}),
                block("button", %{label: "Pill", color: "accent", shape: "pill", size: "sm"}),
                block("button", %{label: "Dash", color: "neutral", variant: "dash"},
                  style: %{"hover" => %{"opacity" => "0.7"}}
                )
              ],
              %{direction: "row", gap: "2", wrap: true}
            ),
            block("link", %{label: "A link with an icon", url: "#", icon: "arrow-up-right"}),
            container(
              [
                block("badge", %{text: "Primary", color: "primary"}),
                block("badge", %{text: "Soft", color: "success", variant: "soft"}),
                block("badge", %{text: "Outline", color: "error", variant: "outline"}),
                block("kbd", %{keys: "⌘ + S"})
              ],
              %{direction: "row", gap: "2", wrap: true, align: "center"}
            )
          ],
          [
            container(
              [
                block("icon", %{
                  name: "rocket-launch",
                  size: "xl",
                  color: "primary",
                  background: "soft"
                }),
                block("icon", %{name: "heart", style: "solid", size: "xl", color: "error"}),
                block("icon", %{name: "star", size: "xl", color: "warning", background: "solid"})
              ],
              %{direction: "row", gap: "4"}
            ),
            block("feature", %{
              icon: "bolt",
              title: "Icon box",
              text: "<p>An icon, a title and a text.</p>",
              layout: "left"
            }),
            block("list", %{
              icon: "check-circle",
              color: "success",
              divider: true,
              items: [
                %{"text" => "Lists with icons"},
                %{"text" => "<strong>Rich text</strong> in every item"},
                %{"text" => "Its own icon per item", "icon" => "star"}
              ]
            })
          ]
        ])
      ],
      %{gap: "6"},
      attrs: %{"id" => "basic", "label" => "Basic"}
    )
  end

  defp components do
    section(
      [
        title(
          "Components",
          "alert · card · stats · steps · countdown · accordion · tabs · timeline · rating · progress · avatar · chat · quote"
        ),
        columns([
          [block("alert", %{kind: "info", title: "Info", text: "<p>An informative notice.</p>"})],
          [
            block("alert", %{
              kind: "warning",
              variant: "soft",
              title: "Heads up",
              text: "<p>With a button.</p>",
              button_label: "View",
              button_url: "#"
            })
          ]
        ]),
        columns(
          [
            [
              block("card", %{
                image: image("card1", 600, 400),
                title: "Image on top",
                badge: "New",
                text: "<p>The image above the content.</p>",
                button_label: "Buy",
                shadow: "md"
              })
            ],
            [
              block("card", %{
                image: image("card2", 600, 400),
                image_position: "overlay",
                title: "Overlay card",
                text: "<p>Text over the image.</p>"
              })
            ],
            [
              block("card", %{
                title: "Card without image",
                text: "<p>Dashed border, centered.</p>",
                border: "dash",
                centered: true,
                background: "base-200"
              })
            ]
          ],
          %{columns: "3", columns_tablet: "2", columns_mobile: "1"}
        ),
        block("stats", %{}),
        block("steps", %{
          items: [
            %{"label" => "Create", "done" => true},
            %{"label" => "Edit", "done" => true},
            %{"label" => "Publish", "done" => false}
          ],
          vertical_on_mobile: true
        }),
        block("countdown", %{target: target(10), align: "center", size: "5xl"}),
        columns([
          [block("accordion", %{exclusive: true})],
          [block("tabs", %{style: "lift"})]
        ]),
        block("timeline", %{direction: "horizontal"}),
        columns(
          [
            [
              block("rating", %{value: 4.5, label: "4.5 out of 5"}),
              block("rating", %{value: 3, shape: "heart", color: "error", max: "5"})
            ],
            [
              block("progress", %{value: 70, label: "Bar", show_value: true}),
              block("progress", %{kind: "radial", value: 45, color: "secondary"})
            ],
            [
              block("avatar", %{
                image: image("avatar", 200, 200),
                name: "Ana Pérez",
                subtitle: "Editor",
                status: "online",
                ring: true
              }),
              block("avatar", %{initials: "JS", name: "Juan Soto", shape: "squircle"})
            ]
          ],
          %{columns: "3", columns_mobile: "1"}
        ),
        columns([[block("chat", %{})], [block("quote", %{style: "card"})]])
      ],
      %{gap: "8"},
      attrs: %{"id" => "components", "label" => "Components"}
    )
  end

  defp media do
    section(
      [
        title("Media", "image · carousel · video · mockup"),
        columns([
          [
            block("image", %{
              src: image("image", 800, 600),
              alt: "An example image",
              caption: "Image with a squircle mask",
              mask: "squircle",
              width: "full",
              aspect: "square"
            })
          ],
          [
            block("video", %{
              url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
              title: "Embedded video",
              rounded: true
            })
          ]
        ]),
        block("carousel", %{
          per_view: "3",
          height: "64",
          items:
            for n <- 1..6 do
              %{"image" => image("carousel#{n}", 600, 400), "caption" => "Photo #{n}"}
            end
        }),
        columns(
          [
            [
              block("mockup", %{
                kind: "browser",
                image: image("browser", 900, 560),
                address: "https://example.com"
              })
            ],
            [block("mockup", %{kind: "phone", image: image("phone", 390, 780)})],
            [
              block("mockup", %{
                kind: "code",
                code: "mix elementorex.gen.cms Pages Page pages",
                prefix: "$"
              })
            ]
          ],
          %{columns: "3", columns_mobile: "1", align: "center"}
        )
      ],
      %{gap: "6"},
      attrs: %{"id" => "media", "label" => "Media"}
    )
  end

  defp advanced do
    section(
      [
        title("Advanced", "html · custom CSS · classes · animations"),
        block("html", %{
          html:
            ~s|<div class="rounded-box border border-base-300 p-4"><p><strong>HTML</strong> sanitized: | <>
              ~s|the script below never reaches the page.</p><script>alert("xss")</script></div>|
        }),
        block("heading", %{text: "Custom CSS with nesting", level: "h3", align: "center"},
          attrs: %{
            "class" => "tracking-tight",
            "css" =>
              "selector { text-decoration: underline wavy var(--color-accent); } " <>
                "selector:hover { letter-spacing: 0.05em }",
            "animation" => "fade-left"
          }
        )
      ],
      %{gap: "6"},
      attrs: %{"id" => "advanced", "label" => "Advanced"}
    )
  end

  defp custom do
    section(
      [
        title("App blocks", "pricing · whatsapp · callout (ExampleWeb.Blocks)"),
        columns(
          [
            [
              block("pricing", %{
                plan: "Starter",
                price: "$0",
                cta: "Get started",
                tone: "neutral"
              })
            ],
            [block("pricing", %{plan: "Pro", price: "$9.990", featured: true, badge: "Popular"})],
            [block("pricing", %{plan: "Business", price: "$29.990", tone: "secondary"})]
          ],
          %{columns: "3", columns_tablet: "3", columns_mobile: "1"}
        ),
        block("callout", %{title: "A container of this app", image: image("callout", 1200, 500)},
          children: [
            block("text", %{text: "<p>The callout only accepts some blocks inside.</p>"}),
            block("whatsapp", %{label: "Uses the number of the site"})
          ]
        ),
        block("whatsapp", %{label: "Its own number", phone: "+56 9 1234 5678", size: "lg"})
      ],
      %{gap: "6"},
      attrs: %{"id" => "app-blocks", "label" => "App blocks"}
    )
  end

  # Helpers -------------------------------------------------------------------

  defp title(text, subtitle) do
    container(
      [
        block("heading", %{text: text, level: "h2", size: "3xl"}),
        block("text", %{text: "<p><code>#{subtitle}</code></p>", muted: true, size: "sm"})
      ],
      %{gap: "1"}
    )
  end

  defp box(text, color) do
    block("card", %{title: text, background: "base-200", size: "sm", centered: true},
      style: %{
        "desktop" =>
          Map.merge(
            %{"border-style" => "solid", "border-color" => "var(--color-#{color})"},
            Map.new(~w(top right bottom left), &{"border-#{&1}-width", "2px"})
          ),
        "hover" => %{"box-shadow" => "lg", "background-color" => "var(--color-base-100)"}
      },
      attrs: %{
        "css" =>
          "selector { transition: transform .2s } selector:hover { transform: translateY(-4px) }"
      }
    )
  end

  defp image(seed, w, h), do: "https://picsum.photos/seed/exr-#{seed}/#{w}/#{h}"

  defp target(days) do
    DateTime.utc_now()
    |> DateTime.add(days, :day)
    |> Calendar.strftime("%Y-%m-%dT%H:%M")
  end
end
