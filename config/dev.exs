import Config

config :spandex_tesla, SpandexTesla.Tracer,
  service: :myapi,
  adapter: SpandexDatadog.Adapter,
  disabled?: false,
  env: "dev"
