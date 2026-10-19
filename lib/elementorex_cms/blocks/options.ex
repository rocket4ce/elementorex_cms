defmodule ElementorexCms.Blocks.Options do
  @moduledoc """
  Option lists shared by the built-in blocks (labels are translated when shown).

  The class names that go with each option live in each block as literal
  strings, so Tailwind finds them when it scans the library.
  """

  @doc "daisyUI semantic colors."
  def colors do
    [
      {"Primary", "primary"},
      {"Secondary", "secondary"},
      {"Accent", "accent"},
      {"Neutral", "neutral"},
      {"Info", "info"},
      {"Success", "success"},
      {"Warning", "warning"},
      {"Error", "error"}
    ]
  end

  @doc "Colors plus `Default` (no color class)."
  def colors_with_default, do: [{"Default", "default"} | colors()]

  @doc "Text colors: inherit plus the semantic colors."
  def text_colors, do: [{"Inherit", "current"}, {"Base content", "base"} | colors()]

  @doc "daisyUI component sizes."
  def sizes do
    [{"XS", "xs"}, {"S", "sm"}, {"M", "md"}, {"L", "lg"}, {"XL", "xl"}]
  end

  @doc "Horizontal alignment."
  def alignments, do: [{"Left", "left"}, {"Center", "center"}, {"Right", "right"}]

  @doc "Spacing scale for gaps."
  def gaps do
    [
      {"None", "0"},
      {"XS", "1"},
      {"S", "2"},
      {"M", "4"},
      {"L", "6"},
      {"XL", "8"},
      {"2XL", "12"}
    ]
  end

  @doc "Border radius scale."
  def radii do
    [
      {"None", "none"},
      {"S", "sm"},
      {"M", "md"},
      {"L", "lg"},
      {"XL", "xl"},
      {"2XL", "2xl"},
      {"Box", "box"},
      {"Full", "full"}
    ]
  end

  @doc "Shadow scale."
  def shadows do
    [{"None", "none"}, {"S", "sm"}, {"M", "md"}, {"L", "lg"}, {"XL", "xl"}, {"2XL", "2xl"}]
  end

  @doc "Style of daisyUI buttons, badges and alerts."
  def variants do
    [
      {"Solid", "solid"},
      {"Soft", "soft"},
      {"Outline", "outline"},
      {"Dash", "dash"}
    ]
  end

  @doc "Heroicons styles."
  def icon_styles, do: [{"Outline", "outline"}, {"Solid", "solid"}, {"Mini", "mini"}]
end
