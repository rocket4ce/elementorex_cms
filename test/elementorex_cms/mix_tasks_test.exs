defmodule ElementorexCms.MixTasksTest do
  # Generators write files relative to the current directory, so they run in a
  # temporary one (not async).
  use ExUnit.Case, async: false

  setup do
    dir = Path.join(System.tmp_dir!(), "exr_gen_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      File.rm_rf!(dir)
    end)

    %{dir: dir}
  end

  defp in_dir(dir, fun), do: File.cd!(dir, fun)

  defp assert_valid_elixir(path) do
    source = File.read!(path)
    assert {:ok, _} = Code.string_to_quoted(source), "#{path} is not valid Elixir:\n#{source}"
    source
  end

  test "gen.block creates a compilable block and its test", %{dir: dir} do
    in_dir(dir, fn ->
      Mix.Tasks.Elementorex.Gen.Block.run(
        ~w(Marketing.HeroBanner --category layout --container --icon sparkles)
      )

      block = assert_valid_elixir("lib/elementorex_cms_web/blocks/marketing/hero_banner.ex")
      assert block =~ "defmodule ElementorexCmsWeb.Blocks.Marketing.HeroBanner do"
      assert block =~ ~s(type: "hero_banner")
      assert block =~ "container: true"
      assert block =~ "<.children node={@node} ctx={@ctx} />"

      test = assert_valid_elixir("test/elementorex_cms_web/blocks/marketing/hero_banner_test.exs")
      assert test =~ "HeroBannerTest"

      [{module, _}] = Code.compile_string(block)
      assert module.type() == "hero_banner"
      assert module.meta().container
    end)

    assert_received {:mix_shell, :info, [_]}
  end

  test "gen.block rejects bad names" do
    assert_raise Mix.Error, fn -> Mix.Tasks.Elementorex.Gen.Block.run(["not-a-module"]) end
  end

  test "gen.template creates a templates module", %{dir: dir} do
    in_dir(dir, fn ->
      Mix.Tasks.Elementorex.Gen.Template.run(["Marketing"])
      source = assert_valid_elixir("lib/elementorex_cms_web/editor_templates/marketing.ex")
      [{module, _}] = Code.compile_string(source)
      assert [%{key: "marketing_hero"} | _] = module.templates()
    end)
  end

  test "gen.cms creates the whole CMS", %{dir: dir} do
    in_dir(dir, fn ->
      Mix.Tasks.Elementorex.Gen.Cms.run(~w(Pages Page pages --binary-id))

      [migration] = Path.wildcard("priv/repo/migrations/*_create_pages.exs")
      assert assert_valid_elixir(migration) =~ "add :body, :map"

      schema = assert_valid_elixir("lib/elementorex_cms/pages/page.ex")
      assert schema =~ "field :body, ElementorexCms.Ecto.Document"
      assert schema =~ "@primary_key {:id, :binary_id, autogenerate: true}"

      assert assert_valid_elixir("lib/elementorex_cms/pages.ex") =~ "def update_page_body"

      for file <- ~w(index editor show) do
        assert_valid_elixir("lib/elementorex_cms_web/live/page_live/#{file}.ex")
        assert File.exists?("lib/elementorex_cms_web/live/page_live/#{file}.html.heex")
      end

      assert File.read!("lib/elementorex_cms_web/live/page_live/editor.html.heex") =~
               "module={ElementorexCms.Editor}"
    end)
  end

  test "install reports what is missing", %{dir: dir} do
    in_dir(dir, fn ->
      File.mkdir_p!("assets/js")
      File.write!("assets/js/app.js", ~s(import {hooks as Elementorex} from "elementorex_cms"\n))
      Mix.Tasks.Elementorex.Install.run([])
    end)

    messages = collect_messages()
    assert Enum.any?(messages, &(&1 =~ "✓" and &1 =~ "Editor hooks"))
    assert Enum.any?(messages, &(&1 =~ "✗" and &1 =~ "Tailwind scans the blocks"))
  end

  defp collect_messages(acc \\ []) do
    receive do
      {:mix_shell, :info, [message]} -> collect_messages([IO.iodata_to_binary(message) | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
