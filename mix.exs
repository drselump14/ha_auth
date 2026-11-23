defmodule HaAuth.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :ha_auth,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [main: "readme", extras: ["README.md"], source_ref: "v#{@version}"],
      source_url: "https://github.com/drselump14/ha_auth",
      description:
        "Sign in to Phoenix apps through Home Assistant: Kiosk Satellite, QR code, or HA's login."
    ]
  end

  def application do
    [mod: {HaAuth.Application, []}, extra_applications: [:logger, :crypto]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.1"},
      {:websockex, "~> 0.5.1"},
      {:req, ">= 0.5.0"},
      {:jason, "~> 1.2"},
      {:eqrcode, "~> 0.2"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/drselump14/ha_auth"},
      files: ~w(lib mix.exs README.md LICENSE .formatter.exs)
    ]
  end
end
