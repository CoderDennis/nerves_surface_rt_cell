defmodule NervesSurfaceRtCell.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = target_children()

    # Display first, since Touch and Orientation send to it. If Display
    # restarts, the others restart too.
    opts = [strategy: :rest_for_one, name: NervesSurfaceRtCell.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  if Mix.target() == :host do
    # The host has no framebuffer or touchscreen. The drawing and the
    # automaton are pure modules that the tests cover.
    defp target_children(), do: []
  else
    defp target_children() do
      [
        NervesSurfaceRtCell.Display,
        NervesSurfaceRtCell.Touch,
        NervesSurfaceRtCell.Orientation
      ]
    end
  end
end
