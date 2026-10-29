defmodule NervesSurfaceRtCell.Orientation do
  @moduledoc """
  Rotates `NervesSurfaceRtCell.Display` to follow the accelerometer

  The accelerometer is in the Surface RT's HID sensor hub. The kernel's
  `hid-sensor-accel-3d` driver makes it an IIO device named `accel_3d`.
  Every 500 ms this reads `in_accel_{x,y,z}_raw`. The axis that gravity
  pulls along most decides the rotation. It must win clearly, and twice in
  a row, before the screen turns. Lying flat (gravity along z) keeps the
  current rotation.

  Which axis direction means which rotation depends on how the sensor is
  mounted. Override it in the application environment if the screen turns
  the wrong way, e.g.:

      config :nerves_surface_rt_cell,
        orientation: %{x_neg: 0, x_pos: 180, y_neg: 270, y_pos: 90}
  """
  use GenServer

  require Logger

  alias NervesSurfaceRtCell.Display

  @poll_ms 500
  @default_map %{y_neg: 0, y_pos: 180, x_neg: 90, x_pos: 270}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  The latest raw accelerometer reading, for calibrating the axis map
  """
  @spec reading() :: {integer(), integer(), integer()} | nil
  def reading(), do: GenServer.call(__MODULE__, :reading)

  @impl GenServer
  def init(_opts) do
    map = Map.merge(@default_map, Application.get_env(:nerves_surface_rt_cell, :orientation, %{}))

    case find_device() do
      nil ->
        Logger.warning("No accel_3d IIO device, so the screen won't rotate")
        :ignore

      dir ->
        Logger.info("Accelerometer at #{dir}")
        send(self(), :poll)
        {:ok, %{dir: dir, map: map, rotation: 0, candidate: nil, reading: nil}}
    end
  end

  @impl GenServer
  def handle_call(:reading, _from, state), do: {:reply, state.reading, state}

  @impl GenServer
  def handle_info(:poll, state) do
    Process.send_after(self(), :poll, @poll_ms)

    case read(state.dir) do
      {:ok, reading} ->
        {:noreply, update(%{state | reading: reading}, classify(reading, state.map))}

      :error ->
        {:noreply, state}
    end
  end

  # Turn once the same new rotation is seen twice in a row
  defp update(state, nil), do: %{state | candidate: nil}
  defp update(%{rotation: rotation} = state, rotation), do: %{state | candidate: nil}

  defp update(%{candidate: candidate} = state, candidate) do
    Display.rotate(candidate)
    %{state | rotation: candidate, candidate: nil}
  end

  defp update(state, rotation), do: %{state | candidate: rotation}

  @doc """
  The rotation for a reading, or `nil` if it's not clear
  """
  @spec classify({integer(), integer(), integer()}, map()) :: 0 | 90 | 180 | 270 | nil
  def classify({x, y, z}, map) do
    {ax, ay, az} = {abs(x), abs(y), abs(z)}

    cond do
      ax >= 1.5 * ay and ax >= 0.5 * az and ax > 0 -> if x < 0, do: map.x_neg, else: map.x_pos
      ay >= 1.5 * ax and ay >= 0.5 * az and ay > 0 -> if y < 0, do: map.y_neg, else: map.y_pos
      true -> nil
    end
  end

  defp find_device() do
    Path.wildcard("/sys/bus/iio/devices/iio:device*")
    |> Enum.find(fn dir ->
      match?({:ok, "accel_3d" <> _}, File.read(Path.join(dir, "name")))
    end)
  end

  defp read(dir) do
    with {:ok, x} <- read_integer(dir, "in_accel_x_raw"),
         {:ok, y} <- read_integer(dir, "in_accel_y_raw"),
         {:ok, z} <- read_integer(dir, "in_accel_z_raw") do
      {:ok, {x, y, z}}
    end
  end

  defp read_integer(dir, name) do
    with {:ok, contents} <- File.read(Path.join(dir, name)),
         {value, _} <- Integer.parse(String.trim(contents)) do
      {:ok, value}
    else
      _ -> :error
    end
  end
end
