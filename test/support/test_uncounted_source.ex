defmodule ElementorexCms.TestUncountedSource do
  @moduledoc false
  # The products of TestSource from a source that cannot count them (no
  # count/2): numbered pages fall back to previous and next.
  @behaviour ElementorexCms.Source

  alias ElementorexCms.TestSource

  @impl true
  def key, do: "uncounted"

  @impl true
  def label, do: "Uncounted"

  @impl true
  def fields, do: TestSource.fields()

  @impl true
  def list(query, context), do: TestSource.list(query, context)
end
