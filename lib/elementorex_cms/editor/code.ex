defmodule ElementorexCms.Editor.Code do
  @moduledoc false
  # Formatting and syntax highlighting for the editor's code panel (HTML, CSS
  # and JSON of the selected node). Display only: the output is a list of lines,
  # each one already escaped and wrapped in highlight spans.

  @inline ~w(a abbr b br cite code del em i ins kbd mark q s small span strong sub sup time u)
  @void ~w(br hr img input source col wbr meta link)

  @doc "HTML split into indented, highlighted lines."
  @spec html_lines(String.t()) :: [Phoenix.HTML.safe()]
  def html_lines(html) do
    html
    |> clean()
    |> collapse_svgs()
    |> format_html()
    |> Enum.map(&highlight_html_line/1)
  end

  @doc "CSS split into highlighted lines."
  @spec css_lines(String.t()) :: [Phoenix.HTML.safe()]
  def css_lines(""), do: []

  def css_lines(css) do
    css
    |> ElementorexCms.Style.pretty()
    |> String.split("\n")
    |> Enum.map(&highlight_css_line/1)
  end

  @doc "JSON (pretty printed) split into highlighted lines."
  @spec json_lines(term()) :: [Phoenix.HTML.safe()]
  def json_lines(term) do
    term
    |> Jason.encode!(pretty: true)
    |> String.split("\n")
    |> Enum.map(&highlight_json_line/1)
  end

  @doc "The plain text of the formatted HTML (for copying)."
  @spec html_text(String.t()) :: String.t()
  def html_text(html), do: html |> clean() |> collapse_svgs() |> format_html() |> Enum.join("\n")

  # HEEx debug annotations (comments naming the component and `data-phx-loc`,
  # only in development) are not part of the content.
  defp clean(html) do
    html
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/ data-phx-loc="[^"]*"/, "")
  end

  # SVG paths are long and say nothing in the panel.
  defp collapse_svgs(html) do
    Regex.replace(~r/<svg\b([^>]*)>.*?<\/svg>/s, html, "<svg\\1>…</svg>")
  end

  defp format_html(html) do
    tokens =
      ~r/(<[^>]+>)/
      |> Regex.split(html, include_captures: true, trim: true)
      |> Enum.map(fn token ->
        if String.starts_with?(token, "<"), do: {:tag, token}, else: {:text, String.trim(token)}
      end)
      |> Enum.reject(&(&1 == {:text, ""}))

    {lines, current, _depth} =
      Enum.reduce(tokens, {[], [], 0}, fn
        {:text, text}, {lines, current, depth} ->
          {lines, [text | current], depth}

        {:tag, tag}, {lines, current, depth} ->
          name = tag_name(tag)

          cond do
            name in @inline or name == "svg" ->
              {lines, [tag | current], depth}

            String.starts_with?(tag, "</") ->
              lines = flush(lines, current, depth)
              depth = max(depth - 1, 0)
              {[indent(depth) <> tag | lines], [], depth}

            name in @void or String.ends_with?(tag, "/>") ->
              lines = flush(lines, current, depth)
              {[indent(depth) <> tag | lines], [], depth}

            true ->
              lines = flush(lines, current, depth)
              {[indent(depth) <> tag | lines], [], depth + 1}
          end
      end)

    lines
    |> flush(current, 0)
    |> Enum.reverse()
  end

  defp flush(lines, [], _depth), do: lines

  defp flush(lines, current, depth),
    do: [
      indent(depth) <>
        (current |> Enum.reverse() |> Enum.join(" ") |> String.replace(~r/\s+/, " "))
      | lines
    ]

  defp indent(depth), do: String.duplicate("  ", depth)

  defp tag_name(tag) do
    case Regex.run(~r/\A<\/?([a-zA-Z0-9-]+)/, tag) do
      [_, name] -> String.downcase(name)
      _ -> ""
    end
  end

  defp highlight_html_line(line) do
    ~r/(<[^>]+>)/
    |> Regex.split(line, include_captures: true)
    |> Enum.map(fn
      "<" <> _ = tag -> highlight_tag(tag)
      text -> escape(text)
    end)
    |> Phoenix.HTML.raw()
  end

  defp highlight_tag(tag) do
    case Regex.run(~r/\A<(\/?)([a-zA-Z0-9-]+)(.*?)(\/?)>\z/s, tag) do
      [_, slash, name, attrs, self_close] ->
        [
          ~s(<span class="exr-tk-p">&lt;#{slash}</span><span class="exr-tk-t">#{escape(name)}</span>),
          highlight_attrs(attrs),
          ~s(<span class="exr-tk-p">#{self_close}&gt;</span>)
        ]

      _ ->
        escape(tag)
    end
  end

  defp highlight_attrs(attrs) do
    Regex.replace(~r/([^\s=]+)=("[^"]*"|'[^']*')|([^\s]+)/, attrs, fn
      _, name, value, "" when name != "" ->
        ~s(<span class="exr-tk-a">#{escape(name)}</span>=<span class="exr-tk-s">#{escape(value)}</span>)

      match, _, _, _ ->
        ~s(<span class="exr-tk-a">#{escape(match)}</span>)
    end)
  end

  defp highlight_css_line(line) do
    trimmed = String.trim(line)
    indent = String.duplicate(" ", String.length(line) - String.length(String.trim_leading(line)))

    html =
      cond do
        String.ends_with?(trimmed, "{") ->
          ~s(#{indent}<span class="exr-tk-t">#{escape(trimmed)}</span>)

        trimmed == "}" ->
          ~s(#{indent}<span class="exr-tk-p">}</span>)

        match = Regex.run(~r/\A([^:]+):\s*(.*);\z/, trimmed) ->
          [_, property, value] = match

          ~s(#{indent}<span class="exr-tk-a">#{escape(property)}</span>: <span class="exr-tk-v">#{escape(value)}</span>;)

        true ->
          indent <> escape(trimmed)
      end

    Phoenix.HTML.raw(html)
  end

  defp highlight_json_line(line) do
    line
    |> escape()
    |> then(
      &Regex.replace(
        ~r/(&quot;(?:[^&]|&(?!quot;))*?&quot;)(\s*:)/,
        &1,
        ~s(<span class="exr-tk-a">\\1</span>\\2)
      )
    )
    |> then(
      &Regex.replace(
        ~r/(:\s*)(&quot;(?:[^&]|&(?!quot;))*?&quot;)/,
        &1,
        ~s(\\1<span class="exr-tk-s">\\2</span>)
      )
    )
    |> then(
      &Regex.replace(
        ~r/(:\s*)(-?\d+(?:\.\d+)?|true|false|null)/,
        &1,
        ~s(\\1<span class="exr-tk-v">\\2</span>)
      )
    )
    |> Phoenix.HTML.raw()
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
