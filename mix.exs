defmodule NervesSurfaceRtCell.MixProject do
  use Mix.Project

  @app :nerves_surface_rt_cell
  @version "0.1.0"
  @all_targets [:surface_rt]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.20",
      archives: [nerves_bootstrap: "~> 1.17"],
      listeners: listeners(Mix.target(), Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {NervesSurfaceRtCell.Application, []}
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.13", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:logger_backends, "~> 1.0"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.5.0"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.12"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},
      {:input_event, "~> 1.4", targets: @all_targets},

      # Dependencies for specific targets
      system_dep()
    ]
  end

  # The released Surface RT system from Hex, which comes with a prebuilt
  # system artifact. To test system changes before they're released, set
  # SURFACE_RT_SYSTEM_PATH to a local checkout of the system. It's then
  # built from source (in Docker on macOS) whenever it changes.
  defp system_dep do
    case System.get_env("SURFACE_RT_SYSTEM_PATH") do
      nil ->
        {:nerves_system_surface_rt, "~> 0.2.2", runtime: false, targets: :surface_rt}

      path ->
        {:nerves_system_surface_rt,
         path: path, runtime: false, targets: :surface_rt, nerves: [compile: true]}
    end
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://nerves-pack.hexdocs.pm/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  # Uncomment the following line if using Phoenix > 1.8.
  # defp listeners(:host, :dev), do: [Phoenix.CodeReloader]
  defp listeners(_, _), do: []
end
