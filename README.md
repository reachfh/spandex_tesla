![test workflow](https://github.com/reachfh/spandex_tesla/actions/workflows/test.yml/badge.svg)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)

# Tesla.Middleware.Spandex

Middleware for the [Tesla](https://hexdocs.pm/tesla/readme.html) HTTP client
library that supports [Datadog tracing](https://docs.datadoghq.com/tracing/)
using [Spandex](https://hex.pm/packages/spandex).

It creates a span for the client HTTP call, setting metadata:

```elixir
[
  http: [
    status_code: status_code,
    method: method,
    url: url,
    path: path,
    query_string: URI.encode_query(query),
    host: uri.host,
    port: uri.port,
    scheme: uri.scheme,
  ],
  type: :web,
  resource: "#{method} #{path}",
  tags: [
    span: [kind: "client"]
  ]
]
```
See https://docs.datadoghq.com/tracing/trace_collection/tracing_naming_convention/


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

Add this middleware as a plug in your client.

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

Configure the Spandex tracer in `config/config.exs`:

```elixir
config :spandex_tesla,
  tracer: Foo.Tracer
```

## Code of Conduct

This project  Contributor Covenant version 2.1. Check [CODE_OF_CONDUCT.md](/CODE_OF_CONDUCT.md) file for more information.
