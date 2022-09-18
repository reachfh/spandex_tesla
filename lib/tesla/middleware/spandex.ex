defmodule Tesla.Middleware.Spandex do
  @moduledoc """
  Creates spans for tracing.

  Uses the [Spandex](https://hex.pm/packages/spandex)
  tracing library, which suports Datadog.

  Sets the attributes on the span based on Datadog conventions:

  https://docs.datadoghq.com/tracing/trace_collection/tracing_naming_convention/

  ### Examples

  ```
  defmodule MyClient do
    use Tesla

    plug Tesla.Middleware.Spandex, tracer: MyApp.Tracer
  end
  ```

  ### Options

  - `:tracer` - Application's Spandex.Tracer module
  - `:span_opts` - Options for Spandex.start_span/2 and Spandex.span_error/2
  """
  @behaviour Tesla.Middleware

  require Logger

  @impl true
  def call(env, next, options) do
    # span_name = get_span_name(env)
    {tracer, env} = ensure_tracer(env, options)

    span_opts = DeepMerge.deep_merge(get_span_opts(env), env.opts[:span_opts] || [])

    tracer.start_span("http.request", span_opts)
    try do
      env
      |> Tesla.put_headers(tracer.inject_context([]))
      |> Tesla.run(next)
      |> add_content_length(tracer)
      |> handle_result(tracer)
    rescue
      exception ->
        stacktrace = __STACKTRACE__
        tracer.span_error(exception, stacktrace, span_opts)
        reraise exception, stacktrace
    after
      tracer.finish_span()
    end
  end

  @spec ensure_tracer(Tesla.Env.t(), Keyword.t()) :: {any(), Tesla.Env.t()}
  def ensure_tracer(env, options) do
    cond do
      tracer = env.opts[:tracer] ->
        {tracer, env}

      tracer = options[:tracer] ->
        {tracer, Tesla.put_opt(env, :tracer, tracer)}

      tracer = Application.get_env(:spandex_tesla, :tracer) ->
        {tracer, Tesla.put_opt(env, :tracer, tracer)}

      true ->
        raise "No tracer defined"
    end
  end

  # defp get_span_name(env) do
  #   case env.opts[:path_params] do
  #     nil ->
  #       "HTTP #{format_http_method(env.method)}"
  #
  #     _ ->
  #       URI.parse(env.url).path
  #   end
  # end

  # defp set_span_opts({_, %Tesla.Env{} = env} = result, tracer) do
  #   tracer.update_span([tags: get_span_opts(env)])
  #   result
  # end

  @spec get_span_opts(Tesla.Env.t()) :: Keyword.t()
  def get_span_opts(env) do
    %Tesla.Env{
      method: method,
      url: url,
      status: status_code,
      # headers: headers,
      query: query
    } = env

    full_url = Tesla.build_url(url, query)
    uri = URI.parse(full_url)

    method = format_http_method(method)
    path = uri.path || "/"

    # These tags come mostly from Spandex.Span, but also includes tags from
    # https://docs.datadoghq.com/tracing/trace_collection/tracing_naming_convention/
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
    |> maybe_add_route(env)
  end

  # Path template, e.g. /users/:user_id
  # set when using Tesla.Middleware.PathParams
  @spec maybe_add_route(Keyword.t(), Tesla.Env.t()) :: Keyword.t()
  defp maybe_add_route(opts, env) do
    case Keyword.fetch(env.opts, :path_params) do
      {:ok, _} ->
        put_in(opts, [:http, :route], get_in(opts, [:http, :path]))

      :error ->
        opts
    end
  end

  defp add_content_length({:ok, %Tesla.Env{headers: headers}} = result, tracer) do
    case Enum.find(headers, fn {k, _v} -> k == "content-length" end) do
      nil ->
        result

      {_key, content_length} ->
        tracer.update_span(tags: [{:"http.response.content_length", content_length}])
        result
    end
  end
,
  defp add_content_length(result, _tracer) do
    result
  end

  defp handle_result({:ok, %Tesla.Env{status: status} = env}, tracer) when status > 400 do
    tracer.update_span(error: [error?: true])
    {:ok, env}
  end

  defp handle_result({:error, {Tesla.Middleware.FollowRedirects, :too_many_redirects}} = result, tracer) do
    tracer.update_span(error: [error?: true])
    result
  end

  defp handle_result({:ok, env}, _tracer) do
    {:ok, env}
  end

  defp handle_result(result, tracer) do
    tracer.update_span(error: [error?: true])
    result
  end

  @spec format_http_method(atom()) :: String.t()
  defp format_http_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end
end
