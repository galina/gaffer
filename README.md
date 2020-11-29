# Gaffer

Yet another manager to asynchronously start elixir processes, monitor and restart with given backoff.

# Usage

Start gaffer process:

```elixir
children =
  [
    {Gaffer, [name: :gaffer]}
  ]

Supervisor.start_link(children, opts)
```

implement some worker process:

```elixir
defmodule Worker do
  @moduledoc false

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    IO.puts("run worker #{inspect(self())} with args #{inspect(args)} at #{NaiveDateTime.utc_now()}")

    {:ok, %{}}
  end
end
```

start managed worker process:

```elixir
> Gaffer.take(:gaffer, Worker, :start_link, [:args])

run worker #PID<0.163.0> with args :args at 2020-11-29 14:29:15.812120
```

if worker process terminates for some reason it will be restarted
by gaffer process in configured `backoff` milliseconds:

```elixir
> Process.exit(pid("0.163.0"), :shutdown) && to_string(NaiveDateTime.utc_now())
"2020-11-29 14:30:00.031040"

run worker #PID<0.169.0> with args :args at 2020-11-29 14:30:01.033048
```
