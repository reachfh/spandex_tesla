defmodule SpandexTesla.MixProject do
  use Mix.Project

  @github "https://github.com/reachfh/spandex_tesla"

  def project do
    [
      app: :spandex_tesla,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      source_url: @github,
      homepage_url: @github,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_apps: [:mix],
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger] ++ extra_applications(Mix.env())
    ]
  end

  defp extra_applications(:test), do: [:hackney]
  defp extra_applications(_),     do: []

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bypass, "~> 2.1", only: :test, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:deep_merge, "~> 1.0"},
      {:ex_doc, "~> 0.28.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.10", only: :test},
      {:httpoison, "~> 1.8", only: :test, runtime: false},
      {:hackney, "~> 1.18", only: [:dev, :test]},
      {:jason, "~> 1.3"},
      {:spandex, "~> 3.1"},
      # {:spandex_datadog, "~> 1.2"},
      {:tesla, "~> 1.4"},
    ]
  end

  defp description do
    "Middleware for Tesla HTTP client library that generates Datadog trace spans with Spandex"
  end

  defp package do
    [
      name: "spandex_tesla",
      maintainers: ["Jake Morrison"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github,
        "Tesla" => "https://github.com/elixir-tesla/tesla",
        "Spandex"=> "https://github.com/spandex-project/spandex"
      }
    ]
  end

  defp docs do
    [
      source_url: @github,
      extras: ["README.md", "CHANGELOG.md"],
      # api_reference: false,
      source_url_pattern: "#{@github}/blob/master/%{path}#L%{line}",
    ]
  end
end
