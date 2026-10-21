defmodule Example.EditorMedia do
  @moduledoc """
  Storage of the editor's images (`ElementorexCms.Media`): uploads are copied
  to `priv/static/uploads` and served by `Plug.Static`. Good enough for a test
  bench; a real app would use S3 or similar.
  """

  @behaviour ElementorexCms.Media

  @extensions ~w(.png .jpg .jpeg .gif .webp .svg .avif)

  @impl true
  def store(%{path: path, filename: filename}, _context) do
    ext = filename |> Path.extname() |> String.downcase()

    if ext in @extensions do
      name = "#{System.unique_integer([:positive, :monotonic])}-#{slug(filename)}#{ext}"
      File.mkdir_p!(dir())

      case File.cp(path, Path.join(dir(), name)) do
        :ok -> {:ok, %{url: "/uploads/" <> name, alt: Path.rootname(filename)}}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :unsupported_format}
    end
  end

  @impl true
  def list(opts, _context) do
    search = opts[:search] && String.downcase(opts[:search])

    case File.ls(dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&image?/1)
        |> Enum.filter(&(search in [nil, ""] or String.contains?(String.downcase(&1), search)))
        |> Enum.sort(:desc)
        |> Enum.take(60)
        |> Enum.map(&%{url: "/uploads/" <> &1, thumb: "/uploads/" <> &1, name: &1})

      {:error, _} ->
        []
    end
  end

  defp image?(file), do: String.downcase(Path.extname(file)) in @extensions

  defp dir, do: Application.app_dir(:example, "priv/static/uploads")

  defp slug(filename) do
    filename
    |> Path.rootname()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 40)
  end
end
