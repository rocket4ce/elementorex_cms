defmodule ExampleWeb.Router do
  use ExampleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ExampleWeb.Locale
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExampleWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :default, on_mount: ExampleWeb.Locale do
      # Public pages built with the visual editor
      live "/p/:slug", PageLive.Show, :show

      # No authentication: this app is a test bench for the library. In a real
      # app these go inside the authenticated admin live_session.
      live "/admin/pages", PageLive.Index, :index
      live "/admin/pages/:id/edit", PageLive.Editor, :edit
      live "/playground", PlaygroundLive, :index
    end
  end

  if Application.compile_env(:example, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExampleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
