![tests](https://github.com/reachfh/spandex_tesla/actions/workflows/test.yml/badge.svg)

# SpandexTesla

Middleware for the [Tesla](https://hexdocs.pm/tesla/readme.html) HTTP client
library that creates spans using the [Spandex](https://hex.pm/packages/spandex)
tracing library. Spandex supports Datadog tracing.

## Installation

Add `spandex_tesla` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spandex_tesla, "~> 0.1.0"}
  ]
end
```

## Configuration

Add this middleware to the Tesla configuration for your client.

```elixir
defmodule GitHub do
  use Tesla

  plug Tesla.Middleware.Spandex
  plug Tesla.Middleware.BaseUrl, "https://api.github.com"
  plug Tesla.Middleware.Headers, [{"authorization", "token xyz"}]
  plug Tesla.Middleware.JSON

  def user_repos(login) do
    get("/users/" <> login <> "/repos")
  end
end
```
