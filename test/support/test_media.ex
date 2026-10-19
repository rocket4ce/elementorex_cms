defmodule ElementorexCms.TestMedia do
  @moduledoc false
  @behaviour ElementorexCms.Media

  @impl true
  def store(upload, context) do
    send(context[:test_pid] || self(), {:stored, upload.filename})
    {:ok, %{url: "/uploads/#{upload.filename}"}}
  end

  @impl true
  def list(opts, _context) do
    [
      %{url: "/uploads/a.png", name: "a.png"},
      %{url: "/uploads/b.jpg", name: "b.jpg"}
    ]
    |> Enum.filter(&(opts[:search] in [nil, ""] or String.contains?(&1.name, opts[:search])))
  end
end
