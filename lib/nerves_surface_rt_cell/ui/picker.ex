defmodule NervesSurfaceRtCell.UI.Picker do
  @moduledoc """
  The rule picker screen

  Shows the rule number with − and + buttons, Wolfram's rule icon (the 8
  neighborhoods, 111 to 000, each with its output cell below it), a row of
  preset rules and a Start button. Tapping a neighborhood flips its output
  bit.
  """

  alias NervesSurfaceRtCell.Automaton
  alias NervesSurfaceRtCell.Font
  alias NervesSurfaceRtCell.UI

  @presets [30, 90, 110, 184]
  @number_scale 8
  @cell 36
  @cell_gap 4
  @slot_width 160
  @slot_height 2 * @cell + 20 + 16
  @number_height 120
  @presets_height 90
  @start_height 110

  @type action() :: {:rule, Automaton.rule()} | :start | nil

  @doc """
  Draw the whole screen
  """
  @spec render(Automaton.rule(), {pos_integer(), pos_integer()}, map() | nil) :: [
          NervesSurfaceRtCell.Render.op()
        ]
  def render(rule, {w, h} = size, battery) do
    layout = layout(size)
    {nx, ny, nw, nh} = layout.number
    label = "RULE #{rule}"

    [{:rect, 0, 0, w, h, UI.black()}] ++
      UI.bar(w, "CELLULAR AUTOMATA") ++
      UI.battery(w, battery) ++
      UI.button(layout.minus, "-", scale: 6) ++
      UI.button(layout.plus, "+", scale: 6) ++
      [
        {:text, nx + div(nw - Font.text_width(label, @number_scale), 2),
         ny + div(nh - Font.text_height(@number_scale), 2), @number_scale, label, UI.white()}
      ] ++
      Enum.flat_map(layout.slots, fn {index, rect} -> slot(rule, index, rect) end) ++
      Enum.flat_map(layout.presets, fn {n, rect} ->
        UI.button(rect, "#{n}", scale: 4, selected: n == rule)
      end) ++
      UI.button(layout.start, "START", scale: 6, selected: true)
  end

  # A neighborhood's three cells, with its output cell centered below them
  defp slot(rule, index, {x, y, w, _h}) do
    row_width = 3 * @cell + 2 * @cell_gap
    left = x + div(w - row_width, 2)
    top = y + 8

    neighborhood =
      for bit <- 0..2 do
        value = Bitwise.band(Bitwise.bsr(index, 2 - bit), 1)
        cell({left + bit * (@cell + @cell_gap), top, @cell, @cell}, value)
      end

    output = Bitwise.band(Bitwise.bsr(rule, index), 1)
    out_rect = {left + @cell + @cell_gap, top + @cell + 20, @cell, @cell}
    List.flatten(neighborhood) ++ cell(out_rect, output, UI.accent())
  end

  defp cell(rect, value, outline_color \\ UI.grey())
  defp cell({x, y, w, h}, 1, _outline_color), do: [{:rect, x, y, w, h, UI.white()}]
  defp cell(rect, 0, outline_color), do: UI.outline(rect, 3, outline_color)

  @doc """
  What tapping `point` does
  """
  @spec hit(Automaton.rule(), {pos_integer(), pos_integer()}, {integer(), integer()}) ::
          action()
  def hit(rule, size, point) do
    layout = layout(size)

    cond do
      UI.inside?(layout.minus, point) ->
        {:rule, Integer.mod(rule - 1, 256)}

      UI.inside?(layout.plus, point) ->
        {:rule, Integer.mod(rule + 1, 256)}

      UI.inside?(layout.start, point) ->
        :start

      slot = Enum.find(layout.slots, fn {_i, rect} -> UI.inside?(rect, point) end) ->
        {:rule, Automaton.toggle(rule, elem(slot, 0))}

      preset = Enum.find(layout.presets, fn {_n, rect} -> UI.inside?(rect, point) end) ->
        {:rule, elem(preset, 0)}

      true ->
        nil
    end
  end

  @doc """
  The screen's layout for a logical screen size

  One row of 8 neighborhoods in landscape, two rows of 4 in portrait. The
  space left over is spread evenly between the sections.
  """
  @spec layout({pos_integer(), pos_integer()}) :: map()
  def layout({w, h}) do
    per_row = if w >= 8 * @slot_width + 40, do: 8, else: 4
    slot_rows = div(8, per_row)
    slots_height = slot_rows * @slot_height
    content = @number_height + slots_height + @presets_height + @start_height
    gap = max(div(h - UI.bar_height() - content, 5), 8)

    number_y = UI.bar_height() + gap
    slots_y = number_y + @number_height + gap
    presets_y = slots_y + slots_height + gap
    start_y = presets_y + @presets_height + gap

    side = @number_height
    number_w = min(w - 2 * (side + 40), 600)
    number_x = div(w - number_w, 2)

    slot_w = min(@slot_width, div(w - 40, per_row))
    slots_x = div(w - per_row * slot_w, 2)

    # Wolfram's order: 111 on the left, 000 on the right
    slots =
      for i <- 0..7 do
        index = 7 - i

        {index,
         {slots_x + rem(i, per_row) * slot_w, slots_y + div(i, per_row) * @slot_height, slot_w,
          @slot_height}}
      end

    preset_w = 140
    preset_gap = 24
    presets_x = div(w - (length(@presets) * (preset_w + preset_gap) - preset_gap), 2)

    presets =
      for {n, i} <- Enum.with_index(@presets) do
        {n, {presets_x + i * (preset_w + preset_gap), presets_y, preset_w, @presets_height}}
      end

    start_w = min(420, w - 80)

    %{
      number: {number_x, number_y, number_w, @number_height},
      minus: {number_x - side - 20, number_y, side, @number_height},
      plus: {number_x + number_w + 20, number_y, side, @number_height},
      slots: slots,
      presets: presets,
      start: {div(w - start_w, 2), start_y, start_w, @start_height}
    }
  end
end
