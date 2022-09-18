defmodule SpandexTeslaTest do
  use ExUnit.Case, async: true

  require SpandexTesla.Tracer

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

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

  test "records a ", %{bypass: bypass} do
    defmodule TestClient do
      def get(client) do
        params = [id: '3']

        Tesla.get(client, "/users/:id", opts: [path_params: params])
      end

      def client(url) do
        middleware = [
          {Tesla.Middleware.BaseUrl, url},
          {Tesla.Middleware.Spandex, tracer: SpandexTesla.Tracer},
          Tesla.Middleware.PathParams,
          {Tesla.Middleware.Logger, debug: false}
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users/3", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    SpandexTesla.Tracer.trace "top" do
      bypass.port
      |> endpoint_url()
      |> TestClient.client()
      |> TestClient.get()
    end

    span = Spandex.Test.Util.find_span("http.request")
    assert span.http[:status_code] == 204
    assert span.http[:method] == "GET"
    assert span.http[:path] == "/users/3"
    assert span.http[:route] == "/users/:id"
    assert span.http[:host] == "localhost"
    assert span.http[:scheme] == "http"
    assert span.resource == "GET /users/3"
    assert span.service == :spandex_tesla
    assert span.tags == [span: [kind: "client"]]
    assert span.type == :web
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
