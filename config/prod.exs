use Mix.Config

config :nadia,
  token: "${GUITARBOT_TOKEN}"

config :guitarbot, GuitarBot.Repo,
  adapter: Ecto.Adapters.Postgres,
  url: {:system, "DATABASE_URL"},
  database: "",
  ssl: true,
  pool_size: 1