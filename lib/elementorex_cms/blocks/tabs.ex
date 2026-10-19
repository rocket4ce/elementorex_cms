defmodule ElementorexCms.Blocks.Tabs do
  @moduledoc "daisyUI tabs with content, switched with radio inputs (no JavaScript)."

  use ElementorexCms.Block,
    type: "tabs",
    label: "Tabs",
    icon: "folder",
    category: :components,
    description: "Content in tabs",
    keywords: ~w(tab panes pestañas)

  alias ElementorexCms.Blocks.Options

  prop(:items, :list,
    label: "Tabs",
    item_label: :label,
    max_items: 10,
    default: [
      %{"label" => "First", "content" => "<p>Content of the first tab.</p>"},
      %{"label" => "Second", "content" => "<p>Content of the second tab.</p>"},
      %{"label" => "Third", "content" => "<p>Content of the third tab.</p>"}
    ],
    fields: [
      {:label, :string, label: "Title", default: "Tab"},
      {:content, :richtext, label: "Content", default: "<p>Content</p>", control: :textarea}
    ]
  )

  prop(:style, :select,
    label: "Style",
    options: [{"Lift", "lift"}, {"Box", "box"}, {"Border", "border"}],
    default: "lift",
    control: :segmented
  )

  prop(:size, :select,
    label: "Size",
    options: Options.sizes(),
    default: "md",
    control: :segmented
  )

  @styles %{"lift" => "tabs-lift", "box" => "tabs-box", "border" => "tabs-border"}
  @sizes %{
    "xs" => "tabs-xs",
    "sm" => "tabs-sm",
    "md" => "tabs-md",
    "lg" => "tabs-lg",
    "xl" => "tabs-xl"
  }

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: ["tabs w-full", Map.get(styles(), @style), Map.get(sizes(), @size)], attrs: [{"role", "tablist"}])}>
      <%= for {item, index} <- Enum.with_index(@items) do %>
        <input
          type="radio"
          name={"ex-tabs-#{@node["id"]}"}
          class="tab"
          aria-label={item["label"]}
          checked={index == 0}
        />
        <div class="tab-content exr-rich border-base-300 bg-base-100 p-6">
          {rich(item["content"])}
        </div>
      <% end %>
    </div>
    """
  end

  defp styles, do: @styles
  defp sizes, do: @sizes
end
