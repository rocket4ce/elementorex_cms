import Config

if config_env() == :test do
  config :elementorex_cms, ElementorexCms.TestEndpoint,
    url: [host: "localhost"],
    secret_key_base: String.duplicate("elementorex", 8),
    live_view: [signing_salt: "elementorex-test"],
    render_errors: [formats: [html: ElementorexCms.TestErrorHTML], layout: false],
    pubsub_server: ElementorexCms.TestPubSub,
    check_origin: false,
    server: false

  config :phoenix, :json_library, Jason
  config :logger, level: :warning
end
