defmodule ElementorexCms.Sources do
  @moduledoc """
  The sources of dynamic content a document can use (see
  `ElementorexCms.Source`), like `ElementorexCms.Registry` is for blocks.

  `default/0` reads the config:

      config :elementorex_cms,
        sources: [
          # an Ecto schema: every field, read from the schema
          MyApp.Catalog.Product,
          # a module (use ElementorexCms.Source.Ecto or the behaviour)
          MyAppWeb.Sources.Posts,
          # the Ecto adapter with options
          {ElementorexCms.Source.Ecto, schema: MyApp.Events.Event, path: "/events/:id"}
        ]

  Pass the same sources to the editor and to `ElementorexCms.Components.document/1`
  (`sources={...}`) to use others than the configured ones.
  """

  alias ElementorexCms.Source

  defstruct sources: %{}, order: []

  @type t :: %__MODULE__{sources: %{String.t() => Source.t()}, order: [String.t()]}

  @doc "The configured sources (`config :elementorex_cms, sources: [...]`)."
  @spec default() :: t()
  def default, do: new(Application.get_env(:elementorex_cms, :sources, []))

  @doc """
  Builds the sources from a list of source modules, Ecto schemas or
  `{adapter, opts}` tuples (see `ElementorexCms.Source.new/1`). `nil` gives
  `default/0`; a later source with the same key replaces an earlier one.
  """
  @spec new(t() | [term()] | nil) :: t()
  def new(nil), do: default()
  def new(%__MODULE__{} = sources), do: sources

  def new(list) when is_list(list) do
    Enum.reduce(list, %__MODULE__{}, fn spec, acc ->
      source = Source.new(spec)
      order = if source.key in acc.order, do: acc.order, else: acc.order ++ [source.key]
      %{acc | sources: Map.put(acc.sources, source.key, source), order: order}
    end)
  end

  @doc "The source with `key`, or `nil`."
  @spec fetch(t() | nil, term()) :: Source.t() | nil
  def fetch(%__MODULE__{sources: sources}, key) when is_binary(key), do: Map.get(sources, key)
  def fetch(_sources, _key), do: nil

  @doc "The sources in the order they were given."
  @spec list(t() | nil) :: [Source.t()]
  def list(%__MODULE__{sources: sources, order: order}), do: Enum.map(order, &sources[&1])
  def list(_sources), do: []

  @doc "Whether there are no sources."
  @spec empty?(t() | nil) :: boolean()
  def empty?(sources), do: list(sources) == []

  @doc """
  The source a record comes from: the one whose Ecto schema is the record's
  struct (see `ElementorexCms.Source.Ecto`), or `nil`.
  """
  @spec for_record(t() | nil, term()) :: Source.t() | nil
  def for_record(sources, %struct{}), do: Enum.find(list(sources), &(Source.schema(&1) == struct))
  def for_record(_sources, _record), do: nil
end
