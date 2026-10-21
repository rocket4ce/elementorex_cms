defmodule Example.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :price, :decimal
    field :image_url, :string
    field :category, :string
    field :stock, :integer
    field :featured, :boolean, default: false
    field :published, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :price,
      :image_url,
      :category,
      :stock,
      :featured,
      :published
    ])
    |> validate_required([:name])
    |> put_slug()
    |> validate_required([:slug, :price])
    |> validate_format(:slug, ~r/\A[a-z0-9]+(-[a-z0-9]+)*\z/,
      message: "use lowercase letters, digits and hyphens"
    )
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:stock, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end

  # The shop links to /shop/:slug: a product without a slug gets one from its name.
  defp put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :name)} do
      {slug, name} when slug in [nil, ""] and is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

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
end
