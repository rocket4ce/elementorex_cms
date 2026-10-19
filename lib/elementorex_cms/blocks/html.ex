defmodule ElementorexCms.Blocks.Html do
  @moduledoc """
  Hand-written HTML, sanitized with the `:html` policy of
  `ElementorexCms.HTML.Sanitizer` (no scripts, iframes, forms or event
  handlers). Tailwind and daisyUI classes work if your CSS build includes them.
  """

  use ElementorexCms.Block,
    type: "html",
    label: "HTML",
    icon: "code-bracket",
    category: :advanced,
    description: "Your own HTML (sanitized)",
    keywords: ~w(code custom embed codigo personalizado)

  prop(:html, :html,
    label: "HTML",
    default: ~s(<div class="p-4 rounded-box bg-base-200">Custom HTML</div>)
  )

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: "w-full")}>
      {Phoenix.HTML.raw(ElementorexCms.HTML.Sanitizer.sanitize(@html, :html))}
      <div :if={@html == "" and editor?(assigns)} class="exr-image-placeholder">
        <.heroicon name="code-bracket" class="size-8" />
        <span>{t("Write your HTML in the panel")}</span>
      </div>
    </div>
    """
  end
end
