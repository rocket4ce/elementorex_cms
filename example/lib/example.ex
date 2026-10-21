defmodule Example do
  @moduledoc """
  Example keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @doc """
  Data of the site passed to the blocks as `@ctx.data`, in the editor and on
  the public pages (see `ExampleWeb.Blocks.Whatsapp`).
  """
  def site_data, do: %{whatsapp: "+56 9 8765 4321", site_name: "Example"}
end
