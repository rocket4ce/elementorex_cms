defmodule ElementorexCms.Blocks.FilterChoice do
  @moduledoc """
  Choice filter of a *Filters* form: the values of a field as a dropdown,
  radio buttons, checkboxes (several at once) or buttons. The options are the
  values the records have (`ElementorexCms.Source.values/3`, optionally with
  how many records have each) or a list written in the editor.
  """

  use ElementorexCms.Block,
    type: "filter_choice",
    label: "Choice filter",
    icon: "list-bullet",
    category: :dynamic,
    description: "A field's values as a dropdown, options, checkboxes or buttons",
    keywords: ~w(filter select category options checkboxes radio facet filtro categoria opciones),
    parents: ["filters"]

  alias ElementorexCms.Blocks.FilterField

  prop(:field, :field, label: "Field", only: :filterable)
  prop(:label, :string, label: "Label", help: "Empty: the name of the field")

  prop(:control, :select,
    label: "Show as",
    options: [
      {"Dropdown", "select"},
      {"Options", "radio"},
      {"Checkboxes", "checkboxes"},
      {"Buttons", "buttons"}
    ],
    default: "select"
  )

  prop(:options_from, :select,
    label: "Options",
    options: [{"The values of the field", "auto"}, {"Written here", "manual"}],
    default: "auto",
    control: :segmented
  )

  prop(:options, :list,
    label: "Options",
    item_label: :label,
    max_items: 30,
    default: [],
    fields: [{:label, :string, label: "Text"}, {:value, :string, label: "Value"}],
    show_if: {:options_from, "manual"}
  )

  prop(:all_label, :string,
    label: "Text of “all”",
    default: "All",
    show_if: {:control, ["select", "radio", "buttons"]}
  )

  prop(:show_counts, :boolean,
    label: "Show how many",
    default: false,
    show_if: {:options_from, "auto"}
  )

  def render(assigns) do
    if filter_form?(assigns) and assigns.field != "" do
      assigns =
        assign(assigns,
          title: FilterField.label(assigns, assigns.field),
          name: filter_name(assigns, assigns.field),
          many: filter_name(assigns, [assigns.field, ""]),
          choices: choices(assigns),
          none?: filter_value(assigns, assigns.field) in [nil, "", []]
        )

      ~H"""
      <fieldset {root(assigns, class: "flex min-w-40 flex-col gap-1")}>
        <legend :if={@title != ""} class="mb-1 text-sm font-medium">{@title}</legend>
        <%= case @control do %>
          <% "radio" -> %>
            <label class="flex cursor-pointer items-center gap-2">
              <input type="radio" class="radio radio-sm" name={@name} value="" checked={@none?} />
              <span>{@all_label}</span>
            </label>
            <label :for={choice <- @choices} class="flex cursor-pointer items-center gap-2">
              <input
                type="radio"
                class="radio radio-sm"
                name={@name}
                value={choice.value}
                checked={filter_checked?(assigns, @field, choice.value)}
              />
              <span>{choice.label}</span>
              <span :if={choice.count} class="text-xs opacity-60">({choice.count})</span>
            </label>
          <% "checkboxes" -> %>
            <label :for={choice <- @choices} class="flex cursor-pointer items-center gap-2">
              <input
                type="checkbox"
                class="checkbox checkbox-sm"
                name={@many}
                value={choice.value}
                checked={filter_checked?(assigns, @field, choice.value)}
              />
              <span>{choice.label}</span>
              <span :if={choice.count} class="text-xs opacity-60">({choice.count})</span>
            </label>
          <% "buttons" -> %>
            <div class="join flex-wrap">
              <input
                type="radio"
                class="join-item btn btn-sm"
                name={@name}
                value=""
                aria-label={@all_label}
                checked={@none?}
              />
              <input
                :for={choice <- @choices}
                type="radio"
                class="join-item btn btn-sm"
                name={@name}
                value={choice.value}
                aria-label={
                  if(choice.count, do: "#{choice.label} (#{choice.count})", else: choice.label)
                }
                checked={filter_checked?(assigns, @field, choice.value)}
              />
            </div>
          <% _select -> %>
            <select class="select w-full" name={@name}>
              <option value="">{@all_label}</option>
              <option
                :for={choice <- @choices}
                value={choice.value}
                selected={filter_checked?(assigns, @field, choice.value)}
              >
                {choice.label}{if(choice.count, do: " (#{choice.count})")}
              </option>
            </select>
        <% end %>
      </fieldset>
      """
    else
      FilterField.outside(%{assigns: assigns, __changed__: nil})
    end
  end

  defp choices(%{options_from: "manual", options: options}) do
    for %{"value" => value} = option <- options, value != "" do
      label = if option["label"] in [nil, ""], do: value, else: option["label"]
      %{label: label, value: value, count: nil}
    end
  end

  defp choices(assigns) do
    assigns
    |> filter_options(assigns.field)
    |> Enum.map(fn option -> if assigns.show_counts, do: option, else: %{option | count: nil} end)
  end
end
