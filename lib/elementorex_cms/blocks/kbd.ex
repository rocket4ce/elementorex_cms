defmodule ElementorexCms.Blocks.Kbd do
  @moduledoc "daisyUI kbd: keyboard keys, e.g. `⌘ + K`."

  use ElementorexCms.Block,
    type: "kbd",
    label: "Keyboard keys",
    icon: "command-line",
    category: :components,
    description: "Shortcut keys",
    keywords: ~w(kbd shortcut key atajo tecla)

  alias ElementorexCms.Blocks.Options

  prop(:keys, :string, label: "Keys", default: "⌘ + K", help: "Separate keys with +")

  prop(:size, :select,
    label: "Size",
    options: Options.sizes(),
    default: "md",
    control: :segmented
  )

  @sizes %{
    "xs" => "kbd-xs",
    "sm" => "kbd-sm",
    "md" => "kbd-md",
    "lg" => "kbd-lg",
    "xl" => "kbd-xl"
  }

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :key_list,
        assigns.keys |> String.split("+") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
      )

    ~H"""
    <span {root(assigns, class: "inline-flex items-center gap-1")}>
      <%= for {key, index} <- Enum.with_index(@key_list) do %>
        <span :if={index > 0} class="opacity-60">+</span>
        <kbd class={["kbd", Map.get(sizes(), @size)]}>{key}</kbd>
      <% end %>
    </span>
    """
  end

  defp sizes, do: @sizes
end
