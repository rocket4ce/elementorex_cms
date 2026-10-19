Application.put_env(:elementorex_cms, :locale, "en")

{:ok, _} =
  Supervisor.start_link(
    [{Phoenix.PubSub, name: ElementorexCms.TestPubSub}, ElementorexCms.TestEndpoint],
    strategy: :one_for_one
  )

ExUnit.start()
