defmodule ElementorexCms.TestCategory do
  @moduledoc false
  use Ecto.Schema

  schema "categories" do
    field :name, :string
    field :secret_token, :string
  end
end
