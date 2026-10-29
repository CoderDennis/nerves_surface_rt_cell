defmodule NervesSurfaceRtCell.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Nothing draws on the screen until NervesSurfaceRtCell.start/0 adds
    # NervesSurfaceRtCell.Visualization here, so the Surface boots to IEx.
    opts = [strategy: :one_for_one, name: NervesSurfaceRtCell.Supervisor]
    Supervisor.start_link([], opts)
  end
end
