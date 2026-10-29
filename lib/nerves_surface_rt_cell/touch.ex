defmodule NervesSurfaceRtCell.Touch do
  @moduledoc """
  Turns touchscreen touches into taps on `NervesSurfaceRtCell.Display`

  The Surface RT's Atmel maXTouch is a HID multitouch device. Its single
  touch emulation (`ABS_X`, `ABS_Y` and `BTN_TOUCH`) is enough for taps:
  a tap is sent when a finger touches the screen, at its position as a
  fraction of the screen's width and height.

  The touchscreen is the first input device with multitouch positions
  (`ABS_MT_POSITION_X`), or the `:touch_device` path in the application
  environment. On the Surface RT it's named "hid-over-i2c 03EB:8207"
  (Atmel). The Type Cover's touchpad has no absolute axes. If the
  touchscreen isn't there yet, it's looked for again every 2 seconds.

  If taps land in the wrong place, set `:touch` in the application
  environment, e.g. `config :nerves_surface_rt_cell, touch: [invert_y: true]`.
  The options are `:swap_xy`, `:invert_x` and `:invert_y`.
  """
  use GenServer

  require Logger

  # input_event is a target-only dependency
  @compile {:no_warn_undefined, InputEvent}

  alias NervesSurfaceRtCell.Display

  @retry_ms 2_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    state = %{
      transform: Application.get_env(:nerves_surface_rt_cell, :touch, []),
      path: nil,
      ranges: nil,
      x: 0,
      y: 0
    }

    {:ok, state, {:continue, :find}}
  end

  @impl GenServer
  def handle_continue(:find, state) do
    case find_device() do
      {path, ranges} ->
        Logger.info("Touchscreen at #{path}")
        {:ok, _pid} = InputEvent.start_link(path: path, receiver: self())
        {:noreply, %{state | path: path, ranges: ranges}}

      nil ->
        Process.send_after(self(), :find, @retry_ms)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:find, state), do: {:noreply, state, {:continue, :find}}

  def handle_info({:input_event, _path, events}, state) do
    state = Enum.reduce(events, state, &position/2)

    if {:ev_key, :btn_touch, 1} in events do
      Display.tap(to_fractions(state))
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp position({:ev_abs, :abs_x, x}, state), do: %{state | x: x}
  defp position({:ev_abs, :abs_y, y}, state), do: %{state | y: y}
  defp position(_event, state), do: state

  defp to_fractions(%{ranges: {rx, ry}, transform: transform} = state) do
    fx = fraction(state.x, rx)
    fy = fraction(state.y, ry)
    {fx, fy} = if transform[:swap_xy], do: {fy, fx}, else: {fx, fy}
    fx = if transform[:invert_x], do: 1 - fx, else: fx
    fy = if transform[:invert_y], do: 1 - fy, else: fy
    {fx, fy}
  end

  defp fraction(value, %{min: lo, max: hi}) when hi > lo do
    min(max((value - lo) / (hi - lo), 0.0), 1.0)
  end

  defp fraction(_value, _range), do: 0.0

  defp find_device() do
    devices =
      Enum.flat_map(InputEvent.enumerate(), fn {path, info} ->
        abs = Keyword.get(info.report_info, :ev_abs, [])

        case {axis(abs, :abs_x), axis(abs, :abs_y), axis(abs, :abs_mt_position_x)} do
          {%{} = x, %{} = y, %{}} -> [{path, {x, y}}]
          _ -> []
        end
      end)

    configured = Application.get_env(:nerves_surface_rt_cell, :touch_device)

    if configured do
      Enum.find(devices, fn {path, _ranges} -> path == configured end)
    else
      List.first(devices)
    end
  end

  defp axis(abs, code) do
    Enum.find_value(abs, fn
      {^code, %{} = range} -> range
      _ -> nil
    end)
  end
end
