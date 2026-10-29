defmodule NervesSurfaceRtCell do
  @moduledoc """
  Wolfram's elementary cellular automata on the Surface RT

  The Surface boots to IEx on its screen. `start/0` takes over the screen
  with the visualization, and `stop/0` gives it back to the console. Both
  are imported into IEx, so `start` and `stop` at the prompt work.
  """

  alias NervesSurfaceRtCell.Visualization

  @doc """
  Start the visualization

  The console is hidden while it runs. The keyboard still types into IEx,
  so `stop` brings the console back.
  """
  @spec start() :: :ok | {:error, term()}
  def start() do
    # Temporary, so stop/0 removes it and a crash leaves the console
    child = Supervisor.child_spec(Visualization, restart: :temporary)

    case Supervisor.start_child(NervesSurfaceRtCell.Supervisor, child) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stop the visualization and show the console again
  """
  @spec stop() :: :ok | {:error, :not_running}
  def stop() do
    case Supervisor.terminate_child(NervesSurfaceRtCell.Supervisor, Visualization) do
      :ok -> :ok
      {:error, :not_found} -> {:error, :not_running}
    end
  end
end
