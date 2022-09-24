defmodule SpandexTeslaTest do
  use ExUnit.Case, async: true

  describe "add_span_opts/2" do
    test "basic attributes" do
      env = %Tesla.Env{
        method: :get,
        url: "https://www.example.com/api",
        status: 200,
        headers: [{"content-type", "application/json"}],
        query: [{"param", "value"}]
      }

      assert [
               http: [
                 status_code: 200,
                 method: "GET",
                 url: "https://www.example.com/api",
                 path: "/api",
                 query_string: "param=value",
                 host: "www.example.com",
                 port: 443,
                 scheme: "https"
               ],
               type: :web,
               resource: "GET /api",
               tags: [
                 span: [kind: "client"]
               ]
             ] = Tesla.Middleware.Spandex.get_span_opts(env)
    end
  end
end
