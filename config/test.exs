import Config

config :logger,
  level: :debug

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:file, :line]

config :spandex_tesla, SpandexTesla.Tracer,
  service: :myapi,
  adapter: SpandexDatadog.Adapter,
  disabled?: false,
  env: "test"
