defmodule ElementorexCms.Blocks.Avatar do
  @moduledoc "daisyUI avatar: photo or initials, with status and an optional name beside it."

  use ElementorexCms.Block,
    type: "avatar",
    label: "Avatar",
    icon: "user-circle",
    category: :components,
    description: "Person with photo and name",
    keywords: ~w(person profile user persona perfil foto)

  prop(:image, :image, label: "Photo")
  prop(:initials, :string, label: "Initials", default: "AB", max_length: 3)
  prop(:name, :string, label: "Name", inline: true)
  prop(:subtitle, :string, label: "Subtitle", inline: true)

  prop(:size, :select,
    label: "Size",
    options: [{"S", "10"}, {"M", "14"}, {"L", "20"}, {"XL", "28"}],
    default: "14",
    control: :segmented
  )

  prop(:shape, :select,
    label: "Shape",
    options: [
      {"Circle", "circle"},
      {"Rounded", "rounded"},
      {"Squircle", "squircle"},
      {"Hexagon", "hexagon"}
    ],
    default: "circle",
    control: :segmented
  )

  prop(:status, :select,
    label: "Status",
    options: [{"None", "none"}, {"Online", "online"}, {"Offline", "offline"}],
    default: "none",
    control: :segmented
  )

  prop(:ring, :boolean, label: "Ring", default: false)

  @sizes %{"10" => "w-10", "14" => "w-14", "20" => "w-20", "28" => "w-28"}
  @text %{"10" => "text-sm", "14" => "text-lg", "20" => "text-2xl", "28" => "text-4xl"}
  @shapes %{
    "circle" => "rounded-full",
    "rounded" => "rounded-box",
    "squircle" => "mask mask-squircle",
    "hexagon" => "mask mask-hexagon"
  }
  @status %{"none" => nil, "online" => "avatar-online", "offline" => "avatar-offline"}

  def render(assigns) do
    ~H"""
    <div {root(assigns, class: "flex items-center gap-3")}>
      <div class={["avatar", @image == "" && "avatar-placeholder", Map.get(statuses(), @status)]}>
        <div class={[
          Map.get(sizes(), @size),
          Map.get(shapes(), @shape),
          @ring && "ring-primary ring-offset-base-100 ring-2 ring-offset-2",
          @image == "" && "bg-neutral text-neutral-content"
        ]}>
          <img :if={@image != ""} src={@image} alt={@name} loading="lazy" />
          <span :if={@image == ""} class={Map.get(texts(), @size)}>{@initials}</span>
        </div>
      </div>
      <div :if={@name != "" or @subtitle != ""} class="flex min-w-0 flex-col">
        <span :if={@name != ""} class="font-semibold" {inline(assigns, :name)}>{@name}</span>
        <span :if={@subtitle != ""} class="text-sm opacity-70" {inline(assigns, :subtitle)}>{@subtitle}</span>
      </div>
    </div>
    """
  end

  defp sizes, do: @sizes
  defp texts, do: @text
  defp shapes, do: @shapes
  defp statuses, do: @status
end
