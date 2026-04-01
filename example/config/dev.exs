import Config

try do
  import_config "dev.secret.exs"
rescue
  _error ->
    IO.puts(:stderr, "dev.secret.exs: file not found")
end
