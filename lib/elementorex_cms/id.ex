defmodule ElementorexCms.Id do
  @moduledoc """
  Identifiers of document nodes.

  Ids are short random strings (`"Kq2b7Rt9Lm"`) that stay stable for the life of
  a node: the CSS of a node is scoped to its id (`[data-ex-id="Kq2b7Rt9Lm"]`) and
  the editor selects and moves nodes by id.
  """

  @alphabet ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            |> List.to_tuple()

  @length 10

  @doc "A new random id."
  @spec generate() :: String.t()
  def generate do
    for <<byte <- :crypto.strong_rand_bytes(@length)>>, into: "" do
      <<elem(@alphabet, rem(byte, 62))>>
    end
  end

  @doc """
  Whether `id` can be used as a node id: 1 to 40 letters, digits, `-` or `_`.
  Anything else could break out of the attribute selectors the CSS uses.
  """
  @spec valid?(term()) :: boolean()
  def valid?(id) when is_binary(id), do: id =~ ~r/\A[A-Za-z0-9_-]{1,40}\z/
  def valid?(_id), do: false
end
