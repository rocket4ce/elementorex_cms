defmodule ElementorexCms.Blocks.Video do
  @moduledoc """
  A YouTube or Vimeo video (embedded with its canonical player URL) or a video
  file (`.mp4`, `.webm`).

  Embeds need the host's Content-Security-Policy to allow the players in
  `frame-src` (`https://www.youtube-nocookie.com https://player.vimeo.com`). On
  the editor canvas the player is replaced by a preview, so the editor works
  under a strict policy.
  """

  use ElementorexCms.Block,
    type: "video",
    label: "Video",
    icon: "play-circle",
    category: :media,
    description: "YouTube, Vimeo or a video file",
    keywords: ~w(youtube vimeo mp4 film video)

  alias ElementorexCms.URL

  prop(:url, :url, label: "Video URL", placeholder: "https://www.youtube.com/watch?v=…")
  prop(:title, :string, label: "Title", default: "Video")
  prop(:poster, :image, label: "Cover image", help: "Only for video files")

  prop(:aspect, :select,
    label: "Aspect ratio",
    options: [{"16:9", "video"}, {"4:3", "4/3"}, {"1:1", "square"}, {"9:16", "9/16"}],
    default: "video",
    control: :segmented
  )

  prop(:autoplay, :boolean, label: "Autoplay (muted)", default: false)
  prop(:controls, :boolean, label: "Show controls", default: true)
  prop(:rounded, :boolean, label: "Rounded corners", default: true)

  @aspects %{
    "video" => "aspect-video",
    "4/3" => "aspect-[4/3]",
    "square" => "aspect-square",
    "9/16" => "aspect-[9/16]"
  }

  def render(assigns) do
    assigns = assign(assigns, :source, source(assigns.url))

    ~H"""
    <div {root(assigns, class: ["relative w-full overflow-hidden bg-base-300", Map.get(aspects(), @aspect), @rounded && "rounded-box"])}>
      <%= case {@source, editor?(assigns)} do %>
        <% {{:embed, kind, embed}, false} -> %>
          <iframe
            src={embed <> embed_query(kind, @autoplay, @controls)}
            title={@title}
            class="absolute inset-0 size-full"
            loading="lazy"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen
          ></iframe>
        <% {{:file, file}, false} -> %>
          <video
            src={file}
            poster={@poster != "" && @poster}
            class="absolute inset-0 size-full object-cover"
            controls={@controls}
            autoplay={@autoplay}
            muted={@autoplay}
            loop={@autoplay}
            playsinline
            preload="metadata"
          ></video>
        <% {source, true} -> %>
          <div
            class="absolute inset-0 grid place-items-center bg-neutral text-neutral-content"
            style={preview_style(source, @poster)}
          >
            <span class="flex flex-col items-center gap-2 rounded-box bg-black/50 px-4 py-3 text-sm">
              <.heroicon name="play-circle" style="solid" class="size-12" />
              {if(source == nil, do: t("Paste a YouTube or Vimeo link"), else: @title)}
            </span>
          </div>
        <% _ -> %>
      <% end %>
    </div>
    """
  end

  defp source(""), do: nil

  defp source(url) do
    case URL.video_embed(url) do
      {kind, embed} -> {:embed, kind, embed}
      nil -> if url =~ ~r/\.(mp4|webm|ogg|mov)(\?.*)?\z/i, do: {:file, url}
    end
  end

  defp embed_query(:youtube, autoplay, controls),
    do:
      "?rel=0" <>
        if(autoplay, do: "&autoplay=1&mute=1", else: "") <>
        if(controls, do: "", else: "&controls=0")

  defp embed_query(:vimeo, autoplay, controls),
    do:
      "?dnt=1" <>
        if(autoplay, do: "&autoplay=1&muted=1", else: "") <>
        if(controls, do: "", else: "&controls=0")

  # YouTube serves a thumbnail for every video; Vimeo needs its API, so it gets
  # the plain preview.
  defp preview_style({:embed, :youtube, embed}, _poster) do
    id = embed |> String.split("/") |> List.last()

    style([
      {"background-image", "url(https://i.ytimg.com/vi/#{id}/hqdefault.jpg)"},
      {"background-size", "cover"},
      {"background-position", "center"}
    ])
  end

  defp preview_style(_source, poster) when poster != "",
    do:
      style([
        {"background-image", "url(#{poster})"},
        {"background-size", "cover"},
        {"background-position", "center"}
      ])

  defp preview_style(_source, _poster), do: nil

  defp aspects, do: @aspects
end
