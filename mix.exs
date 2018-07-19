defmodule GuitarBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :guitarbot,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :misc_random, :parse_trans],
      mod: {GuitarBot, []}
    ]
  end

  defp deps do
    [
      {:nadia, "~> 0.4.2"},
      {:httpotion, "~> 3.1.0"},
      {:floki, "~> 0.20.0"},
      # {:html5ever, "~> 0.6.0"},
      {:distillery, "~> 1.0.0"},
      # Until it uses rustler 0.16, when installing html5ever do this:
      # cd deps/html5ever/native/html5ever_nif
      # cargo update
      # Source: https://github.com/hansihe/html5ever_elixir/issues/7#issuecomment-359689792
      { :pdf_generator, ">=0.3.5" }
    ]
  end
end
