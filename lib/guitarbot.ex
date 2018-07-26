defmodule GuitarBot do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    children = [
      supervisor(GuitarBot.Repo, []),
      worker(GuitarBot.Otp.Worker, []),
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
