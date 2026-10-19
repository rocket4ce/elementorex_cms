defmodule ElementorexCms.URL do
  @moduledoc """
  Sanitizes the URLs that end up in `href`, `src` and CSS `url()`.

  Only `http`, `https`, `mailto` and `tel` URLs are kept, besides relative paths
  (`/precios`, `../a`, `?q=1`) and anchors (`#contacto`). Anything with another
  scheme (`javascript:`, `data:`, `vbscript:`...) is dropped, as are URLs with
  control characters or whitespace, which browsers strip before parsing (so
  `java\\tscript:` would otherwise slip through).
  """

  @link_schemes ~w(http https mailto tel)
  @media_schemes ~w(http https)
  @max_length 2048

  @doc """
  Returns the URL if it is safe to use in a link, or `nil`.

  Options:

    * `:schemes` - allowed schemes (default `#{inspect(@link_schemes)}`)

  ## Examples

      iex> ElementorexCms.URL.sanitize("https://example.com/a?b=1")
      "https://example.com/a?b=1"
      iex> ElementorexCms.URL.sanitize("/precios#planes")
      "/precios#planes"
      iex> ElementorexCms.URL.sanitize("JavaScript:alert(1)")
      nil
  """
  @spec sanitize(term(), keyword()) :: String.t() | nil
  def sanitize(url, opts \\ [])

  def sanitize(url, opts) when is_binary(url) do
    url = url |> String.trim() |> String.replace(" ", "%20")
    schemes = Keyword.get(opts, :schemes, @link_schemes)

    cond do
      url == "" -> nil
      byte_size(url) > @max_length -> nil
      not String.valid?(url) -> nil
      url =~ ~r/[\x00-\x20\x7F]/u -> nil
      true -> check_scheme(url, schemes)
    end
  end

  def sanitize(_url, _opts), do: nil

  @doc "Like `sanitize/2`, for images and media (`http` and `https` only, besides relative URLs)."
  @spec sanitize_media(term()) :: String.t() | nil
  def sanitize_media(url), do: sanitize(url, schemes: @media_schemes)

  @doc """
  Turns a YouTube or Vimeo page URL into its canonical embed URL, or `nil` if it
  is neither. Only the video id is taken from the input, so nothing else from the
  URL reaches the `<iframe>`.

      iex> ElementorexCms.URL.video_embed("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      {:youtube, "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"}
      iex> ElementorexCms.URL.video_embed("https://vimeo.com/76979871")
      {:vimeo, "https://player.vimeo.com/video/76979871"}
  """
  @spec video_embed(term()) :: {:youtube | :vimeo, String.t()} | nil
  def video_embed(url) when is_binary(url) do
    url = String.trim(url)

    cond do
      id = youtube_id(url) -> {:youtube, "https://www.youtube-nocookie.com/embed/#{id}"}
      id = vimeo_id(url) -> {:vimeo, "https://player.vimeo.com/video/#{id}"}
      true -> nil
    end
  end

  def video_embed(_url), do: nil

  defp youtube_id(url) do
    patterns = [
      ~r"\A(?:https?://)?(?:www\.|m\.)?youtube(?:-nocookie)?\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/|live/)([A-Za-z0-9_-]{11})",
      ~r"\A(?:https?://)?youtu\.be/([A-Za-z0-9_-]{11})"
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, url) do
        [_, id] -> id
        _ -> nil
      end
    end)
  end

  defp vimeo_id(url) do
    case Regex.run(~r"\A(?:https?://)?(?:www\.|player\.)?vimeo\.com/(?:video/)?(\d{6,12})", url) do
      [_, id] -> id
      _ -> nil
    end
  end

  defp check_scheme(url, schemes) do
    case Regex.run(~r/\A([a-zA-Z][a-zA-Z0-9+.-]*):/, url) do
      [_, scheme] -> if String.downcase(scheme) in schemes, do: url
      nil -> url
    end
  end
end
