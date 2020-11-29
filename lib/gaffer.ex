defmodule Gaffer do
  @moduledoc ~S"""
  Gaffer process starts, monitors and restarts processes with some backoff delay.
  If managed process is running under supervisor it should use `:temporary` strategy to avoid being restarted by the supervisor.

  If gaffer process crashes for some reason all managed processes will become "dangling".
  Keep this in mind when organizing your supervisor tree.

  To avoid the situation with dangling processes
  you may start Gaffer and all managed processes under the same supervisor using :one_for_rest strategy.
  """

  use GenServer

  require Logger

  @doc ~S"""
  Run Gaffer process with options.

  # Options

  * `:backoff` - should be function or tuple.
     Backoff function should return delay between managed process restarts in milliseconds.
     Backoff tuple {:const, 5000} implies process restart in 5000 milliseconds.
     Default backoff value is {:const, 1000}.
  """
  def start_link(init_arg) do
    gen_server_opts = [:name, :timeout, :debug, :spawn_opt, :hibernate_after]
    opts = Keyword.take(init_arg, gen_server_opts)

    GenServer.start_link(__MODULE__, init_arg, opts)
  end

  @doc ~S"""
  Asynchronously start and manage process restarts with mfa.

  mfa callback should return `{:ok, pid}` if process started successfully or error the otherwise.
  """
  def take(gaffer, mod, fun, args, opts \\ []) do
    send(gaffer, {:take, {mod, fun, args}, opts})

    :ok
  end

  @impl GenServer
  def init(init_arg) do
    backoff = Keyword.get(init_arg, :backoff, {:const, 1000})

    {:ok, %{backoff: backoff, refs: %{}}}
  end

  @impl GenServer
  def handle_info({:take, {m, f, a} = mfa, opts}, state) do
    %Task{} =
      Task.Supervisor.async_nolink(Gaffer.TaskSupervisor, fn ->
        {:take_async, apply(m, f, a), mfa, opts}
      end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({_ref, {:take_async, apply_result, mfa, opts}}, state) do
    case apply_result do
      {:ok, pid} ->
        {:noreply, %{state | refs: Map.put(state.refs, Process.monitor(pid), {mfa, opts})}}

      error ->
        Logger.error("failed to start worker #{inspect(error)}")
        schedule_restart(mfa, opts, state)

        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, mref, :process, _pid, _reason}, state) do
    Process.demonitor(mref, [:flush])

    case Map.pop(state.refs, mref) do
      {nil, _} ->
        {:noreply, state}

      {{mfa, opts}, refs} ->
        schedule_restart(mfa, opts, state)

        {:noreply, Map.put(state, :refs, refs)}
    end
  end

  defp schedule_restart(mfa, opts, state) do
    backoff = Keyword.get(opts, :backoff, state.backoff)

    Process.send_after(self(), {:take, mfa, opts}, delay(backoff))
  end

  defp delay({:const, milliseconds}), do: milliseconds
  defp delay(backoff) when is_function(backoff), do: backoff.()
end
