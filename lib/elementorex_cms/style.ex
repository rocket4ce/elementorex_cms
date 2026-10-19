defmodule ElementorexCms.Style do
  @moduledoc """
  Builds the stylesheet of a document from the styles of its nodes.

  Each node's declarations are scoped to its id. Desktop styles are the base;
  tablet and mobile override them below their breakpoints, which match
  Tailwind's `lg` and `md` (so `max-lg:`/`max-md:` classes and these styles agree):

  | State     | Applies                       |
  | --------- | ----------------------------- |
  | `desktop` | always (base)                 |
  | `tablet`  | `max-width: 1023.98px`        |
  | `mobile`  | `max-width: 767.98px`         |
  | `hover`   | `:hover` of the element       |

  Also written here: *Hide on* (per device), entrance animations (only when the
  visitor has no reduced-motion preference) and the hand-written CSS of nodes and
  of the document, nested in their scope (see `ElementorexCms.CSS.scope/2`).

  On the editor canvas hidden elements are dimmed instead of removed, so they can
  still be selected.
  """

  alias ElementorexCms.CSS
  alias ElementorexCms.Document

  @tablet "(max-width:1023.98px)"
  @mobile "(max-width:767.98px)"

  @hide_media %{
    "desktop" => "(min-width:1024px)",
    "tablet" => "(min-width:768px) and (max-width:1023.98px)",
    "mobile" => "(max-width:767.98px)"
  }

  @keyframes %{
    "fade-in" => "@keyframes exr-fade-in{from{opacity:0}to{opacity:1}}",
    "fade-up" =>
      "@keyframes exr-fade-up{from{opacity:0;transform:translateY(28px)}to{opacity:1;transform:none}}",
    "fade-down" =>
      "@keyframes exr-fade-down{from{opacity:0;transform:translateY(-28px)}to{opacity:1;transform:none}}",
    "fade-left" =>
      "@keyframes exr-fade-left{from{opacity:0;transform:translateX(28px)}to{opacity:1;transform:none}}",
    "fade-right" =>
      "@keyframes exr-fade-right{from{opacity:0;transform:translateX(-28px)}to{opacity:1;transform:none}}",
    "zoom-in" =>
      "@keyframes exr-zoom-in{from{opacity:0;transform:scale(.92)}to{opacity:1;transform:none}}"
  }

  # Spacing of rich text (paragraphs, lists, quotes...) inside blocks, which
  # Tailwind's preflight resets. `:where` keeps it at the specificity of one
  # class, so the styles of a node win over it.
  @base ".exr-rich>:where(p,ul,ol,blockquote,h2,h3,h4,pre){margin:0 0 .75em}" <>
          ".exr-rich>:last-child{margin-bottom:0}" <>
          ".exr-rich :where(ul){list-style:disc;padding-left:1.25em}" <>
          ".exr-rich :where(ol){list-style:decimal;padding-left:1.25em}" <>
          ".exr-rich :where(li){margin:.2em 0}" <>
          ".exr-rich :where(a){text-decoration:underline;text-underline-offset:2px}" <>
          ".exr-rich :where(blockquote){border-left:4px solid currentColor;padding-left:1em;font-style:italic;opacity:.85}" <>
          ".exr-rich :where(h2){font-size:1.5em;font-weight:700;line-height:1.2}" <>
          ".exr-rich :where(h3){font-size:1.25em;font-weight:700;line-height:1.25}" <>
          ".exr-rich :where(h4){font-weight:700}" <>
          ".exr-rich :where(hr){margin:1em 0;border:0;border-top:1px solid color-mix(in oklab,currentColor 20%,transparent)}" <>
          ".exr-rich :where(code){font-family:ui-monospace,monospace;font-size:.9em;padding:.1em .3em;" <>
          "border-radius:.3em;background:color-mix(in oklab,currentColor 8%,transparent)}"

  @doc "The base stylesheet of rich text (`.exr-rich`), included with every document."
  def base_css, do: @base

  @doc "Media queries of the responsive states: `%{\"tablet\" => ..., \"mobile\" => ...}`."
  def media, do: %{"tablet" => @tablet, "mobile" => @mobile}

  @doc "CSS selector of a node."
  @spec selector(map() | String.t()) :: String.t()
  def selector(%{"id" => id}), do: selector(id)
  def selector(id) when is_binary(id), do: ~s([data-ex-id="#{id}"])

  @doc "CSS selector of a document (its root carries `data-ex-doc`)."
  @spec doc_selector(Document.t()) :: String.t()
  def doc_selector(doc), do: ~s([data-ex-doc="#{Document.root(doc)["id"]}"])

  @doc """
  The stylesheet of a document. Options:

    * `:mode` - `:public` (default) or `:editor`
    * `:base` - include `base_css/0` (default `true`)
  """
  @spec css(Document.t(), keyword()) :: String.t()
  def css(doc, opts \\ []) do
    mode = Keyword.get(opts, :mode, :public)
    nodes = Document.nodes(doc)
    root = Document.root(doc)

    [
      if(Keyword.get(opts, :base, true), do: @base),
      Enum.map(nodes, &rule(&1, "desktop")),
      Enum.map(nodes, &hover_rule/1),
      media(@tablet, Enum.map(nodes, &rule(&1, "tablet"))),
      media(@mobile, Enum.map(nodes, &rule(&1, "mobile"))),
      hide_rules(nodes, mode),
      animation_rules(nodes),
      Enum.map(nodes, fn node ->
        if node["id"] == root["id"],
          do: "",
          else: CSS.scope(get_in(node, ["attrs", "css"]), selector(node))
      end),
      CSS.scope(get_in(root, ["attrs", "css"]), doc_selector(doc))
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  @doc """
  CSS of a single node (its states, visibility, animation and custom CSS),
  formatted for reading. Used by the editor's code panel.
  """
  @spec node_css(map(), keyword()) :: String.t()
  def node_css(node, opts \\ []) do
    css(
      %{"version" => 1, "root" => Map.put(node, "children", [])},
      Keyword.put(opts, :base, false)
    )
  end

  @doc """
  Formats a stylesheet one declaration per line, for display.

      iex> ElementorexCms.Style.pretty("a{color:red;margin:0}")
      "a {\\n  color: red;\\n  margin: 0;\\n}"
  """
  @spec pretty(String.t()) :: String.t()
  def pretty(css) do
    {lines, _depth, buffer, _quote, _parens} =
      css
      |> String.graphemes()
      |> Enum.reduce({[], 0, "", nil, 0}, &pretty_char/2)

    lines = if String.trim(buffer) == "", do: lines, else: [String.trim(buffer) | lines]

    lines
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp pretty_char(char, {lines, depth, buffer, quote, parens}) when quote != nil do
    {lines, depth, buffer <> char, if(char == quote, do: nil, else: quote), parens}
  end

  defp pretty_char(char, {lines, depth, buffer, nil, parens}) when char in ["\"", "'"],
    do: {lines, depth, buffer <> char, char, parens}

  defp pretty_char("(", {lines, depth, buffer, nil, parens}),
    do: {lines, depth, buffer <> "(", nil, parens + 1}

  defp pretty_char(")", {lines, depth, buffer, nil, parens}),
    do: {lines, depth, buffer <> ")", nil, max(parens - 1, 0)}

  defp pretty_char("{", {lines, depth, buffer, nil, 0}) do
    {[indent(depth) <> String.trim(buffer) <> " {" | lines], depth + 1, "", nil, 0}
  end

  defp pretty_char(";", {lines, depth, buffer, nil, 0}) do
    {declaration_line(lines, depth, buffer), depth, "", nil, 0}
  end

  defp pretty_char("}", {lines, depth, buffer, nil, 0}) do
    lines = declaration_line(lines, depth, buffer)
    depth = max(depth - 1, 0)
    {[indent(depth) <> "}" | lines], depth, "", nil, 0}
  end

  defp pretty_char("\n", state), do: state

  defp pretty_char(char, {lines, depth, buffer, nil, parens}),
    do: {lines, depth, buffer <> char, nil, parens}

  defp declaration_line(lines, depth, buffer) do
    case String.trim(buffer) do
      "" ->
        lines

      declaration ->
        formatted =
          case String.split(declaration, ":", parts: 2) do
            [property, value] -> String.trim(property) <> ": " <> String.trim(value)
            _ -> declaration
          end

        [indent(depth) <> formatted <> ";" | lines]
    end
  end

  defp indent(depth), do: String.duplicate("  ", depth)

  defp rule(node, state) do
    case CSS.declarations(get_in(node, ["style", state]) || %{}) do
      "" -> nil
      declarations -> "#{selector(node)}{#{declarations}}"
    end
  end

  defp hover_rule(node) do
    case CSS.declarations(get_in(node, ["style", "hover"]) || %{}) do
      "" -> nil
      declarations -> "#{selector(node)}:hover{#{declarations}}"
    end
  end

  defp media(query, rules) do
    case Enum.reject(rules, &is_nil/1) do
      [] -> nil
      rules -> "@media #{query}{#{Enum.join(rules)}}"
    end
  end

  defp hide_rules(nodes, mode) do
    declaration =
      case mode do
        :editor -> "opacity:.35!important;filter:grayscale(1)"
        _ -> "display:none!important"
      end

    for device <- ~w(desktop tablet mobile),
        selectors =
          for(
            node <- nodes,
            device in (get_in(node, ["attrs", "hide_on"]) || []),
            do: selector(node)
          ),
        selectors != [] do
      "@media #{@hide_media[device]}{#{Enum.join(selectors, ",")}{#{declaration}}}"
    end
  end

  defp animation_rules(nodes) do
    animated =
      for node <- nodes,
          animation = get_in(node, ["attrs", "animation"]),
          Map.has_key?(@keyframes, animation) do
        delay = get_in(node, ["attrs", "animation_delay"]) || 0

        {animation,
         "#{selector(node)}{animation:exr-#{animation} .7s cubic-bezier(.2,.7,.2,1) #{delay}ms both}"}
      end

    case animated do
      [] ->
        nil

      animated ->
        keyframes = animated |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.map(&@keyframes[&1])
        rules = Enum.map(animated, &elem(&1, 1))
        "@media (prefers-reduced-motion:no-preference){#{Enum.join(keyframes ++ rules)}}"
    end
  end
end
