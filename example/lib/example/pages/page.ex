defmodule Example.Pages.Page do
  @moduledoc """
  A page built with the visual editor (ElementorexCms). `body` is the document.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pages" do
    field :title, :string
    field :slug, :string
    field :body, ElementorexCms.Ecto.Document, default: ElementorexCms.Document.new()
    field :status, Ecto.Enum, values: [:draft, :published], default: :draft
    field :published_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :slug, :status])
    |> validate_required([:title])
    |> put_slug()
    |> validate_required([:slug])
    |> validate_format(:slug, ~r/\A[a-z0-9]+(-[a-z0-9]+)*\z/,
      message: "use lowercase letters, digits and hyphens"
    )
    |> unique_constraint(:slug)
    |> put_published_at()
  end

  @doc false
  def body_changeset(page, body), do: cast(page, %{body: body}, [:body])

  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :title)} do
      {slug, title} when slug in [nil, ""] and is_binary(title) ->
        put_change(changeset, :slug, slugify(title))

      _ ->
        changeset
    end
  end

  defp slugify(text) do
    text
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp put_published_at(changeset) do
    if get_change(changeset, :status) == :published,
      do: put_change(changeset, :published_at, DateTime.utc_now(:second)),
      else: changeset
  end
end
