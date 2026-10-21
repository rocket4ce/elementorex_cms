defmodule Example.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :slug, :string
      add :description, :text
      add :price, :decimal
      add :image_url, :string
      add :category, :string
      add :stock, :integer
      add :featured, :boolean, default: false, null: false
      add :published, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:products, [:slug])
  end
end
