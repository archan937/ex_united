use Mix.Config

config :porcelain,
  goon_warn_if_missing: false

if File.exists?("config/#{Mix.env()}.exs") do
  import_config "#{Mix.env()}.exs"
end
