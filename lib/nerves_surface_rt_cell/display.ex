defmodule NervesSurfaceRtCell.Display do
  @moduledoc """
  The app's screens and the only process that draws on the framebuffer

  Screens:

    * `:picker` - choose a rule (`NervesSurfaceRtCell.UI.Picker`)
    * `:running` - the automaton grows one row per tick, and scrolls up a
      quarter of the screen at a time once it reaches the bottom
    * `:paused` - stopped, with Resume and New rule buttons

  `NervesSurfaceRtCell.Touch` sends taps and `NervesSurfaceRtCell.Orientation`
  sends rotations. The battery indicator is refreshed every 30 seconds.
  """
  use GenServer

  require Logger

  alias NervesSurfaceRtCell.Automaton
  alias NervesSurfaceRtCell.Battery
  alias NervesSurfaceRtCell.Framebuffer
  alias NervesSurfaceRtCell.Render
  alias NervesSurfaceRtCell.Rotation
  alias NervesSurfaceRtCell.UI
  alias NervesSurfaceRtCell.UI.Picker
  alias NervesSurfaceRtCell.UI.Runner

  @tick_ms 30
  @battery_ms 30_000
  @default_rule 30

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  A tap on the physical screen, as fractions (0.0-1.0) of its width and height
  """
  @spec tap({float(), float()}) :: :ok
  def tap(position), do: GenServer.cast(__MODULE__, {:tap, position})

  @doc """
  Rotate the screen to 0, 90, 180 or 270 degrees
  """
  @spec rotate(Rotation.t()) :: :ok
  def rotate(rotation) when rotation in [0, 90, 180, 270],
    do: GenServer.cast(__MODULE__, {:rotate, rotation})

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    case Framebuffer.open(Keyword.get(opts, :device, "fb0")) do
      {:ok, fb} ->
        state =
          %{
            fb: fb,
            physical: {fb.geometry.width, fb.geometry.height},
            rotation: 0,
            screen: :picker,
            rule: @default_rule,
            rows: [],
            count: 0,
            battery: Battery.info(),
            timer: nil
          }
          |> put_size()

        Process.send_after(self(), :battery, @battery_ms)
        {:ok, redraw(state)}

      {:error, reason} ->
        {:stop, {:framebuffer, reason}}
    end
  end

  @impl GenServer
  def handle_cast({:tap, {fx, fy}}, state) do
    {pw, ph} = state.physical
    physical_point = {round(fx * (pw - 1)), round(fy * (ph - 1))}
    point = Rotation.to_logical(state.rotation, state.physical, physical_point)
    {:noreply, handle_tap(state.screen, point, state)}
  end

  def handle_cast({:rotate, rotation}, %{rotation: rotation} = state), do: {:noreply, state}

  def handle_cast({:rotate, rotation}, state) do
    Logger.info("Rotating the screen to #{rotation}°")

    state =
      %{state | rotation: rotation}
      |> put_size()
      |> restart_automaton()
      |> redraw()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:tick, %{screen: :running} = state) do
    {:noreply, state |> step() |> schedule_tick()}
  end

  def handle_info(:tick, state), do: {:noreply, state}

  def handle_info(:battery, state) do
    Process.send_after(self(), :battery, @battery_ms)
    state = %{state | battery: Battery.info()}
    draw(state, UI.battery(elem(state.size, 0), state.battery))
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    Framebuffer.close(state.fb)
  end

  defp handle_tap(:picker, point, state) do
    case Picker.hit(state.rule, state.size, point) do
      {:rule, rule} ->
        redraw(%{state | rule: rule})

      :start ->
        %{state | screen: :running}
        |> restart_automaton()
        |> redraw()
        |> schedule_tick()

      nil ->
        state
    end
  end

  defp handle_tap(screen, point, state) do
    case Runner.hit(screen, state.size, point) do
      :stop ->
        state = %{state | screen: :paused}
        draw(state, Runner.bar(:paused, state.rule, state.size, state.battery))
        state

      :resume ->
        state = %{state | screen: :running}
        draw(state, Runner.bar(:running, state.rule, state.size, state.battery))
        schedule_tick(state)

      :new_rule ->
        redraw(%{state | screen: :picker, rows: [], count: 0})

      nil ->
        state
    end
  end

  # Add the next generation. Once the area is full, drop the oldest quarter
  # and redraw what's left from the top.
  defp step(state) do
    area = Runner.area(state.size)
    next = Automaton.next(List.last(state.rows), state.rule)

    if state.count < area.rows do
      draw(state, Runner.rows_ops([next], state.count, state.size))
      %{state | rows: state.rows ++ [next], count: state.count + 1}
    else
      rows = Enum.drop(state.rows, max(div(area.rows, 4), 1)) ++ [next]
      count = length(rows)
      draw(state, Runner.rows_ops(rows, 0, state.size) ++ Runner.clear_below(count, state.size))
      %{state | rows: rows, count: count}
    end
  end

  defp restart_automaton(%{screen: :picker} = state), do: state

  defp restart_automaton(state) do
    first = Automaton.initial(Runner.area(state.size).columns)
    %{state | rows: [first], count: 1}
  end

  defp schedule_tick(state) do
    if state.timer, do: Process.cancel_timer(state.timer)
    %{state | timer: Process.send_after(self(), :tick, @tick_ms)}
  end

  defp put_size(state) do
    Map.put(state, :size, Rotation.logical_size(state.rotation, state.physical))
  end

  defp redraw(%{screen: :picker} = state) do
    draw(state, Picker.render(state.rule, state.size, state.battery))
    state
  end

  defp redraw(state) do
    draw(state, Runner.render(state.screen, state.rule, state.rows, state.size, state.battery))
    state
  end

  defp draw(state, ops) do
    writes = Render.writes(ops, state.rotation, state.fb.geometry)

    case Framebuffer.write(state.fb, writes) do
      :ok -> :ok
      {:error, reason} -> Logger.error("Framebuffer write failed: #{inspect(reason)}")
    end
  end
end
