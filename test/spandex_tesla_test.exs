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

      expected = [
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
      ]

      result = Tesla.Middleware.Spandex.get_span_opts(env)
      assert ^expected = result
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
          Tesla.Middleware.PathParams
        ]

        Tesla.client(middleware)
      end
    end

    Bypass.expect_once(bypass, "GET", "/users/3", fn conn ->
      Plug.Conn.resp(conn, 204, "")
    end)

    SpandexTesla.Tracer.trace("top") do
      bypass.port
      |> endpoint_url()
      |> TestClient.client()
      |> TestClient.get()
    end

    assert_receive {:sent_trace, ""}

    # assert_receive {:sent_trace,
    #   %Spandex.Trace{
    #     spans: [
    #       %Spandex.Span{
    #         http: nil,
    #         name: "phx.router_dispatch",
    #         resource: "get /prismic/personalization_traits",
    #         service: :api,
    #         type: :web
    #       },
    #       %Spandex.Span{
    #         http: [
    #           method: "GET",
    #           query_string: "",
    #           status_code: 200,
    #           url: "/prismic/personalization_traits",
    #           user_agent: nil
    #         ],
    #         name: "request",
    #         resource: "get /prismic/personalization_traits",
    #         service: :api,
    #         type: :web
    #       }
    #     ]
    #   }}

  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
