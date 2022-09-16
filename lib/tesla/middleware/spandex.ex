defmodule Tesla.Middleware.Spandex do
  @moduledoc """
  Creates spans for tracing.

  Uses the [Spandex](https://hex.pm/packages/spandex)
  tracing library, which suports Datadog.

  ### Examples

  ```
  defmodule MyClient do
    use Tesla

    plug Tesla.Middleware.Spandex, tracer: MyApp.Tracer
  end
  ```

  ### Options

  - `:tracer` - Application's Spandex.Tracer module
  """
  @behaviour Tesla.Middleware

  @impl true
  def call(env, next, options) do
    # span_name = get_span_name(env)
    {tracer, env} = ensure_tracer(env, options)

    tracer.span("http.request") do
      env
      |> Tesla.put_headers(tracer.inject_context([]))
      |> Tesla.run(next)
      |> set_span_attrs()
      |> handle_result(tracer)
    end
  end

  @spec ensure_tracer(Tesla.Env.t(), Keyword.t()) :: {any(), Tesla.Env.t()}
  defp ensure_tracer(env, options) do
    case Keyword.fetch(env.opts, :tracer) do
      {:ok, tracer} ->
        {tracer, env}

      :error ->
        tracer = Keyword.fetch(options, :tracer)
        {tracer, Tesla.put_opt(env, :tracer, tracer)}
    end
  end

  # @spec get_span_name(Tesla.Env.t()) :: String.t()
  # defp get_span_name(env) do
  #   case env.opts[:path_params] do
  #     nil ->
  #       "HTTP #{format_http_method(env.method)}"
  #
  #     _ ->
  #       URI.parse(env.url).path
  #   end
  # end

  defp set_span_attrs({_, %Tesla.Env{} = env} = result) do
    tracer = env.opts[:tracer]
    tracer.update_span(get_attrs(env))
    result
  end

  @spec get_attrs(Tesla.Env.t()) :: Keyword.t()
  defp get_attrs(env) do
    %Tesla.Env{
      method: method,
      url: url,
      status: status_code,
      headers: headers,
      query: query
    } = env

    url = Tesla.build_url(url, query)
    uri = URI.parse(url)

    method = format_http_method(method)

    # https://docs.datadoghq.com/tracing/trace_collection/tracing_naming_convention/
    [
      {:"span.kind", "client"},
      {:service, uri.host},
      {:resource, "#{method} #{url}"},

      {:"http.status_code", status_code},
      {:"http.url", url},
      {:"http.method", method},
      # http.version
      # http.route # path template, e.g. /users/:user_id
      {:"http.target", uri.path},
      {:"http.host", uri.host},
      {:"http.scheme", uri.scheme}
      # http.request.content_length
      # http.response.content_length
    ]
    |> maybe_add_content_length(headers)
  end

  defp maybe_add_content_length(attrs, headers) do
    case Enum.find(headers, fn {k, _v} -> k == "content-length" end) do
      nil ->
        attrs

      {_key, content_length} ->
        Keyword.put(attrs, :"http.response_content_length", content_length)
    end
  end

  defp handle_result({:ok, %Tesla.Env{status: status} = env}, tracer) when status > 400 do
    tracer.update_span([:error, error?: true])
    {:ok, env}
  end

  defp handle_result({:error, {Tesla.Middleware.FollowRedirects, :too_many_redirects}} = result, tracer) do
    tracer.update_span([:error, error?: true])
    result
  end

  defp handle_result({:ok, env}, _tracer) do
    {:ok, env}
  end

  defp handle_result(result, tracer) do
    tracer.update_span([:error, error?: true])
    result
  end

  @spec format_http_method(atom()) :: String.t()
  defp format_http_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end
end
