defmodule ElementorexCms.TestPost do
  @moduledoc false
  # UUID keys, like apps generated with `binary_id: true`.
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "posts" do
    field :title, :string
  end
end
