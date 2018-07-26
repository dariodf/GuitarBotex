use Mix.Config

config :guitarbot, GuitarBot.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "guitarbot",
  username: "guitarbot",
  password: "guitarbot",
  hostname: "localhost"


# config :floki, :html_parser, Floki.HTMLParser.Html5ever

config :pdf_generator,
    command_prefix: ["xvfb-run", "-a"]

import_config "#{Mix.env}.exs"

config :guitarbot, ecto_repos: [GuitarBot.Repo]