defmodule Example.Repo.Migrations.AddSourceToPages do
  use Ecto.Migration

  # A page with a source is the template of the pages of its records (the page
  # of each product), made in the visual editor.
  def change do
    alter table(:pages) do
      add :source, :string
    end

    create index(:pages, [:source])
  end
end
