defmodule ElementorexCms.TestProduct do
  @moduledoc false
  # A schema for the Ecto source tests (no database: see TestRepo).
  use Ecto.Schema

  schema "products" do
    field :name, :string
    field :slug, :string
    field :price, :decimal
    field :image_url, :string
    field :description, :string
    field :body_html, :string
    field :stock, :integer
    field :featured, :boolean, default: false
    field :status, Ecto.Enum, values: [:draft, :published]
    field :released_on, :date
    field :tags, {:array, :string}
    field :meta, :map
    field :password_hash, :string
    field :api_token, :string, redact: true
    belongs_to :category, ElementorexCms.TestCategory

    timestamps type: :utc_datetime
  end
end
