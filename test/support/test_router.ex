defmodule ElementorexCms.TestRouter do
  @moduledoc false
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser
    live "/editor", ElementorexCms.TestEditorLive
  end
end
