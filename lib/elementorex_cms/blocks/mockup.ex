defmodule ElementorexCms.Blocks.Mockup do
  @moduledoc "daisyUI mockups: browser, phone or window frames around an image, or a code block."

  use ElementorexCms.Block,
    type: "mockup",
    label: "Mockup",
    icon: "device-phone-mobile",
    category: :media,
    description: "Browser, phone, window or code frame",
    keywords: ~w(browser phone device code terminal navegador telefono)

  prop(:kind, :select,
    label: "Kind",
    options: [{"Browser", "browser"}, {"Phone", "phone"}, {"Window", "window"}, {"Code", "code"}],
    default: "browser",
    control: :segmented
  )

  prop(:image, :image, label: "Screenshot", show_if: {:kind, ["browser", "phone", "window"]})

  prop(:address, :string,
    label: "Address",
    default: "https://example.com",
    show_if: {:kind, "browser"}
  )

  prop(:code, :text,
    label: "Code",
    default: "npm i daisyui\ninstalling...\nDone!",
    show_if: {:kind, "code"}
  )

  prop(:prefix, :string,
    label: "Line prefix",
    default: "$",
    max_length: 3,
    show_if: {:kind, "code"}
  )

  def render(assigns) do
    ~H"""
    <%= case @kind do %>
      <% "browser" -> %>
        <div {root(assigns, class: "mockup-browser w-full border border-base-300 bg-base-200")}>
          <div class="mockup-browser-toolbar">
            <div class="input">{@address}</div>
          </div>
          <.screen image={@image} class="border-t border-base-300" />
        </div>
      <% "phone" -> %>
        <div {root(assigns, class: "mockup-phone mx-auto border-primary")}>
          <div class="mockup-phone-camera"></div>
          <div class="mockup-phone-display"><.screen image={@image} class="h-full" /></div>
        </div>
      <% "window" -> %>
        <div {root(assigns, class: "mockup-window w-full border border-base-300 bg-base-200")}>
          <.screen image={@image} class="border-t border-base-300" />
        </div>
      <% _code -> %>
        <div {root(assigns, class: "mockup-code w-full")}>
          <pre :for={line <- String.split(@code, "\n")} data-prefix={@prefix}><code>{line}</code></pre>
        </div>
    <% end %>
    """
  end

  attr :image, :string, required: true
  attr :class, :any, default: nil

  defp screen(assigns) do
    ~H"""
    <img
      :if={@image != ""}
      src={@image}
      alt=""
      class={["block w-full object-cover object-top", @class]}
      loading="lazy"
    />
    <div
      :if={@image == ""}
      class={["grid min-h-48 place-items-center bg-base-100 text-base-content/40", @class]}
    >
      <.heroicon name="photo" class="size-10" />
    </div>
    """
  end
end
