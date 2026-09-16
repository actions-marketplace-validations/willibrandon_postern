import Config

# The language server speaks LSP on stdout, so every log line has to go to
# stderr, and editors show that stream in their output panes, so no colours.
config :logger, level: :warning

config :logger, :default_handler, config: [type: :standard_error]

config :logger, :default_formatter, colors: [enabled: false]
