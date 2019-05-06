defmodule Pools.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Pools.Worker.start_link(arg)
      {Pools.CastOnlyPool, [name: Pools.CastOnlyPool]},
      {Task.Supervisor, [name: Pools.ProcessesPool.Supervisor]},
      {Pools.ProcessesPool, [name: Pools.ProcessesPool]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Pools.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
