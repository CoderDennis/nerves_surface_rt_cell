defmodule NervesSurfaceRtCell.Visualization do
  @moduledoc """
  Supervises the processes that run the visualization

  Display first, since Touch and Orientation send to it. If Display
  restarts, the others restart too.
  """
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      NervesSurfaceRtCell.Display,
      NervesSurfaceRtCell.Touch,
      NervesSurfaceRtCell.Orientation
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
