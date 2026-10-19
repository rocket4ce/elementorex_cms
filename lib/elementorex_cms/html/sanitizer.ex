defmodule ElementorexCms.HTML.Sanitizer do
  @moduledoc """
  Allow-list HTML sanitizer for the rich text and the HTML of documents.

  The input is tokenized and rebuilt from scratch: only allowed tags are written
  back, each with its allowed attributes, every attribute value is validated
  (URLs, CSS, ids, classes...) and escaped again, and text is escaped. Nothing of
  the input is copied verbatim, so malformed markup cannot smuggle anything
  through.

  ## Policies

    * `:inline` - formatting inside a line (`<strong>`, `<em>`, `<a>`, `<br>`...),
      for headings and buttons
    * `:rich` - `:inline` plus paragraphs, lists, quotes, `<h2>`-`<h6>`, `<hr>`
      and `<pre>`, for text blocks (the default)
    * `:html` - `:rich` plus layout tags, images, tables, `<details>` and
      `<video>`, for the *HTML* block

  Under every policy `<script>`, `<style>`, `<iframe>`, `<object>`, `<svg>`,
  `<math>`, forms and their contents are removed, as are comments, event
  handlers (`on*`), `phx-*` bindings and URLs with schemes other than http(s),
  `mailto` and `tel`. Disallowed tags are removed but their text is kept.

      iex> ElementorexCms.HTML.Sanitizer.sanitize(~s|<p onclick="x()">Hola <b>mundo</b><script>alert(1)</script></p>|)
      "<p>Hola <b>mundo</b></p>"
      iex> ElementorexCms.HTML.Sanitizer.sanitize(~s|<a href="javascript:alert(1)">x</a>|)
      "<a>x</a>"
  """

  alias ElementorexCms.CSS
  alias ElementorexCms.URL

  @inline ~w(a abbr b br cite code del dfn em i ins kbd mark q s samp small span strong sub sup
             time u var wbr)
  @rich @inline ++ ~w(p ul ol li blockquote h2 h3 h4 h5 h6 hr pre)
  @html @rich ++
          ~w(h1 div section article header footer aside nav main figure figcaption img picture
             source table thead tbody tfoot tr th td caption colgroup col details summary dl dt
             dd address video)

  @void ~w(br hr img wbr source col)

  # Removed together with everything inside them.
  @drop_content ~w(script style iframe object embed noscript template textarea select title xmp
                   plaintext noembed noframes math svg applet frameset head)

  @tag_attrs %{
    "a" => ~w(href target rel title),
    "abbr" => ~w(title),
    "blockquote" => ~w(cite),
    "q" => ~w(cite),
    "time" => ~w(datetime),
    "ol" => ~w(start reversed type),
    "li" => ~w(value),
    "img" => ~w(src alt width height loading decoding),
    "source" => ~w(src type),
    "td" => ~w(colspan rowspan),
    "th" => ~w(colspan rowspan scope),
    "col" => ~w(span),
    "colgroup" => ~w(span),
    "details" => ~w(open),
    "video" => ~w(src poster controls autoplay muted loop playsinline preload width height)
  }

  @global ~w(class id title dir lang role style)
  @boolean ~w(reversed open controls autoplay muted loop playsinline)
  @rel_tokens ~w(noopener noreferrer nofollow ugc sponsored external)
  @max_depth 64
  @max_input 200_000

  @type policy :: :inline | :rich | :html

  @doc "Sanitizes `html` with the given policy (`:rich` by default)."
  @spec sanitize(String.t() | nil, policy()) :: String.t()
  def sanitize(html, policy \\ :rich)
  def sanitize(nil, _policy), do: ""

  def sanitize(html, policy) when is_binary(html) and policy in [:inline, :rich, :html] do
    html =
      if byte_size(html) > @max_input, do: binary_part(html, 0, @max_input), else: html

    html = if String.valid?(html), do: html, else: :unicode.characters_to_binary(html, :latin1)

    {acc, stack} = scan(html, policy, [], [])
    closing = Enum.map(stack, &["</", &1, ">"])

    IO.iodata_to_binary([Enum.reverse(acc), closing])
  end

  @doc """
  Plain text of an HTML fragment: tags removed, entities of the basic set
  decoded and whitespace collapsed. For excerpts, search and `alt` texts.

      iex> ElementorexCms.HTML.Sanitizer.text("<p>Hola&nbsp;<b>mundo</b></p><p>!</p>")
      "Hola mundo !"
  """
  @spec text(String.t() | nil) :: String.t()
  def text(nil), do: ""

  def text(html) when is_binary(html) do
    html
    |> sanitize(:inline)
    |> String.replace(~r/<br\s*\/?>/, " ")
    |> String.replace(~r/<[^>]*>/, " ")
    |> decode_entities()
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  @doc """
  Escapes plain text as HTML, turning line breaks into `<br>`.

      iex> ElementorexCms.HTML.Sanitizer.text_to_html("a < b\\nc")
      "a &lt; b<br>c"
  """
  @spec text_to_html(String.t() | nil) :: String.t()
  def text_to_html(nil), do: ""

  def text_to_html(text) when is_binary(text) do
    text
    |> escape_all()
    |> String.replace(~r/\r?\n/, "<br>")
  end

  ## Scanner

  defp scan(html, policy, acc, stack) do
    case :binary.match(html, "<") do
      :nomatch ->
        {[escape_text(html) | acc], stack}

      {pos, 1} ->
        text = binary_part(html, 0, pos)
        rest = binary_part(html, pos + 1, byte_size(html) - pos - 1)
        acc = [escape_text(text) | acc]
        tag(rest, policy, acc, stack)
    end
  end

  # Comments, doctypes and processing instructions are dropped.
  defp tag("!--" <> rest, policy, acc, stack) do
    case :binary.match(rest, "-->") do
      {pos, 3} -> scan(binary_part(rest, pos + 3, byte_size(rest) - pos - 3), policy, acc, stack)
      :nomatch -> {acc, stack}
    end
  end

  defp tag(<<c, rest::binary>>, policy, acc, stack) when c in [?!, ??] do
    case :binary.match(rest, ">") do
      {pos, 1} -> scan(binary_part(rest, pos + 1, byte_size(rest) - pos - 1), policy, acc, stack)
      :nomatch -> {acc, stack}
    end
  end

  defp tag("/" <> rest, policy, acc, stack) do
    case Regex.run(~r/\A([a-zA-Z][a-zA-Z0-9-]*)\s*>/, rest) do
      [match, name] ->
        rest = binary_part(rest, byte_size(match), byte_size(rest) - byte_size(match))
        {acc, stack} = close(String.downcase(name), acc, stack)
        scan(rest, policy, acc, stack)

      nil ->
        scan(rest, policy, ["&lt;/" | acc], stack)
    end
  end

  defp tag(<<c, _::binary>> = rest, policy, acc, stack) when c in ?a..?z or c in ?A..?Z do
    [name] = Regex.run(~r/\A[a-zA-Z][a-zA-Z0-9-]*/, rest)

    case tag_end(binary_part(rest, byte_size(name), byte_size(rest) - byte_size(name))) do
      {attrs, self_closing?, rest} ->
        open(String.downcase(name), attrs, self_closing?, rest, policy, acc, stack)

      :error ->
        scan(rest, policy, ["&lt;" | acc], stack)
    end
  end

  defp tag(rest, policy, acc, stack), do: scan(rest, policy, ["&lt;" | acc], stack)

  defp open(name, _attrs, _self_closing?, rest, policy, acc, stack) when name in @drop_content do
    case Regex.run(~r{</#{name}\s*>}i, rest, return: :index) do
      [{pos, len}] ->
        scan(binary_part(rest, pos + len, byte_size(rest) - pos - len), policy, acc, stack)

      nil ->
        {acc, stack}
    end
  end

  defp open(name, attrs, self_closing?, rest, policy, acc, stack) do
    cond do
      name not in allowed(policy) or length(stack) >= @max_depth ->
        scan(rest, policy, acc, stack)

      name in @void ->
        case attributes(name, attrs, policy) do
          :drop -> scan(rest, policy, acc, stack)
          attrs -> scan(rest, policy, [["<", name, attrs, ">"] | acc], stack)
        end

      self_closing? ->
        scan(
          rest,
          policy,
          [["<", name, attributes!(name, attrs, policy), "></", name, ">"] | acc],
          stack
        )

      true ->
        scan(rest, policy, [["<", name, attributes!(name, attrs, policy), ">"] | acc], [
          name | stack
        ])
    end
  end

  defp close(name, acc, stack) do
    if name in stack do
      {closed, [^name | rest]} = Enum.split_while(stack, &(&1 != name))
      acc = Enum.reduce(closed ++ [name], acc, &[["</", &1, ">"] | &2])
      {acc, rest}
    else
      {acc, stack}
    end
  end

  defp allowed(:inline), do: @inline
  defp allowed(:rich), do: @rich
  defp allowed(:html), do: @html

  # Finds the `>` that ends the tag, skipping quoted attribute values.
  defp tag_end(binary), do: tag_end(binary, 0, nil)

  defp tag_end(binary, pos, quote) when pos < byte_size(binary) do
    case :binary.at(binary, pos) do
      ?> when quote == nil ->
        attrs = binary_part(binary, 0, pos)
        rest = binary_part(binary, pos + 1, byte_size(binary) - pos - 1)
        {attrs, String.ends_with?(String.trim_trailing(attrs), "/"), rest}

      q when q in [?", ?'] and quote == nil ->
        tag_end(binary, pos + 1, q)

      q when q == quote ->
        tag_end(binary, pos + 1, nil)

      _ ->
        tag_end(binary, pos + 1, quote)
    end
  end

  defp tag_end(_binary, _pos, _quote), do: :error

  ## Attributes

  @attr_regex ~r/([^\s"'>\/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/

  defp attributes!(name, attrs, policy) do
    case attributes(name, attrs, policy) do
      :drop -> []
      attrs -> attrs
    end
  end

  defp attributes(name, raw, policy) do
    allowed = Map.get(@tag_attrs, name, []) ++ @global

    pairs =
      @attr_regex
      |> Regex.scan(raw)
      |> Enum.map(fn [_ | captures] ->
        [attr | values] = captures ++ List.duplicate("", 4 - length(captures))
        value = Enum.find(values, "", &(&1 != ""))
        {String.downcase(attr), decode_entities(value)}
      end)
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.flat_map(fn {attr, value} ->
        if attr in allowed or extra_attr?(attr, policy) do
          case attribute(name, attr, value) do
            nil -> []
            value -> [{attr, value}]
          end
        else
          []
        end
      end)
      |> secure_links(name)

    cond do
      name == "img" and not List.keymember?(pairs, "src", 0) -> :drop
      name == "source" and not List.keymember?(pairs, "src", 0) -> :drop
      true -> Enum.map(pairs, &render_attr/1)
    end
  end

  defp extra_attr?("aria-" <> rest, _policy), do: rest =~ ~r/\A[a-z]{2,30}\z/

  defp extra_attr?("data-" <> rest, :html) do
    rest =~ ~r/\A[a-z0-9][a-z0-9-]{0,39}\z/ and not String.starts_with?(rest, ["ex-", "phx-"])
  end

  defp extra_attr?(_attr, _policy), do: false

  defp attribute(_tag, attr, value) when attr in ["href", "cite"], do: URL.sanitize(value)
  defp attribute(_tag, attr, value) when attr in ["src", "poster"], do: URL.sanitize_media(value)
  defp attribute(_tag, "target", value), do: if(value in ["_blank", "_self"], do: value)

  defp attribute(_tag, "rel", value) do
    tokens = value |> String.split() |> Enum.filter(&(&1 in @rel_tokens))
    if tokens != [], do: Enum.join(tokens, " ")
  end

  defp attribute(_tag, "class", value) do
    tokens =
      value
      |> String.split()
      |> Enum.filter(&(&1 =~ ~r/\A[A-Za-z0-9_:\-\/\[\]\.%#!]{1,80}\z/))
      |> Enum.reject(&String.starts_with?(&1, "exr-"))
      |> Enum.take(40)

    if tokens != [], do: Enum.join(tokens, " ")
  end

  defp attribute(_tag, "id", value), do: if(value =~ ~r/\A[A-Za-z][\w:.-]{0,63}\z/, do: value)

  defp attribute(_tag, "style", value) do
    case CSS.sanitize_inline(value) do
      "" -> nil
      style -> style
    end
  end

  defp attribute(_tag, attr, value)
       when attr in ~w(width height colspan rowspan start value span) do
    if value =~ ~r/\A\d{1,4}\z/, do: value
  end

  defp attribute(_tag, attr, _value) when attr in @boolean, do: true
  defp attribute(_tag, "dir", value), do: if(value in ~w(ltr rtl auto), do: value)
  defp attribute(_tag, "lang", value), do: if(value =~ ~r/\A[a-zA-Z-]{2,15}\z/, do: value)
  defp attribute(_tag, "role", value), do: if(value =~ ~r/\A[a-z ]{2,40}\z/, do: value)
  defp attribute(_tag, "loading", value), do: if(value in ~w(lazy eager), do: value)
  defp attribute(_tag, "decoding", value), do: if(value in ~w(async sync auto), do: value)
  defp attribute(_tag, "preload", value), do: if(value in ~w(none metadata auto), do: value)
  defp attribute(_tag, "scope", value), do: if(value in ~w(row col rowgroup colgroup), do: value)
  defp attribute("ol", "type", value), do: if(value in ~w(1 a A i I), do: value)

  defp attribute("source", "type", value),
    do: if(value =~ ~r/\A[a-z]+\/[a-z0-9.+-]+\z/, do: value)

  defp attribute(_tag, "datetime", value), do: if(value =~ ~r/\A[0-9:TZ+\-. ]{4,40}\z/, do: value)
  defp attribute(_tag, _attr, value), do: String.slice(value, 0, 500)

  # `target="_blank"` links always get `rel="noopener noreferrer"`.
  defp secure_links(pairs, "a") do
    case List.keyfind(pairs, "target", 0) do
      {"target", "_blank"} ->
        rel =
          pairs
          |> List.keyfind("rel", 0, {"rel", ""})
          |> elem(1)
          |> String.split()
          |> Kernel.++(["noopener", "noreferrer"])
          |> Enum.uniq()
          |> Enum.join(" ")

        List.keystore(pairs, "rel", 0, {"rel", rel})

      _ ->
        pairs
    end
  end

  defp secure_links(pairs, _tag), do: pairs

  defp render_attr({attr, true}), do: [" ", attr]
  defp render_attr({attr, value}), do: [" ", attr, "=\"", escape_all(value), "\""]

  ## Escaping

  # Text keeps well-formed entities (`&amp;`, `&nbsp;`, `&#39;`) and escapes
  # everything else that could start markup.
  defp escape_text(""), do: ""

  defp escape_text(text) do
    text
    |> String.replace(
      ~r/&(?!(#\d{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z][a-zA-Z0-9]{1,31});)/,
      "&amp;"
    )
    |> String.replace(">", "&gt;")
  end

  defp escape_all(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  @named %{"amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", "nbsp" => " "}

  @doc false
  def decode_entities(value) do
    Regex.replace(~r/&(#\d{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]{2,8});?/, value, fn match,
                                                                                   entity ->
      case entity do
        "#x" <> hex -> codepoint(String.to_integer(hex, 16), match)
        "#X" <> hex -> codepoint(String.to_integer(hex, 16), match)
        "#" <> dec -> codepoint(String.to_integer(dec), match)
        name -> Map.get(@named, name, match)
      end
    end)
  end

  defp codepoint(cp, match) when cp in 1..0x10FFFF and cp not in 0xD800..0xDFFF do
    <<cp::utf8>>
  rescue
    _ -> match
  end

  defp codepoint(_cp, match), do: match
end
