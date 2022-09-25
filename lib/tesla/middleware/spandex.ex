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

  This can also be set in the application config:

    config :spandex_tesla,
      tracer: SpandexTesla.Tracer

  - `:span_opts` - Options for Spandex.start_span/2 and Spandex.span_error/2
  """
  @behaviour Tesla.Middleware

  @type tesla_result() :: {any(), Tesla.Env.t()}

  @impl true
  def call(env, next, options) do
    # span_name = get_span_name(env)
    {tracer, env} = ensure_tracer(env, options)
    span_opts = env.opts[:span_opts] || []

    tracer.start_span("http.request", span_opts)

    try do
      env
      |> Tesla.put_headers(tracer.inject_context([]))
      |> handle_path_params(tracer)
      |> Tesla.run(next)
    rescue
      exception ->
        stacktrace = __STACKTRACE__
        tracer.span_error(exception, stacktrace, span_opts)
        reraise exception, stacktrace
    else
        {:ok, new_env} = result ->
          span_opts = DeepMerge.deep_merge(get_span_opts(new_env), env.opts[:span_opts] || [])
          tracer.update_span(span_opts)

          result

        {:error, _reason} = result ->
          span_opts = DeepMerge.deep_merge(get_span_opts(env), env.opts[:span_opts] || [])
          tracer.update_span(span_opts)

          result
    after
      tracer.finish_span()
    end
  end

  @spec ensure_tracer(Tesla.Env.t(), Keyword.t()) :: {any(), Tesla.Env.t()}
  def ensure_tracer(env, options) do
    cond do
      tracer = env.opts[:tracer] ->
        {tracer, env}

      tracer = Application.get_env(:spandex_tesla, :tracer) ->
        {tracer, Tesla.put_opt(env, :tracer, tracer)}

      tracer = options[:tracer] ->
        {tracer, Tesla.put_opt(env, :tracer, tracer)}

      true ->
        raise "No tracer defined"
    end
  end

  @spec get_span_opts(Tesla.Env.t()) :: Keyword.t()
  def get_span_opts(env) do
    %Tesla.Env{
      method: method,
      url: url,
      status: status_code,
      headers: headers,
      query: query
    } = env

    full_url = Tesla.build_url(url, query)
    uri = URI.parse(full_url)

    method = format_http_method(method)
    path = uri.path || "/"

    tags = [
      span: [kind: "client"]
    ]
    |> add_content_length(headers)

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
        scheme: uri.scheme
      ],
      type: :web,
      resource: "#{method} #{path}",
      tags: tags
    ]
    |> set_status_error(env)
  end

  # With Tesla.Middleware.PathParams, the path is initially a template,
  # e.g. /users/:user_id, then expanded to the final version.
  @spec handle_path_params(Tesla.Env.t(), module()) :: Tesla.Env.t()
  defp handle_path_params(env, tracer) do
    case Keyword.fetch(env.opts, :path_params) do
      {:ok, _} ->
        %Tesla.Env{url: url, query: query} = env
        full_url = Tesla.build_url(url, query)
        uri = URI.parse(full_url)
        path = uri.path || "/"
        # Maybe set resource as well here

        tracer.update_span(http: [route: path])
        env

      :error ->
        env
    end
  end

  @spec add_content_length(Keyword.t(), Tesla.Env.headers()) :: Keyword.t()
  defp add_content_length(tags, headers) do
    case Enum.find(headers, fn {k, _v} -> k == "content-length" end) do
      nil ->
        tags

      {_key, content_length} ->
        DeepMerge.deep_merge(tags, [http: [response: [content_length: content_length]]])
        # Keyword.put(tags, :"http.response.content_length", content_length)
    end
  end

  @spec set_status_error(Keyword.t(), Tesla.Env.t()) :: Keyword.t()
  def set_status_error(span_opts, %Tesla.Env{status: status}) when status > 400 do
    Keyword.put(span_opts, :error, [error?: true])
  end

  def set_status_error(span_opts, _) do
    span_opts
  end

  @spec format_http_method(atom()) :: String.t()
  defp format_http_method(method) do
    method
    |> Atom.to_string()
    |> String.upcase()
  end
end
