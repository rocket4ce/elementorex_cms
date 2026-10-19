defmodule ElementorexCms.HTML.SanitizerTest do
  use ExUnit.Case, async: true

  alias ElementorexCms.HTML.Sanitizer

  doctest Sanitizer

  @vectors [
    ~s|<script>alert(1)</script>|,
    ~s|<img src=x onerror=alert(1)>|,
    ~s|<a href="javascript:alert(1)">x</a>|,
    ~s|<a href="&#106;avascript:alert(1)">x</a>|,
    ~s|<a href="java\tscript:alert(1)">x</a>|,
    ~s|<a href=" JaVaScRiPt:alert(1)">x</a>|,
    ~s|<svg><script>alert(1)</script></svg>|,
    ~s|<iframe src="https://evil.example"></iframe>|,
    ~s|<p style="background:url(javascript:alert(1))">x</p>|,
    ~s|<p style="color:red;}</style><script>alert(1)</script>">x</p>|,
    ~s|<math><mi xlink:href="javascript:alert(1)">x</mi></math>|,
    ~s|<div onmouseover="alert(1)">x</div>|,
    ~s|<object data="x.swf"></object>|,
    ~s|<style>body{display:none}</style>|,
    ~s|<p phx-click="delete">x</p>|,
    ~s|<!--<script>alert(1)</script>-->|,
    ~s|<img src="data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=">|,
    ~s|<scr<script>ipt>alert(1)</script>|,
    ~s|<a href="vbscript:msgbox(1)">x</a>|,
    ~s|<form action="/x"><input name=y></form>|,
    ~s|<p title="a" title="b" onclick=x>z</p>|
  ]

  test "no vector survives under any policy" do
    for vector <- @vectors, policy <- [:inline, :rich, :html] do
      out = Sanitizer.sanitize(vector, policy)

      refute out =~ ~r/<script/i, "#{vector} → #{out}"
      refute out =~ ~r/javascript:/i, "#{vector} → #{out}"
      refute out =~ ~r/vbscript:/i, "#{vector} → #{out}"
      refute out =~ ~r/\son[a-z]+=/i, "#{vector} → #{out}"
      refute out =~ ~r/<(iframe|object|svg|math|style|form|input)/i, "#{vector} → #{out}"
      refute out =~ ~r/phx-/i, "#{vector} → #{out}"
      refute out =~ ~r/data:image/i, "#{vector} → #{out}"
    end
  end

  test "keeps allowed markup per policy" do
    html =
      ~s(<h2>Title</h2><p>Hello <strong>bold</strong> <a href="/x" target="_blank">link</a></p>)

    assert Sanitizer.sanitize(html, :rich) ==
             ~s(<h2>Title</h2><p>Hello <strong>bold</strong> <a href="/x" target="_blank" rel="noopener noreferrer">link</a></p>)

    assert Sanitizer.sanitize(html, :inline) ==
             ~s(TitleHello <strong>bold</strong> <a href="/x" target="_blank" rel="noopener noreferrer">link</a>)
  end

  test "the html policy keeps layout, images and safe styles" do
    html =
      ~s(<div class="p-4 bg-base-200" style="color: red; position: fixed"><img src="/a.png" alt="A" width="20"></div>)

    assert Sanitizer.sanitize(html, :html) ==
             ~s(<div class="p-4 bg-base-200" style="color: red"><img src="/a.png" alt="A" width="20"></div>)
  end

  test "closes unclosed tags and drops stray closing ones" do
    assert Sanitizer.sanitize("<p><b>x</p></i>") == "<p><b>x</b></p>"
    assert Sanitizer.sanitize("<ul><li>a<li>b") == "<ul><li>a<li>b</li></li></ul>"
  end

  test "escapes text and keeps entities" do
    assert Sanitizer.sanitize("a < b && c > d &amp; &nbsp;") ==
             "a &lt; b &amp;&amp; c &gt; d &amp; &nbsp;"
  end

  test "text/1 and text_to_html/1" do
    assert Sanitizer.text("<p>Hi <b>there</b></p><script>x</script>") == "Hi there"
    assert Sanitizer.text_to_html("<b>\nok") == "&lt;b&gt;<br>ok"
  end
end
