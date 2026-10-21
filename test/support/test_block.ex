defmodule ElementorexCms.TestBlock do
  @moduledoc false
  # An app block for the I18n tests and the locale generator.

  use ElementorexCms.Block,
    type: "test_pricing",
    label: "Pricing plan",
    icon: "currency-dollar",
    category: :sales,
    description: "A plan and its price"

  prop :plan, :string, label: "Plan name", default: "Pro"
  prop :url, :url, label: "Link", default: "https://example.com"

  prop :period, :select,
    label: "Billing period",
    options: [{"Monthly", "month"}, {"Yearly", "year"}],
    default: "month"

  prop :features, :list,
    label: "Features",
    default: [%{"text" => "Unlimited pages"}],
    fields: [{:text, :string, label: "Feature", default: "Feature"}]

  def render(assigns) do
    ~H"""
    <div {root(assigns)}>{@plan} {t("Billing period")}</div>
    """
  end
end
