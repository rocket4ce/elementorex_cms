defmodule ElementorexCms.TestRepo do
  @moduledoc false
  # Records nothing: sends the queries it gets to the calling process and
  # returns what the test put in the process dictionary.
  def all(query) do
    send(self(), {:repo_all, query})
    Process.get(:test_repo_records, [])
  end

  def aggregate(query, :count) do
    send(self(), {:repo_count, query})
    Process.get(:test_repo_count, 0)
  end

  def one(query) do
    send(self(), {:repo_one, query})
    Process.get(:test_repo_one)
  end

  def preload(records, preloads) do
    send(self(), {:repo_preload, preloads})
    records
  end
end
