defmodule NervesSurfaceRtCell.UI.Runner do
  @moduledoc """
  The screen that runs an automaton

  The top bar shows the rule and a Stop button, or Resume and New rule
  while stopped. The rest of the screen is the automaton, one row per
  generation, white cells on black.
  """

  alias NervesSurfaceRtCell.UI

  @cell 4

  @type status() :: :running | :paused
  @type action() :: :stop | :resume | :new_rule | nil

  @doc """
  The automaton's area: `{x, y, columns, rows}` and the cell size

  The columns are centered horizontally.
  """
  @spec area({pos_integer(), pos_integer()}) :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          columns: pos_integer(),
          rows: pos_integer(),
          cell: pos_integer()
        }
  def area({w, h}) do
    columns = div(w, @cell)

    %{
      x: div(w - columns * @cell, 2),
      y: UI.bar_height(),
      columns: columns,
      rows: div(h - UI.bar_height(), @cell),
      cell: @cell
    }
  end

  @doc """
  Draw the whole screen, with `rows` of the automaton from the top
  """
  @spec render(status(), 0..255, [[0 | 1]], {pos_integer(), pos_integer()}, map() | nil) ::
          [NervesSurfaceRtCell.Render.op()]
  def render(status, rule, rows, {w, h} = size, battery) do
    [{:rect, 0, 0, w, h, UI.black()}] ++
      bar(status, rule, size, battery) ++
      rows_ops(rows, 0, size)
  end

  @doc """
  Draw the top bar
  """
  @spec bar(status(), 0..255, {pos_integer(), pos_integer()}, map() | nil) ::
          [NervesSurfaceRtCell.Render.op()]
  def bar(status, rule, {w, _h}, battery) do
    UI.bar(w, "RULE #{rule}") ++
      UI.battery(w, battery) ++
      Enum.flat_map(buttons(status, w), fn {id, rect} -> UI.button(rect, label(id)) end)
  end

  @doc """
  Draw `rows` of the automaton, starting at generation row `first` of the area
  """
  @spec rows_ops([[0 | 1]], non_neg_integer(), {pos_integer(), pos_integer()}) ::
          [NervesSurfaceRtCell.Render.op()]
  def rows_ops([], _first, _size), do: []

  def rows_ops(rows, first, size) do
    area = area(size)
    [{:cells, area.x, area.y + first * area.cell, area.cell, rows}]
  end

  @doc """
  Clear the area below generation row `first`
  """
  @spec clear_below(non_neg_integer(), {pos_integer(), pos_integer()}) ::
          [NervesSurfaceRtCell.Render.op()]
  def clear_below(first, {w, h} = size) do
    area = area(size)
    y = area.y + first * area.cell
    [{:rect, 0, y, w, h - y, UI.black()}]
  end

  @doc """
  What tapping `point` does

  Besides the buttons, tapping the automaton stops it, or resumes it while
  stopped.
  """
  @spec hit(status(), {pos_integer(), pos_integer()}, {integer(), integer()}) :: action()
  def hit(status, {w, _h}, {_x, y} = point) do
    button =
      Enum.find_value(buttons(status, w), fn {id, rect} -> UI.inside?(rect, point) && id end)

    cond do
      button -> button
      y < UI.bar_height() -> nil
      status == :running -> :stop
      status == :paused -> :resume
    end
  end

  defp buttons(:running, w), do: UI.bar_buttons(w, [{:stop, label(:stop)}])

  defp buttons(:paused, w),
    do: UI.bar_buttons(w, [{:new_rule, label(:new_rule)}, {:resume, label(:resume)}])

  defp label(:stop), do: "STOP"
  defp label(:resume), do: "RESUME"
  defp label(:new_rule), do: "NEW RULE"
end
