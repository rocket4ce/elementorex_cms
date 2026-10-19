defmodule ElementorexCms.Heroicons do
  @moduledoc """
  [Heroicons](https://heroicons.com) v2.2 rendered as inline SVG.

  The icons ship inside the package (`priv/heroicons/heroicons.json`, MIT, by
  Tailwind Labs) in three styles: `"outline"` (24px, stroke), `"solid"` (24px)
  and `"mini"` (20px). Rendering them inline instead of with the `hero-*`
  classes of Phoenix's Tailwind plugin matters for a content editor: those
  classes only exist for the icon names Tailwind finds in your source files,
  while here the icon is picked at runtime.

      <ElementorexCms.Heroicons.icon name="gift" class="size-5" />
      <ElementorexCms.Heroicons.icon name="check-circle" style="solid" />
  """

  use Phoenix.Component

  @path Path.expand("../../priv/heroicons/heroicons.json", __DIR__)
  @external_resource @path

  @icons @path |> File.read!() |> Jason.decode!()
  @names @icons |> Map.fetch!("outline") |> Map.keys() |> Enum.sort()
  @styles ~w(outline solid mini)

  # Spanish words that point to icon names, so the picker finds "regalo" or
  # "flecha" in Spanish too.
  @synonyms %{
    "alerta" => ~w(exclamation-triangle exclamation-circle bell-alert),
    "auto" => ~w(truck),
    "ayuda" => ~w(question-mark-circle lifebuoy),
    "basura" => ~w(trash),
    "buscar" => ~w(magnifying-glass),
    "calendario" => ~w(calendar calendar-days),
    "campana" => ~w(bell),
    "carrito" => ~w(shopping-cart),
    "casa" => ~w(home home-modern),
    "check" => ~w(check check-circle check-badge),
    "chat" => ~w(chat-bubble-left-right chat-bubble-oval-left),
    "compartir" => ~w(share),
    "configuracion" => ~w(cog-6-tooth adjustments-horizontal),
    "corazon" => ~w(heart),
    "correo" => ~w(envelope),
    "descargar" => ~w(arrow-down-tray),
    "dinero" => ~w(banknotes currency-dollar),
    "documento" => ~w(document document-text),
    "editar" => ~w(pencil pencil-square),
    "escudo" => ~w(shield-check shield-exclamation),
    "estrella" => ~w(star sparkles),
    "fecha" => ~w(calendar),
    "flecha" => ~w(arrow-right arrow-left arrow-up arrow-down chevron-right),
    "fuego" => ~w(fire),
    "imagen" => ~w(photo),
    "info" => ~w(information-circle),
    "llamar" => ~w(phone),
    "mapa" => ~w(map map-pin),
    "mas" => ~w(plus plus-circle),
    "medico" => ~w(heart),
    "mensaje" => ~w(chat-bubble-left envelope),
    "ojo" => ~w(eye),
    "personas" => ~w(users user-group),
    "premio" => ~w(trophy gift),
    "regalo" => ~w(gift gift-top),
    "reloj" => ~w(clock),
    "salud" => ~w(heart),
    "seguro" => ~w(shield-check lock-closed),
    "subir" => ~w(arrow-up-tray),
    "tarjeta" => ~w(credit-card),
    "telefono" => ~w(phone device-phone-mobile),
    "tiempo" => ~w(clock),
    "ubicacion" => ~w(map-pin),
    "usuario" => ~w(user user-circle),
    "video" => ~w(video-camera play-circle)
  }

  @doc "Names of every icon (the same in the three styles)."
  @spec names() :: [String.t()]
  def names, do: @names

  @doc "Available styles: `\"outline\"`, `\"solid\"` and `\"mini\"`."
  @spec styles() :: [String.t()]
  def styles, do: @styles

  @doc "Whether an icon with that name exists."
  @spec exists?(term()) :: boolean()
  def exists?(name) when is_binary(name), do: Map.has_key?(icons()["outline"], name)
  def exists?(_name), do: false

  @doc """
  Icons whose name (or a Spanish synonym) contains `query`, up to `limit`.
  An empty query returns the first icons in alphabetical order.
  """
  @spec search(String.t() | nil, pos_integer()) :: [String.t()]
  def search(query, limit \\ 60)
  def search(nil, limit), do: Enum.take(@names, limit)

  def search(query, limit) do
    query = query |> String.trim() |> String.downcase() |> strip_accents()

    if query == "" do
      Enum.take(@names, limit)
    else
      from_synonyms =
        @synonyms
        |> Enum.filter(fn {word, _} -> String.starts_with?(word, query) end)
        |> Enum.flat_map(&elem(&1, 1))

      by_name = Enum.filter(@names, &String.contains?(&1, String.replace(query, " ", "-")))

      (from_synonyms ++ by_name)
      |> Enum.uniq()
      |> Enum.filter(&exists?/1)
      |> Enum.take(limit)
    end
  end

  defp strip_accents(text) do
    text
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
  end

  @doc """
  Renders an icon. Unknown names render nothing.

  ## Attributes

    * `name` - icon name, e.g. `"arrow-right"`
    * `style` - `"outline"` (default), `"solid"` or `"mini"`
    * `class` - classes for the `<svg>` (size it with `size-*` or CSS)
    * any other attribute is added to the `<svg>` (`aria-label`, `data-*`...)
  """
  attr :name, :string, required: true
  attr :style, :string, default: "outline"
  attr :class, :any, default: nil
  attr :rest, :global

  def icon(assigns) do
    assigns = assign(assigns, :inner, inner(assigns.name, assigns.style))

    ~H"""
    <svg
      :if={@inner}
      xmlns="http://www.w3.org/2000/svg"
      viewBox={viewbox(@style)}
      fill={if(@style == "outline", do: "none", else: "currentColor")}
      stroke={if(@style == "outline", do: "currentColor")}
      stroke-width={if(@style == "outline", do: "1.5")}
      aria-hidden={if(@rest[:"aria-label"], do: nil, else: "true")}
      data-slot="icon"
      class={@class}
      {@rest}
    >{Phoenix.HTML.raw(@inner)}</svg>
    """
  end

  @doc """
  The icon as an SVG string, for places that are not HEEx (the editor builds the
  canvas document as a string).
  """
  @spec svg(String.t(), String.t(), keyword()) :: String.t()
  def svg(name, style \\ "outline", opts \\ []) do
    case inner(name, style) do
      nil ->
        ""

      inner ->
        class = if c = opts[:class], do: ~s( class="#{c}"), else: ""

        paint =
          if style == "outline",
            do: ~s(fill="none" stroke="currentColor" stroke-width="1.5"),
            else: ~s(fill="currentColor")

        ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{viewbox(style)}" #{paint} aria-hidden="true"#{class}>#{inner}</svg>)
    end
  end

  defp inner(name, style) when is_binary(name) and style in @styles,
    do: get_in(icons(), [style, name])

  defp inner(name, _style) when not is_binary(name), do: nil
  defp inner(name, _style), do: inner(name, "outline")

  # The icon data is referenced from a single place so the literal is stored
  # once in the module.
  defp icons, do: @icons

  defp viewbox("mini"), do: "0 0 20 20"
  defp viewbox(_style), do: "0 0 24 24"
end
