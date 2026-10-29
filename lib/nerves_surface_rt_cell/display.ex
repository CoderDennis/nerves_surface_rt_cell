defmodule NervesSurfaceRtCell.Display do
  @moduledoc """
  The app's screens and the only process that draws on the framebuffer

  Screens:

    * `:picker` - choose a rule (`NervesSurfaceRtCell.UI.Picker`)
    * `:running` - the automaton grows one row per tick until it reaches
      the bottom of the screen. Rotating the screen keeps the pattern (see
      `NervesSurfaceRtCell.History`).
    * `:paused` - stopped, by Stop or at the bottom of the screen. It has
      Resume and New rule buttons, or only New rule while the screen is
      full. Turning to portrait makes room to resume.

  `NervesSurfaceRtCell.Touch` sends taps and `NervesSurfaceRtCell.Orientation`
  sends rotations. The battery indicator is refreshed every 30 seconds.
  """
  use GenServer

  require Logger

  alias NervesSurfaceRtCell.Automaton
  alias NervesSurfaceRtCell.Battery
  alias NervesSurfaceRtCell.Framebuffer
  alias NervesSurfaceRtCell.History
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
            history: nil,
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
      |> reframe()
      |> redraw()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:tick, %{screen: :running} = state) do
    {:noreply, step(state)}
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
        draw(state, Picker.update(state.rule, rule, state.size))
        %{state | rule: rule}

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
    case Runner.hit(status(screen, state), state.size, point) do
      :stop ->
        pause(state)

      :resume ->
        state = %{state | screen: :running}
        draw(state, Runner.bar(:running, state.rule, state.size, state.battery))
        schedule_tick(state)

      :new_rule ->
        redraw(%{state | screen: :picker, history: nil})

      nil ->
        state
    end
  end

  # Add the next generation below the others, or stop at the bottom
  defp step(state) do
    area = Runner.area(state.size)
    next = Automaton.next(History.last(state.history), state.rule)

    case History.push(state.history, next, area.rows) do
      {history, index} ->
        row = History.row(history, index, area.columns)
        draw(state, Runner.rows_ops([row], index, state.size))
        schedule_tick(%{state | history: history})

      :full ->
        pause(state)
    end
  end

  defp pause(state) do
    state = %{state | screen: :paused}
    draw(state, Runner.bar(status(:paused, state), state.rule, state.size, state.battery))
    state
  end

  # A stopped automaton that fills the screen can't resume
  defp status(:paused, state) do
    if History.full?(state.history, Runner.area(state.size).rows), do: :finished, else: :paused
  end

  defp status(screen, _state), do: screen

  # The automaton is as wide as the widest view, so it fits both landscape
  # and portrait
  defp restart_automaton(state) do
    landscape = Runner.area(Rotation.logical_size(0, state.physical))
    portrait = Runner.area(Rotation.logical_size(90, state.physical))
    first = Automaton.initial(max(landscape.columns, portrait.columns))
    %{state | history: History.new(first)}
  end

  defp reframe(%{history: nil} = state), do: state

  defp reframe(state) do
    %{state | history: History.reframe(state.history, Runner.area(state.size).rows)}
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
    area = Runner.area(state.size)
    rows = History.visible(state.history, area.rows, area.columns)
    status = status(state.screen, state)
    draw(state, Runner.render(status, state.rule, rows, state.size, state.battery))
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
