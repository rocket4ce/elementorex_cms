defmodule ElementorexCms.Editor.History do
  @moduledoc """
  Undo and redo for the editor: snapshots of the document with a label.

  Edits of the same field that follow each other quickly (typing in an input)
  are merged into one step, so undo goes back a whole word and not a letter.
  """

  defstruct past: [], future: [], last: nil, limit: 100

  @type entry :: %{doc: map(), label: String.t(), at: integer()}
  @type t :: %__MODULE__{past: [entry()], future: [entry()], last: term(), limit: pos_integer()}

  @merge_window_ms 1_500

  @doc "An empty history."
  @spec new(keyword()) :: t()
  def new(opts \\ []), do: %__MODULE__{limit: Keyword.get(opts, :limit, 100)}

  @doc """
  Records `previous` (the document before a change) under `label`. `key`
  identifies the edited field: consecutive changes with the same key within
  #{@merge_window_ms} ms are merged.
  """
  @spec push(t(), map(), String.t(), term()) :: t()
  def push(history, previous, label, key \\ nil) do
    now = System.monotonic_time(:millisecond)

    merge? =
      key != nil and match?({^key, at} when now - at < @merge_window_ms, history.last)

    if merge? do
      %{history | future: [], last: {key, now}}
    else
      entry = %{doc: previous, label: label, at: System.system_time(:second)}

      %{
        history
        | past: Enum.take([entry | history.past], history.limit),
          future: [],
          last: key && {key, now}
      }
    end
  end

  @doc "Goes one step back. Returns `{:ok, document, history}` or `:error`."
  @spec undo(t(), map()) :: {:ok, map(), t()} | :error
  def undo(%__MODULE__{past: [entry | past]} = history, current) do
    redo_entry = %{entry | doc: current}
    {:ok, entry.doc, %{history | past: past, future: [redo_entry | history.future], last: nil}}
  end

  def undo(_history, _current), do: :error

  @doc "Goes one step forward. Returns `{:ok, document, history}` or `:error`."
  @spec redo(t(), map()) :: {:ok, map(), t()} | :error
  def redo(%__MODULE__{future: [entry | future]} = history, current) do
    undo_entry = %{entry | doc: current}
    {:ok, entry.doc, %{history | future: future, past: [undo_entry | history.past], last: nil}}
  end

  def redo(_history, _current), do: :error

  @doc "Whether there is something to undo."
  def can_undo?(%__MODULE__{past: past}), do: past != []

  @doc "Whether there is something to redo."
  def can_redo?(%__MODULE__{future: future}), do: future != []

  @doc """
  Jumps to step `index` of `past` (0 is the most recent), keeping the steps in
  between as redo steps.
  """
  @spec restore(t(), map(), non_neg_integer()) :: {:ok, map(), t()} | :error
  def restore(history, current, 0), do: undo(history, current)

  def restore(history, current, index) when index > 0 do
    case undo(history, current) do
      {:ok, doc, history} -> restore(history, doc, index - 1)
      :error -> :error
    end
  end
end
