defmodule ElementorexCms.TemplatesTest do
  use ExUnit.Case, async: true

  import ElementorexCms.Builder

  alias ElementorexCms.{Registry, Templates}

  defmodule Mine do
    @behaviour ElementorexCms.Templates

    @impl true
    def templates do
      [
        %{
          key: "intro",
          label: "Intro",
          nodes: fn -> [section([block("heading"), block("text")])] end
        },
        %{key: "promo", label: "Promo", nodes: fn -> [section([block("countdown")])] end}
      ]
    end
  end

  test "usable/2 leaves out templates with blocks the registry doesn't have" do
    registry = Registry.new(only: ~w(section heading text))
    keys = Templates.all([Mine]) |> Templates.usable(registry) |> Enum.map(& &1.key)

    assert "intro" in keys
    refute "promo" in keys
    # Built-in templates use blocks this registry lacks
    refute Enum.any?(Templates.builtin(), &(&1.key in keys))
  end

  test "usable/2 keeps every template with the full registry" do
    all = Templates.all([Mine])
    assert Templates.usable(all, Registry.default()) == all
    assert Templates.usable(all, nil) == all
  end
end
