defmodule ElementorexCms.TestTag do
  @moduledoc false
  # No primary key (a view, a join table…).
  use Ecto.Schema

  @primary_key false
  schema "tags" do
    field :name, :string
  end
end
