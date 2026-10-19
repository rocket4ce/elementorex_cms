defmodule ElementorexCms.PropURLI18nTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.Block.Prop
  alias ElementorexCms.I18n
  alias ElementorexCms.URL

  doctest URL

  describe "Prop.cast/2" do
    test "text types" do
      assert Prop.cast(Prop.new(:t, :string), "a\nb\tc") == "a b c"
      assert Prop.cast(Prop.new(:t, :string, max_length: 3), "abcdef") == "abc"
      assert Prop.cast(Prop.new(:t, :text), "a\r\nb") == "a\nb"

      assert Prop.cast(Prop.new(:t, :richtext), "<p onclick=x>a<script>b</script></p>") ==
               "<p>a</p>"

      assert Prop.cast(Prop.new(:t, :richtext, policy: :inline), "<p>a <b>b</b></p>") ==
               "a <b>b</b>"
    end

    test "choices and numbers" do
      select = Prop.new(:s, :select, options: [{"Small", "sm"}, {"Large", "lg"}], default: "sm")
      assert Prop.cast(select, "lg") == "lg"
      assert Prop.cast(select, "xl") == "sm"
      assert Prop.cast(Prop.new(:b, :boolean, default: true), "false") == false
      assert Prop.cast(Prop.new(:b, :boolean, default: true), "garbage") == true
      assert Prop.cast(Prop.new(:n, :integer, min: 0, max: 10), "42") == 10
      assert Prop.cast(Prop.new(:n, :number, min: 0, max: 5), "2,5") == 2.5
      assert Prop.cast(Prop.new(:n, :integer, default: 3), "x") == 3
    end

    test "links, images, icons, colors and dates" do
      assert Prop.cast(Prop.new(:u, :url), "javascript:alert(1)") == ""
      assert Prop.cast(Prop.new(:u, :url), "mailto:a@b.cl") == "mailto:a@b.cl"
      assert Prop.cast(Prop.new(:i, :image), "data:image/png;base64,AA") == ""
      assert Prop.cast(Prop.new(:i, :icon, default: "star"), "gift") == "gift"
      assert Prop.cast(Prop.new(:i, :icon, default: "star"), "not-an-icon") == "star"
      assert Prop.cast(Prop.new(:c, :color), "red;}") == ""

      assert Prop.cast(Prop.new(:d, :datetime, default: "2030-01-01T00:00"), "2026-12-31T23:59") ==
               "2026-12-31T23:59"

      assert Prop.cast(Prop.new(:d, :datetime, default: "2030-01-01T00:00"), "tomorrow") ==
               "2030-01-01T00:00"
    end

    test "lists cast each item, keep ids and accept form maps" do
      list =
        Prop.new(:items, :list,
          max_items: 2,
          fields: [{:title, :string, default: "Item"}, {:done, :boolean}]
        )

      [first, second] =
        Prop.cast(list, %{
          "1" => %{"title" => "B"},
          "0" => %{"id" => "keep1", "title" => "A", "done" => "true"},
          "2" => %{}
        })

      assert first == %{"id" => "keep1", "title" => "A", "done" => true}
      assert second["title"] == "B"
      assert second["id"] =~ ~r/\A[A-Za-z0-9]{10}\z/
      assert Prop.cast(list, "nope") == []
    end

    test "visible?/2 follows show_if" do
      prop = Prop.new(:p, :string, show_if: {:icon, :present})
      assert Prop.visible?(prop, %{icon: "gift"})
      refute Prop.visible?(prop, %{icon: ""})
      assert Prop.visible?(Prop.new(:p, :string, show_if: {:kind, ["a", "b"]}), %{kind: "b"})
    end

    test "unknown types raise" do
      assert_raise ArgumentError, fn -> Prop.new(:x, :weird) end
    end
  end

  describe "URL" do
    test "video embeds keep only the id" do
      assert URL.video_embed("https://youtu.be/dQw4w9WgXcQ?t=3") ==
               {:youtube, "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ"}

      assert URL.video_embed("https://evil.example/watch?v=dQw4w9WgXcQ") == nil
    end

    test "rejects whitespace tricks and keeps relative URLs" do
      assert URL.sanitize("java\nscript:alert(1)") == nil
      assert URL.sanitize("  /a b ") == "/a%20b"
      assert URL.sanitize("#contacto") == "#contacto"
      assert URL.sanitize_media("https://x.cl/a.png") == "https://x.cl/a.png"
      assert URL.sanitize_media("mailto:a@b.cl") == nil
    end
  end

  describe "I18n" do
    test "translates per process locale with interpolation" do
      I18n.put_locale("es")
      assert I18n.t("Button") == "Botón"
      assert I18n.t("Drop: %{block}", block: "Alerta") == "Soltar: Alerta"
      assert I18n.t("Not in the dictionary") == "Not in the dictionary"
      I18n.put_locale("en")
      assert I18n.t("Button") == "Button"
    end

    test "configured translations win" do
      Application.put_env(:elementorex_cms, :translations, %{"es" => %{"Button" => "Botoncito"}})
      I18n.put_locale("es")
      assert I18n.t("Button") == "Botoncito"
    after
      Application.delete_env(:elementorex_cms, :translations)
      I18n.put_locale(nil)
    end

    test "new blocks start with texts in the editor's language" do
      I18n.put_locale("es")

      heading =
        ElementorexCms.Document.node("heading", %{}, registry: ElementorexCms.Registry.default())

      assert heading["props"]["text"] == "Escribe tu título"
      I18n.put_locale(nil)
    end
  end
end
