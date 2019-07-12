defmodule UeberauthTwitchTv.Mixfile do
  use Mix.Project

  @version "0.5.0"
  @repo_url "https://github.com/DMeechan/ueberauth_twitch_tv"

  def project do
    [
      app: :ueberauth_twitch_tv,
      version: @version,
      name: "Ueberauth Twitch.tv",
      package: package(),
      elixir: "~> 1.7",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: @repo_url,
      homepage_url: @repo_url,
      description: description(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [applications: [:logger, :ueberauth, :oauth2]]
  end

  defp deps do
    [
      {:ueberauth, "~> 0.6"},
      {:oauth2, "~> 1.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [extras: ["README.md"]]
  end

  defp description do
    "An Ueberauth strategy for using Twitch.tv to authenticate your users."
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: [
        "Daniel Meechan",
        "Built on contributions from: Andy Warner",
        "Built on contributions from: Tim Smith"
      ],
      licenses: ["MIT"],
      links: %{GitHub: @repo_url}
    ]
  end
end
