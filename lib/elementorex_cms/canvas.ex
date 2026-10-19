defmodule ElementorexCms.Canvas do
  @moduledoc """
  How the editor canvas looks: the stylesheets of your site, the attributes of
  `<html>` and `<body>` and an optional frame around the content.

  The canvas is an `<iframe>` built from this configuration, so the content is
  rendered with your site's CSS and not the admin's, and the tablet and mobile
  widths trigger your media queries for real.

      ElementorexCms.Canvas.new(
        stylesheets: ["/assets/css/app.css"],
        html_attrs: %{"data-theme" => "light"},
        body_class: "bg-base-200 p-8",
        # the content goes where the frame has `data-exr-mount`
        frame: ~s(<main class="mx-auto max-w-3xl rounded-box bg-base-100 p-6" data-exr-mount></main>)
      )

  ## Options

    * `:stylesheets` - URLs of the CSS files (same origin or allowed by your
      Content-Security-Policy)
    * `:head` - extra HTML for `<head>` (fonts...)
    * `:html_attrs` - attributes of `<html>` (`data-theme` for daisyUI)
    * `:body_class` - classes of `<body>`
    * `:frame` - HTML around the content, with an element carrying
      `data-exr-mount` where the document goes (default: just that element).
      It can be a string or anything `Phoenix.HTML.Safe` (a rendered component)
    * `:widths` - canvas width per device, default
      `%{"desktop" => 1280, "tablet" => 768, "mobile" => 390}`
  """

  defstruct stylesheets: [],
            head: "",
            html_attrs: %{},
            body_class: "",
            frame: nil,
            widths: %{"desktop" => 1280, "tablet" => 768, "mobile" => 390}

  @type t :: %__MODULE__{}

  @default_frame ~s(<div data-exr-mount style="min-height:100vh"></div>)

  @doc "Builds a canvas configuration (see the module docs)."
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      stylesheets: Keyword.get(opts, :stylesheets, []),
      head: opts |> Keyword.get(:head, "") |> to_html(),
      html_attrs:
        Map.new(Keyword.get(opts, :html_attrs, %{}), fn {k, v} -> {to_string(k), to_string(v)} end),
      body_class: Keyword.get(opts, :body_class, ""),
      frame: opts |> Keyword.get(:frame) |> to_html(),
      widths: Map.merge(%__MODULE__{}.widths, Keyword.get(opts, :widths, %{}))
    }
  end

  @doc false
  def to_html(nil), do: nil
  def to_html(html) when is_binary(html), do: html
  def to_html(safe), do: safe |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

  @doc false
  # The configuration as JSON for the editor hook.
  def to_json(%__MODULE__{} = canvas) do
    frame = canvas.frame || @default_frame

    frame =
      if String.contains?(frame, "data-exr-mount"), do: frame, else: frame <> @default_frame

    Jason.encode!(%{
      stylesheets: canvas.stylesheets,
      head: canvas.head,
      htmlAttrs: canvas.html_attrs,
      bodyClass: canvas.body_class,
      frame: frame,
      widths: canvas.widths
    })
  end

  def to_json(nil), do: to_json(new())
end
