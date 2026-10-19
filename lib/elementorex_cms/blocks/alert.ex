defmodule ElementorexCms.Blocks.Alert do
  @moduledoc "daisyUI alert: an important message with icon, title, text and an optional button."

  use ElementorexCms.Block,
    type: "alert",
    label: "Alert",
    icon: "exclamation-triangle",
    category: :components,
    description: "Highlighted message",
    keywords: ~w(notice warning info callout aviso alerta)

  alias ElementorexCms.Blocks.Options

  prop(:kind, :select,
    label: "Kind",
    options: [
      {"Info", "info"},
      {"Success", "success"},
      {"Warning", "warning"},
      {"Error", "error"},
      {"Neutral", "neutral"}
    ],
    default: "info",
    control: :segmented
  )

  prop(:variant, :select,
    label: "Style",
    options: Options.variants(),
    default: "soft",
    control: :segmented
  )

  prop(:title, :string, label: "Title", default: "Heads up", inline: true)

  prop(:text, :richtext,
    label: "Text",
    default: "<p>Something important your visitors should know.</p>",
    inline: true
  )

  prop(:icon, :icon, label: "Icon", help: "Leave empty to use the icon of the kind")
  prop(:button_label, :string, label: "Button text", group: "Button")

  prop(:button_url, :url,
    label: "Button link",
    group: "Button",
    show_if: {:button_label, :present}
  )

  @kinds %{
    "info" => "alert-info",
    "success" => "alert-success",
    "warning" => "alert-warning",
    "error" => "alert-error",
    "neutral" => nil
  }
  @variants %{
    "solid" => nil,
    "soft" => "alert-soft",
    "outline" => "alert-outline",
    "dash" => "alert-dash"
  }
  @icons %{
    "info" => "information-circle",
    "success" => "check-circle",
    "warning" => "exclamation-triangle",
    "error" => "x-circle",
    "neutral" => "bell"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns,
      class: ["alert items-start max-sm:alert-vertical max-sm:items-start max-sm:text-left", Map.get(kinds(), @kind), Map.get(variants(), @variant)],
      attrs: [{"role", "alert"}]
    )}>
      <.heroicon
        name={if(@icon != "", do: @icon, else: Map.get(icons(), @kind))}
        class="size-6 shrink-0"
      />
      <div class="flex min-w-0 flex-col gap-1">
        <h3 :if={@title != ""} class="font-bold" {inline(assigns, :title)}>{@title}</h3>
        <div class="exr-rich text-sm" {inline(assigns, :text)}>{rich(@text)}</div>
      </div>
      <a :if={@button_label != ""} class="btn btn-sm" {link_attrs(@button_url)}>{@button_label}</a>
    </div>
    """
  end

  defp kinds, do: @kinds
  defp variants, do: @variants
  defp icons, do: @icons
end
