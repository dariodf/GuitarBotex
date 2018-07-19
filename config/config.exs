use Mix.Config

# config :floki, :html_parser, Floki.HTMLParser.Html5ever

config :pdf_generator,
    command_prefix: ["xvfb-run", "-a"]

import_config "#{Mix.env}.exs"