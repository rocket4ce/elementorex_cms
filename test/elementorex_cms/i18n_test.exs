defmodule ElementorexCms.I18nTest do
  # Changes the application env (locales, translations), so not async.
  use ExUnit.Case, async: false

  alias ElementorexCms.I18n

  doctest I18n

  setup do
    on_exit(fn ->
      I18n.put_locale(nil)
      Application.delete_env(:elementorex_cms, :locales)
      Application.delete_env(:elementorex_cms, :translations)
    end)
  end

  describe "built-in dictionaries" do
    test "English is the default" do
      assert I18n.locale() == "en"
      assert I18n.t("Save") == "Save"
    end

    test "every language translates every string of the library" do
      keys = I18n.source_strings()

      for module <- I18n.builtin() do
        dictionary = module.dictionary()
        assert Map.keys(dictionary) |> Enum.sort() == keys, "#{module.locale()} differs"
        assert Enum.all?(dictionary, fn {_k, v} -> is_binary(v) and v != "" end)
      end
    end

    test "placeholders and HTML tags survive the translation" do
      placeholders = &(Regex.scan(~r/%\{\w+\}/, &1) |> List.flatten() |> Enum.sort())
      tags = &(Regex.scan(~r/<\/?[a-z]+/, &1) |> List.flatten() |> Enum.sort())

      for module <- I18n.builtin(), {key, value} <- module.dictionary() do
        assert placeholders.(key) == placeholders.(value), "#{module.locale()}: #{key}"
        assert tags.(key) == tags.(value), "#{module.locale()}: #{key}"
      end
    end

    test "languages and their names" do
      assert I18n.locales() == ~w(en es pt de fr it ja)

      assert I18n.languages() == [
               {"en", "English"},
               {"es", "Español"},
               {"pt", "Português"},
               {"de", "Deutsch"},
               {"fr", "Français"},
               {"it", "Italiano"},
               {"ja", "日本語"}
             ]
    end

    test "translates in each language" do
      for {locale, save} <- [
            {"es", "Guardar"},
            {"pt", "Salvar"},
            {"de", "Speichern"},
            {"fr", "Enregistrer"},
            {"it", "Salva"},
            {"ja", "保存"}
          ] do
        assert I18n.with_locale(locale, fn -> I18n.t("Save") end) == save
      end
    end

    test "regional codes fall back to their language" do
      assert I18n.with_locale("pt-BR", fn -> I18n.t("Save") end) == "Salvar"
      assert I18n.with_locale("fr_CA", fn -> I18n.t("Save") end) == "Enregistrer"
      assert I18n.with_locale("ko", fn -> I18n.t("Save") end) == "Save"
    end

    test "with_locale restores the previous locale" do
      I18n.put_locale("es")
      assert I18n.with_locale("ja", fn -> I18n.locale() end) == "ja"
      assert I18n.locale() == "es"
      assert I18n.with_locale(nil, fn -> I18n.locale() end) == "es"
    end
  end

  describe "locale modules of the app" do
    defmodule Pt do
      use ElementorexCms.I18n.Locale, locale: "pt", name: "Português"

      def dictionary,
        do: %{"Pricing plan" => "Plano", "Save" => "Gravar", "Billing period" => nil}
    end

    defmodule Ko do
      use ElementorexCms.I18n.Locale, locale: "ko", name: "한국어"
      def dictionary, do: %{"Save" => "저장"}
    end

    test "add strings and override the built-in ones" do
      Application.put_env(:elementorex_cms, :locales, [Pt])
      I18n.put_locale("pt")

      assert I18n.t("Pricing plan") == "Plano"
      assert I18n.t("Save") == "Gravar"
      assert I18n.t("Undo") == "Desfazer"
      assert I18n.t("Billing period") == "Billing period"
    end

    test "a regional variant builds on its language" do
      defmodule PtBr do
        use ElementorexCms.I18n.Locale, locale: "pt-BR", name: "Português (Brasil)"
        def dictionary, do: %{"Save" => "Salvar já"}
      end

      Application.put_env(:elementorex_cms, :locales, [PtBr])
      I18n.put_locale("pt-BR")

      assert I18n.t("Save") == "Salvar já"
      assert I18n.t("Undo") == "Desfazer"
      assert I18n.with_locale("pt", fn -> I18n.t("Save") end) == "Salvar"
    end

    test "add a new language" do
      Application.put_env(:elementorex_cms, :locales, [Ko])

      assert "ko" in I18n.locales()
      assert {"ko", "한국어"} in I18n.languages()
      assert I18n.with_locale("ko", fn -> I18n.t("Save") end) == "저장"
      assert I18n.with_locale("ko", fn -> I18n.t("Undo") end) == "Undo"
    end

    test "locale modules that don't exist yet are skipped (before gen.locale creates them)" do
      Application.put_env(:elementorex_cms, :locales, [MyApp.NotGeneratedYet, Ko])

      assert {"ko", "한국어"} in I18n.languages()
      assert I18n.with_locale("ko", fn -> I18n.t("Save") end) == "저장"
    end

    test "the :translations config wins and dictionary/1 merges everything" do
      Application.put_env(:elementorex_cms, :locales, [Pt])
      Application.put_env(:elementorex_cms, :translations, %{"pt" => %{"Save" => "Guardar já"}})

      dictionary = I18n.dictionary("pt")
      assert dictionary["Save"] == "Guardar já"
      assert dictionary["Pricing plan"] == "Plano"
      assert dictionary["Undo"] == "Desfazer"
      refute Map.has_key?(dictionary, "Billing period")
    end
  end

  test "strings of blocks and templates" do
    strings = I18n.strings([ElementorexCms.TestBlock, ElementorexCms.Templates])

    for text <-
          ["Pricing plan", "A plan and its price", "Sales", "Plan name", "Pro", "Billing period"] ++
            ["Monthly", "Features", "Feature", "Unlimited pages"] do
      assert text in strings
    end

    refute "https://example.com" in strings
    refute "month" in strings
  end

  describe "rendering in a language" do
    setup do
      doc = ElementorexCms.Builder.doc([ElementorexCms.Builder.block("countdown")])
      %{doc: doc}
    end

    test "to_html/2 takes a locale", %{doc: doc} do
      assert ElementorexCms.to_html(doc, locale: "de") =~ "Tage"
      assert ElementorexCms.to_html(doc) =~ "days"
      assert I18n.locale() == "en"
    end

    test "the document component takes a locale", %{doc: doc} do
      html =
        Phoenix.LiveViewTest.rendered_to_string(
          ElementorexCms.Components.document(%{document: doc, locale: "ja", __changed__: nil})
        )

      assert html =~ I18n.with_locale("ja", fn -> I18n.t("days") end)
      assert html =~ "data-ex-countdown"
    end
  end
end
