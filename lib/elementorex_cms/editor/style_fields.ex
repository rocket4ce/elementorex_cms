defmodule ElementorexCms.Editor.StyleFields do
  @moduledoc false
  # Sections and fields of the inspector's Style tab. Each field edits one CSS
  # property (or a group of four for sides and corners) of the selected node,
  # for the current device or for :hover.

  @weights [
    {"Default", ""},
    {"Thin", "100"},
    {"Light", "300"},
    {"Normal", "400"},
    {"Medium", "500"},
    {"Semibold", "600"},
    {"Bold", "700"},
    {"Extra bold", "800"},
    {"Black", "900"}
  ]

  @doc "Groups of four properties edited together (linked) or one by one."
  def groups do
    %{
      "margin" => ~w(margin-top margin-right margin-bottom margin-left),
      "padding" => ~w(padding-top padding-right padding-bottom padding-left),
      "border-width" =>
        ~w(border-top-width border-right-width border-bottom-width border-left-width),
      "border-radius" =>
        ~w(border-top-left-radius border-top-right-radius border-bottom-right-radius border-bottom-left-radius)
    }
  end

  @doc "Properties whose plain numbers mean pixels (`24` → `24px`)."
  def pixel_properties do
    ~w(font-size letter-spacing width min-width max-width height min-height max-height gap row-gap
       column-gap flex-basis) ++ (groups() |> Map.values() |> List.flatten())
  end

  @doc "Properties offered for the :hover state."
  def hover_properties, do: ~w(color background-color border-color box-shadow opacity)

  @doc "The sections of the Style tab."
  def sections do
    [
      %{
        key: "typography",
        label: "Typography",
        icon: "language",
        fields: [
          %{property: "font-size", label: "Size", control: :length, placeholder: "16px"},
          %{property: "font-weight", label: "Weight", control: :select, options: @weights},
          %{property: "line-height", label: "Line height", control: :length, placeholder: "1.5"},
          %{
            property: "letter-spacing",
            label: "Letter spacing",
            control: :length,
            placeholder: "0px"
          },
          %{
            property: "text-align",
            label: "Alignment",
            control: :icons,
            options: [
              {"Left", "left", "bars-3-bottom-left"},
              {"Center", "center", "bars-3"},
              {"Right", "right", "bars-3-bottom-right"},
              {"Justify", "justify", "bars-4"}
            ]
          },
          %{
            property: "text-transform",
            label: "Transform",
            control: :segmented,
            options: [
              {"Aa", "none"},
              {"AA", "uppercase"},
              {"aa", "lowercase"},
              {"Ab", "capitalize"}
            ]
          },
          %{
            property: "font-style",
            label: "Style",
            control: :segmented,
            options: [{"Normal", "normal"}, {"Italic", "italic"}]
          },
          %{
            property: "text-decoration-line",
            label: "Decoration",
            control: :select,
            options: [
              {"Default", ""},
              {"None", "none"},
              {"Underline", "underline"},
              {"Line through", "line-through"}
            ]
          },
          %{property: "color", label: "Text color", control: :color}
        ]
      },
      %{
        key: "spacing",
        label: "Spacing",
        icon: "arrows-pointing-out",
        fields: [
          %{property: "margin", label: "Margin", control: :sides},
          %{property: "padding", label: "Padding", control: :sides}
        ]
      },
      %{
        key: "size",
        label: "Size",
        icon: "arrows-right-left",
        fields: [
          %{property: "width", label: "Width", control: :length, placeholder: "auto"},
          %{property: "max-width", label: "Max width", control: :length, placeholder: "none"},
          %{property: "height", label: "Height", control: :length, placeholder: "auto"},
          %{property: "min-height", label: "Min height", control: :length, placeholder: "0"},
          %{
            property: "aspect-ratio",
            label: "Aspect ratio",
            control: :select,
            options: [
              {"Auto", ""},
              {"1:1", "1 / 1"},
              {"16:9", "16 / 9"},
              {"4:3", "4 / 3"},
              {"3:4", "3 / 4"}
            ]
          },
          %{
            property: "overflow",
            label: "Overflow",
            control: :segmented,
            options: [{"Visible", "visible"}, {"Hidden", "hidden"}, {"Auto", "auto"}]
          }
        ]
      },
      %{
        key: "background",
        label: "Background",
        icon: "paint-brush",
        fields: [
          %{property: "background-color", label: "Color", control: :color},
          %{property: "background-image", label: "Image", control: :background_image},
          %{
            property: "background-size",
            label: "Size",
            control: :segmented,
            options: [{"Auto", "auto"}, {"Cover", "cover"}, {"Contain", "contain"}]
          },
          %{
            property: "background-position",
            label: "Position",
            control: :select,
            options: [
              {"Default", ""},
              {"Center", "center"},
              {"Top", "top"},
              {"Bottom", "bottom"},
              {"Left", "left"},
              {"Right", "right"}
            ]
          },
          %{
            property: "background-repeat",
            label: "Repeat",
            control: :select,
            options: [
              {"Default", ""},
              {"No repeat", "no-repeat"},
              {"Repeat", "repeat"},
              {"Horizontally", "repeat-x"},
              {"Vertically", "repeat-y"}
            ]
          }
        ]
      },
      %{
        key: "border",
        label: "Border",
        icon: "stop",
        fields: [
          %{
            property: "border-style",
            label: "Style",
            control: :select,
            options: [
              {"Default", ""},
              {"None", "none"},
              {"Solid", "solid"},
              {"Dashed", "dashed"},
              {"Dotted", "dotted"},
              {"Double", "double"}
            ]
          },
          %{property: "border-width", label: "Width", control: :sides},
          %{property: "border-color", label: "Color", control: :color},
          %{property: "border-radius", label: "Radius", control: :corners}
        ]
      },
      %{
        key: "effects",
        label: "Effects",
        icon: "sparkles",
        fields: [
          %{
            property: "box-shadow",
            label: "Shadow",
            control: :segmented,
            options: [
              {"–", "none"},
              {"S", "sm"},
              {"M", "md"},
              {"L", "lg"},
              {"XL", "xl"},
              {"2XL", "2xl"}
            ]
          },
          %{property: "opacity", label: "Opacity", control: :range, min: 0, max: 1, step: 0.05}
        ]
      },
      %{
        key: "flex",
        label: "Position in its container",
        icon: "adjustments-horizontal",
        fields: [
          %{
            property: "align-self",
            label: "Align self",
            control: :select,
            options: [
              {"Default", ""},
              {"Start", "flex-start"},
              {"Center", "center"},
              {"End", "flex-end"},
              {"Stretch", "stretch"}
            ]
          },
          %{property: "flex-grow", label: "Grow", control: :number, min: 0, max: 20, step: 1},
          %{property: "order", label: "Order", control: :number, min: -100, max: 100, step: 1}
        ]
      }
    ]
  end
end
