defmodule Francy.Repo do
  use Ecto.Repo,
    otp_app: :francy,
    adapter: Ecto.Adapters.Postgres
end
