defmodule Gaffer.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Gaffer.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Gaffer.Supervisor)
  end
end
