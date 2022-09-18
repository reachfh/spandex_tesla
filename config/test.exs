import Config

config :logger,
  level: :warning

config :logger, :console,
  level: :warning,
  format: "$time $metadata[$level] $message\n",
  metadata: [:mfa]

config :spandex_tesla,
  tracer: SpandexTesla.Tracer

config :spandex_tesla, SpandexTesla.Tracer,
  service: :spandex_tesla,
  adapter: Spandex.TestAdapter,
  sender: Spandex.TestSender,
  disabled?: false,
  resource: "default",
  env: "test"

config :tesla, Tesla.Middleware.Logger,
  # format: "$method $url ====> $status / time=$time",
  debug: true
