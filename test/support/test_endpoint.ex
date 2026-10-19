defmodule ElementorexCms.TestEndpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :elementorex_cms

  @session_options [store: :cookie, key: "_exr_test", signing_salt: "exr-test", same_site: "Lax"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, @session_options
  plug ElementorexCms.TestRouter
end
