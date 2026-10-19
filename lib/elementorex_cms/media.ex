defmodule ElementorexCms.Media do
  @moduledoc """
  Behaviour to connect the editor's image fields to your file storage.

  Without a media module, image fields take a URL. With one, they also offer
  *Upload* (LiveView uploads, stored by `store/2`) and *Library* (a grid of
  existing files from `list/2`).

      defmodule MyApp.EditorMedia do
        @behaviour ElementorexCms.Media

        @impl true
        def store(%{path: path, filename: filename, content_type: type}, %{user_id: user_id}) do
          with {:ok, file} <- MyApp.Files.upload(path, filename, type, user_id) do
            {:ok, %{url: file.url, alt: file.alt}}
          end
        end

        @impl true
        def list(opts, _context) do
          MyApp.Files.list_images(search: opts[:search], limit: 40)
          |> Enum.map(&%{url: &1.url, thumb: &1.url, alt: &1.alt, name: &1.filename})
        end
      end

      <.live_component module={ElementorexCms.Editor} id="editor" media={MyApp.EditorMedia}
        media_context={%{user_id: @current_scope.user.id}} ... />
  """

  @typedoc "An uploaded file: its temporary path, the client's file name and the content type."
  @type upload :: %{
          path: String.t(),
          filename: String.t(),
          content_type: String.t() | nil,
          size: non_neg_integer()
        }

  @typedoc "A file of the library."
  @type item :: %{
          required(:url) => String.t(),
          optional(:thumb) => String.t(),
          optional(:alt) => String.t(),
          optional(:name) => String.t()
        }

  @doc "Stores an uploaded image and returns its public URL."
  @callback store(upload(), context :: map()) ::
              {:ok, %{required(:url) => String.t(), optional(:alt) => String.t()}}
              | {:error, term()}

  @doc "Lists library images. `opts` has `:search` (may be `nil`)."
  @callback list(opts :: keyword(), context :: map()) :: [item()]

  @optional_callbacks list: 2
end
