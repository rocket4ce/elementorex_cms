if Code.ensure_loaded?(Ecto.Type) do
  defmodule ElementorexCms.Ecto.Document do
    @moduledoc """
    Ecto type for documents, stored as a map (`jsonb` in PostgreSQL).

        schema "pages" do
          field :body, ElementorexCms.Ecto.Document, default: ElementorexCms.Document.new()
        end

    Casting accepts a map or a JSON string and normalizes it with the default
    registry (see `ElementorexCms.Document.normalize/2`), so whatever reaches the
    database is a valid, sanitized document.
    """

    use Ecto.Type

    alias ElementorexCms.Document

    @impl true
    def type, do: :map

    @impl true
    def cast(nil), do: {:ok, nil}
    def cast(json) when is_binary(json), do: {:ok, Document.normalize(json)}
    def cast(%{} = doc), do: {:ok, Document.normalize(doc)}
    def cast(_other), do: :error

    @impl true
    def load(nil), do: {:ok, nil}
    def load(%{} = doc), do: {:ok, doc}
    def load(_other), do: :error

    @impl true
    def dump(nil), do: {:ok, nil}
    def dump(%{} = doc), do: {:ok, doc}
    def dump(_other), do: :error

    @impl true
    def embed_as(_format), do: :dump

    @impl true
    def equal?(a, b), do: a == b
  end
end
