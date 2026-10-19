defmodule ElementorexCms.CSS do
  @moduledoc """
  Validation of the CSS that documents carry.

  Styles are data: a map of property → value per device. Before a declaration is
  written to a stylesheet its property must be in an allow-list and its value
  must match the grammar of that property (lengths, colors, keywords...), so a
  stored document can never break out of its rule (`}`), load resources
  (`@import`) or run script (`expression()`).

  Custom CSS written by hand (the *Custom CSS* field of an element or of the
  document) is a different case: it is free text, so `scope/2` neutralizes the
  dangerous parts and nests it inside the element's selector, which keeps its
  rules from leaking to the rest of the page.
  """

  alias ElementorexCms.URL

  @length ~r/\A-?(\d{1,5}(\.\d{1,4})?|\.\d{1,4})(px|rem|em|%|vh|vw|vmin|vmax|svh|dvh|ch|ex)\z/
  @number ~r/\A-?(\d{1,5}(\.\d{1,4})?|\.\d{1,4})\z/
  @hex ~r/\A#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\z/
  @color_fn ~r/\A(rgb|rgba|hsl|hsla|oklch|oklab|lab|lch|hwb|color-mix)\([0-9a-z.,%\s\/+-]{1,80}\)\z/
  @css_var ~r/\Avar\(--[a-zA-Z0-9-]{1,48}\)\z/
  @named_color ~r/\A[a-zA-Z]{3,20}\z/
  @font_family ~r/\A[a-zA-Z0-9 ,"'-]{1,120}\z/

  @spacing ~w(margin-top margin-right margin-bottom margin-left
              padding-top padding-right padding-bottom padding-left)
  @sizes ~w(width min-width max-width height min-height max-height)
  @radius ~w(border-top-left-radius border-top-right-radius border-bottom-right-radius
             border-bottom-left-radius)
  @border_widths ~w(border-top-width border-right-width border-bottom-width border-left-width)
  @gaps ~w(gap row-gap column-gap)

  @keywords %{
    "text-align" => ~w(left center right justify start end),
    "font-weight" => ~w(100 200 300 400 500 600 700 800 900 normal bold),
    "font-style" => ~w(normal italic),
    "text-transform" => ~w(none uppercase lowercase capitalize),
    "text-decoration-line" => ~w(none underline line-through overline),
    "border-style" => ~w(none solid dashed dotted double),
    "background-size" => ~w(auto cover contain),
    "background-position" =>
      ~w(center top bottom left right) ++
        ["top left", "top right", "bottom left", "bottom right", "center top", "center bottom"],
    "background-repeat" => ~w(no-repeat repeat repeat-x repeat-y),
    "background-attachment" => ~w(scroll fixed),
    "object-fit" => ~w(fill contain cover none scale-down),
    "align-self" => ~w(auto flex-start center flex-end stretch baseline),
    "justify-self" => ~w(auto start center end stretch),
    "overflow" => ~w(visible hidden clip auto),
    "white-space" => ~w(normal nowrap pre-line),
    "display" => ~w(block inline-block flex inline-flex grid none),
    "flex-direction" => ~w(row row-reverse column column-reverse),
    "flex-wrap" => ~w(nowrap wrap),
    "justify-content" => ~w(flex-start center flex-end space-between space-around space-evenly),
    "align-items" => ~w(flex-start center flex-end stretch baseline),
    "position" => ~w(static relative)
  }

  # Box shadows offered by the editor. Shadows are chosen from these presets
  # instead of being typed, which keeps their grammar out of the allow-list.
  @shadows %{
    "none" => "none",
    "xs" => "0 1px 2px 0 rgb(0 0 0 / 0.05)",
    "sm" => "0 1px 3px 0 rgb(0 0 0 / 0.1), 0 1px 2px -1px rgb(0 0 0 / 0.1)",
    "md" => "0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)",
    "lg" => "0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)",
    "xl" => "0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)",
    "2xl" => "0 25px 50px -12px rgb(0 0 0 / 0.25)",
    "inner" => "inset 0 2px 4px 0 rgb(0 0 0 / 0.05)"
  }

  @properties @spacing ++
                @sizes ++
                @radius ++
                @border_widths ++
                @gaps ++
                Map.keys(@keywords) ++
                ~w(color background-color border-color font-size line-height letter-spacing
                   font-family opacity box-shadow background-image flex-grow flex-shrink
                   flex-basis order aspect-ratio z-index)

  @doc "Properties a style map may set."
  @spec properties() :: [String.t()]
  def properties, do: @properties

  @doc "The box-shadow presets: `%{name => css}`."
  @spec shadows() :: %{String.t() => String.t()}
  def shadows, do: @shadows

  @doc """
  Validates one declaration. Returns the value to write (sometimes normalized,
  like a shadow preset expanded to its CSS) or `nil` when it must be dropped.

      iex> ElementorexCms.CSS.value("padding-top", "24px")
      "24px"
      iex> ElementorexCms.CSS.value("color", "var(--color-primary)")
      "var(--color-primary)"
      iex> ElementorexCms.CSS.value("color", "red;}body{display:none")
      nil
      iex> ElementorexCms.CSS.value("behavior", "url(x.htc)")
      nil
  """
  @spec value(String.t(), term()) :: String.t() | nil
  def value(property, value) when is_binary(property) and is_binary(value) do
    value = String.trim(value)

    if value == "" or property not in @properties do
      nil
    else
      validate(property, value)
    end
  end

  def value(property, value) when is_binary(property) and is_number(value),
    do: value(property, to_string(value))

  def value(_property, _value), do: nil

  @doc "Whether `value` is a color the styles accept."
  @spec color?(term()) :: boolean()
  def color?(value) when is_binary(value) do
    value = String.trim(value)
    Enum.any?([@hex, @color_fn, @css_var, @named_color], &(value =~ &1))
  end

  def color?(_value), do: false

  @doc "Whether `value` is a CSS length (`12px`, `1.5rem`, `50%`, `0`...)."
  @spec length?(term()) :: boolean()
  def length?(value) when is_binary(value), do: value == "0" or value =~ @length
  def length?(_value), do: false

  defp validate(p, v) when p in @spacing, do: length_or(v, ~w(auto))

  defp validate(p, v) when p in @sizes,
    do: length_or(v, ~w(auto none fit-content max-content min-content))

  defp validate(p, v) when p in @radius, do: length_or(v, [])
  defp validate(p, v) when p in @border_widths, do: length_or(v, [])
  defp validate(p, v) when p in @gaps, do: length_or(v, [])
  defp validate("font-size", v), do: length_or(v, [])
  defp validate("letter-spacing", v), do: length_or(v, ~w(normal))
  defp validate("flex-basis", v), do: length_or(v, ~w(auto))
  defp validate("line-height", v), do: if(v =~ @number, do: v, else: length_or(v, ~w(normal)))
  defp validate("opacity", v), do: number_in(v, 0, 1)
  defp validate("flex-grow", v), do: number_in(v, 0, 20)
  defp validate("flex-shrink", v), do: number_in(v, 0, 20)
  defp validate("order", v), do: integer_in(v, -100, 100)
  defp validate("z-index", v), do: integer_in(v, -10, 100)

  defp validate("aspect-ratio", v) do
    if v == "auto" or v =~ ~r/\A\d{1,4}(\.\d{1,3})?\s*\/\s*\d{1,4}(\.\d{1,3})?\z/, do: v
  end

  defp validate(p, v) when p in ~w(color background-color border-color), do: if(color?(v), do: v)
  defp validate("font-family", v), do: if(v =~ @font_family, do: v)
  defp validate("box-shadow", v), do: Map.get(@shadows, v)
  defp validate("background-image", v), do: background_image(v)

  defp validate(p, v) do
    case Map.fetch(@keywords, p) do
      {:ok, allowed} -> if v in allowed, do: v
      :error -> nil
    end
  end

  defp length_or(v, keywords) do
    cond do
      v in keywords -> v
      v == "0" -> v
      v =~ @length -> v
      true -> nil
    end
  end

  defp number_in(v, min, max) do
    with true <- v =~ @number,
         {number, ""} <- Float.parse(v),
         true <- number >= min and number <= max do
      v
    else
      _ -> nil
    end
  end

  defp integer_in(v, min, max) do
    case Integer.parse(v) do
      {int, ""} when int >= min and int <= max -> v
      _ -> nil
    end
  end

  # Background images come either from an image URL (`url(...)`) or from the
  # gradient control, which builds `linear-gradient(<angle>deg, <color>, <color>)`.
  defp background_image("none"), do: "none"

  defp background_image(v) do
    cond do
      match = Regex.run(~r/\Aurl\(\s*["']?([^"'()\s]+)["']?\s*\)\z/, v) ->
        [_, url] = match
        if safe = URL.sanitize_media(url), do: ~s|url("#{escape_url(safe)}")|

      match = Regex.run(~r/\A(linear|radial)-gradient\((.{1,240})\)\z/, v) ->
        [_, kind, args] = match
        gradient(kind, args)

      true ->
        nil
    end
  end

  defp gradient(kind, args) do
    parts = args |> String.split(",") |> Enum.map(&String.trim/1)

    valid? =
      Enum.all?(parts, fn part ->
        part =~ ~r/\A(-?\d{1,3}deg|to (top|bottom|left|right)( (left|right))?|circle|ellipse)\z/ or
          color_stop?(part)
      end)

    if valid? and length(parts) <= 6, do: "#{kind}-gradient(#{Enum.join(parts, ", ")})"
  end

  defp color_stop?(part) do
    case Regex.run(~r/\A(.+?)(\s+\d{1,3}%)?\z/, part) do
      [_, color | _] -> color?(color)
      _ -> false
    end
  end

  defp escape_url(url), do: String.replace(url, ~s("), "%22")

  @doc """
  Writes a declaration block from a map of property → value, dropping invalid
  declarations. Keys are written in a stable order.

      iex> ElementorexCms.CSS.declarations(%{"color" => "#fff", "x" => "1", "padding-top" => "8px"})
      "color:#fff;padding-top:8px"
  """
  @spec declarations(map()) :: String.t()
  def declarations(styles) when is_map(styles) do
    styles
    |> Enum.sort_by(fn {property, _} -> property end)
    |> Enum.flat_map(fn {property, value} ->
      case value(to_string(property), value) do
        nil -> []
        valid -> ["#{property}:#{valid}"]
      end
    end)
    |> Enum.join(";")
  end

  def declarations(_styles), do: ""

  @doc """
  Parses an inline `style` attribute (`"color: red; padding: 4px"`) keeping only
  valid declarations. Used by the HTML sanitizer.
  """
  @spec sanitize_inline(String.t()) :: String.t()
  def sanitize_inline(style) when is_binary(style) do
    style
    |> String.split(";")
    |> Enum.flat_map(fn declaration ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] -> [{String.downcase(String.trim(property)), String.trim(value)}]
        _ -> []
      end
    end)
    |> Enum.flat_map(fn {property, value} ->
      case value(property, value) do
        nil -> []
        valid -> ["#{property}: #{valid}"]
      end
    end)
    |> Enum.join("; ")
  end

  @max_custom 20_000

  @doc """
  Prepares hand-written CSS and nests it inside `selector` using CSS nesting, so
  every rule applies only inside the element (or document) it belongs to.

  The keyword `selector` refers to the element itself, like in Elementor:

      selector { box-shadow: none }
      selector .btn:hover { transform: translateY(-2px) }

  Declarations written outside any rule apply to the element as well. Before
  nesting, the text loses `<` (so it can never close the `<style>` element),
  `@import`/`@charset`/`@namespace` rules, `expression()`, `behavior`,
  `-moz-binding`, `javascript:` and every `url()` that is not a safe http(s) or
  relative URL. Returns `""` for empty input.
  """
  @spec scope(String.t() | nil, String.t()) :: String.t()
  def scope(nil, _selector), do: ""

  def scope(css, selector) when is_binary(css) do
    css =
      css
      |> String.slice(0, @max_custom)
      |> neutralize()
      |> String.replace(~r/\bselector\b/, "&")
      |> String.trim()

    if css == "" or not balanced?(css), do: "", else: "#{selector}{#{css}}"
  end

  @doc false
  def neutralize(css) do
    css
    |> String.replace("<", "")
    |> String.replace(~r{/\*.*?\*/}s, "")
    |> String.replace(~r/@(import|charset|namespace)[^;{}]*;?/i, "")
    |> String.replace(~r/expression\s*\(/i, "(")
    |> String.replace(~r/(-moz-binding|behavior)\s*:/i, "x-blocked:")
    |> String.replace(~r/javascript\s*:/i, "")
    |> String.replace(~r/url\(\s*(['"]?)(.*?)\1\s*\)/i, fn match ->
      [_, _quote, url] = Regex.run(~r/url\(\s*(['"]?)(.*?)\1\s*\)/i, match)

      case URL.sanitize_media(url) do
        nil -> "none"
        safe -> ~s|url("#{escape_url(safe)}")|
      end
    end)
  end

  # Unbalanced braces could close the scope rule and leak the rest of the text
  # as global rules, so such CSS is dropped as a whole.
  defp balanced?(css) do
    css
    |> String.graphemes()
    |> Enum.reduce_while(0, fn
      "{", depth -> {:cont, depth + 1}
      "}", 0 -> {:halt, -1}
      "}", depth -> {:cont, depth - 1}
      _, depth -> {:cont, depth}
    end)
    |> Kernel.==(0)
  end
end
