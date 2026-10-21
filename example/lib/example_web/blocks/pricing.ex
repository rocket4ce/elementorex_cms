defmodule ExampleWeb.Blocks.Pricing do
  @moduledoc """
  Pricing plan card for the visual editor (ElementorexCms).

  Exercises `:list` props, booleans with `show_if`, `:url`, `group:` and the
  `:swatches` / `:segmented` controls.
  """

  use ElementorexCms.Block,
    type: "pricing",
    label: "Pricing",
    icon: "currency-dollar",
    category: :components,
    description: "A plan with price, features and a button",
    keywords: ~w(plan price precio plan suscripcion)

  alias ElementorexCms.Blocks.Options

  prop :plan, :string, label: "Plan", default: "Pro", inline: true
  prop :price, :string, label: "Price", default: "$9.990", inline: true
  prop :period, :string, label: "Period", default: "/month"
  prop :text, :richtext, label: "Description", default: "<p>Everything you need to grow.</p>"

  prop :features, :list,
    label: "Features",
    item_label: :text,
    max_items: 10,
    default: [
      %{"text" => "Unlimited pages", "included" => true},
      %{"text" => "Visual editor", "included" => true},
      %{"text" => "Priority support", "included" => false}
    ],
    fields: [
      {:text, :string, label: "Feature", default: "Feature"},
      {:included, :boolean, label: "Included", default: true}
    ]

  prop :cta, :string, label: "Button", default: "Choose plan", group: "Button"
  prop :url, :url, label: "Link", default: "#", group: "Button"

  prop :featured, :boolean, label: "Featured", default: false, group: "Look"

  prop :badge, :string,
    label: "Badge",
    default: "Most popular",
    group: "Look",
    show_if: {:featured, true}

  prop :tone, :select,
    label: "Color",
    options: Options.colors(),
    default: "primary",
    control: :swatches,
    group: "Look"

  # Class names must be written in full so Tailwind finds them.
  @borders %{
    "primary" => "border-primary",
    "secondary" => "border-secondary",
    "accent" => "border-accent",
    "neutral" => "border-neutral",
    "info" => "border-info",
    "success" => "border-success",
    "warning" => "border-warning",
    "error" => "border-error"
  }
  @texts %{
    "primary" => "text-primary",
    "secondary" => "text-secondary",
    "accent" => "text-accent",
    "neutral" => "text-neutral",
    "info" => "text-info",
    "success" => "text-success",
    "warning" => "text-warning",
    "error" => "text-error"
  }
  @buttons %{
    "primary" => "btn-primary",
    "secondary" => "btn-secondary",
    "accent" => "btn-accent",
    "neutral" => "btn-neutral",
    "info" => "btn-info",
    "success" => "btn-success",
    "warning" => "btn-warning",
    "error" => "btn-error"
  }
  @badges %{
    "primary" => "badge-primary",
    "secondary" => "badge-secondary",
    "accent" => "badge-accent",
    "neutral" => "badge-neutral",
    "info" => "badge-info",
    "success" => "badge-success",
    "warning" => "badge-warning",
    "error" => "badge-error"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns,
      class: [
        "card relative bg-base-100 shadow-sm",
        if(@featured, do: ["border-2", Map.get(borders(), @tone)], else: "border border-base-300")
      ]
    )}>
      <span
        :if={@featured and @badge != ""}
        class={["badge absolute -top-3 left-1/2 -translate-x-1/2", Map.get(badges(), @tone)]}
      >
        {@badge}
      </span>
      <div class="card-body gap-4">
        <h3 class="text-lg font-semibold" {inline(assigns, :plan)}>{@plan}</h3>
        <p class="flex items-baseline gap-1">
          <span class={["text-4xl font-black", Map.get(texts(), @tone)]} {inline(assigns, :price)}>
            {@price}
          </span>
          <span :if={@period != ""} class="text-sm opacity-60">{@period}</span>
        </p>
        <div class="exr-rich opacity-80">{rich(@text)}</div>
        <ul class="flex flex-col gap-2 text-sm">
          <li
            :for={feature <- @features}
            class={["flex items-center gap-2", !feature["included"] && "opacity-50 line-through"]}
          >
            <.heroicon
              name={if(feature["included"], do: "check-circle", else: "x-circle")}
              style="mini"
              class={["size-5 shrink-0", feature["included"] && Map.get(texts(), @tone)]}
            />
            {feature["text"]}
          </li>
        </ul>
        <a
          :if={@cta != ""}
          class={["btn mt-2", Map.get(buttons(), @tone), !@featured && "btn-outline"]}
          {link_attrs(@url)}
        >
          {@cta}
        </a>
      </div>
    </div>
    """
  end

  defp borders, do: @borders
  defp texts, do: @texts
  defp buttons, do: @buttons
  defp badges, do: @badges
end
