defmodule ElementorexCms.CSSStyleTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.CSS
  alias ElementorexCms.Document
  alias ElementorexCms.Style

  doctest CSS
  doctest Style

  describe "CSS.value/2" do
    test "accepts the grammar of each property" do
      assert CSS.value("margin-top", "auto") == "auto"
      assert CSS.value("width", "50%") == "50%"
      assert CSS.value("line-height", "1.5") == "1.5"
      assert CSS.value("opacity", "0.4") == "0.4"
      assert CSS.value("color", "#fff") == "#fff"
      assert CSS.value("color", "oklch(70% 0.1 200)") == "oklch(70% 0.1 200)"
      assert CSS.value("background-color", "var(--color-base-200)") == "var(--color-base-200)"
      assert CSS.value("text-align", "center") == "center"
      assert CSS.value("box-shadow", "md") =~ "rgb"
      assert CSS.value("aspect-ratio", "16 / 9") == "16 / 9"
      assert CSS.value("background-image", "url(/a.png)") == ~s|url("/a.png")|

      assert CSS.value("background-image", "linear-gradient(90deg, #e23a7a, #f0603c 80%)") ==
               "linear-gradient(90deg, #e23a7a, #f0603c 80%)"
    end

    test "rejects anything else" do
      for {property, value} <- [
            {"color", "red;background:url(x)"},
            {"color", "expression(alert(1))"},
            {"width", "100px}"},
            {"opacity", "2"},
            {"text-align", "middle"},
            {"background-image", "url(javascript:alert(1))"},
            {"background-image", "url(data:image/png;base64,AAA)"},
            {"position", "fixed"},
            {"behavior", "url(a.htc)"},
            {"box-shadow", "0 0 0 red"}
          ] do
        assert CSS.value(property, value) == nil, "#{property}: #{value}"
      end
    end
  end

  describe "CSS.scope/2" do
    test "nests the CSS in the selector, replacing `selector`" do
      assert CSS.scope(
               "selector { color: red } selector a:hover { opacity: .5 }",
               ~s([data-ex-id="a"])
             ) ==
               ~s([data-ex-id="a"]{& { color: red } & a:hover { opacity: .5 }})
    end

    test "neutralizes dangerous parts" do
      css =
        CSS.scope(
          ~s|@import url(x.css); selector { background: url(javascript:x); } </style><script>|,
          "#a"
        )

      refute css =~ "@import"
      refute css =~ "javascript"
      refute css =~ "<"
    end

    test "drops CSS with unbalanced braces" do
      assert CSS.scope("} body { display:none } {", "#a") == ""
    end
  end

  describe "Style.css/2" do
    setup do
      node = %{
        "id" => "n1",
        "type" => "text",
        "props" => %{},
        "children" => [],
        "style" => %{
          "desktop" => %{"color" => "#111"},
          "tablet" => %{"font-size" => "18px"},
          "mobile" => %{"font-size" => "16px"},
          "hover" => %{"color" => "#e23a7a"}
        },
        "attrs" => %{
          "hide_on" => ["mobile"],
          "animation" => "fade-up",
          "css" => "selector { letter-spacing: 1px }"
        }
      }

      %{doc: Document.new([node])}
    end

    test "writes base, states, visibility, animation and custom CSS", %{doc: doc} do
      css = Style.css(doc)

      assert css =~ Style.base_css()
      assert css =~ ~s([data-ex-id="n1"]{color:#111})
      assert css =~ ~s([data-ex-id="n1"]:hover{color:#e23a7a})
      assert css =~ ~s/@media (max-width:1023.98px){[data-ex-id="n1"]{font-size:18px}}/
      assert css =~ ~s/@media (max-width:767.98px){[data-ex-id="n1"]{font-size:16px}}/
      assert css =~ ~s/@media (max-width:767.98px){[data-ex-id="n1"]{display:none!important}}/
      assert css =~ "@keyframes exr-fade-up"
      assert css =~ ~s([data-ex-id="n1"]{& { letter-spacing: 1px }})
    end

    test "dims hidden blocks on the canvas instead of removing them", %{doc: doc} do
      css = Style.css(doc, mode: :editor)
      refute css =~ "display:none"
      assert css =~ "opacity:.35"
    end

    test "node_css/1 leaves out the base stylesheet", %{doc: doc} do
      [node] = Document.root(doc)["children"]
      refute Style.node_css(node) =~ ".exr-rich"
    end
  end
end
