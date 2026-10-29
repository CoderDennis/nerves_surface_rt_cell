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

    [{:rect, 0, 0, w, h, UI.black()}] ++
      UI.bar(w, "CELLULAR AUTOMATA") ++
      UI.battery(w, battery) ++
      UI.button(layout.minus, "-", scale: 6) ++
      UI.button(layout.plus, "+", scale: 6) ++
      number(rule, layout) ++
      Enum.flat_map(layout.slots, fn {index, rect} ->
        neighborhood(index, rect) ++ output(rule, index, rect)
      end) ++
      Enum.flat_map(layout.presets, &preset(rule, &1)) ++
      UI.button(layout.start, "START", scale: 6, selected: true)
  end

  @doc """
  Draw only what changes between rule `old` and rule `new`: the number,
  the output cells that flip and the presets that change highlight
  """
  @spec update(Automaton.rule(), Automaton.rule(), {pos_integer(), pos_integer()}) :: [
          NervesSurfaceRtCell.Render.op()
        ]
  def update(old, new, size) do
    layout = layout(size)
    {x, y, w, h} = layout.number

    outputs =
      for {index, rect} <- layout.slots,
          Bitwise.band(Bitwise.bsr(Bitwise.bxor(old, new), index), 1) == 1,
          do: output(new, index, rect)

    presets =
      for {n, _rect} = preset <- layout.presets, n == old != (n == new), do: preset(new, preset)

    [{:rect, x, y, w, h, UI.black()}] ++
      number(new, layout) ++ List.flatten(outputs) ++ List.flatten(presets)
  end

  defp number(rule, layout) do
    {x, y, w, h} = layout.number
    label = "RULE #{rule}"

    [
      {:text, x + div(w - Font.text_width(label, @number_scale), 2),
       y + div(h - Font.text_height(@number_scale), 2), @number_scale, label, UI.white()}
    ]
  end

  defp preset(rule, {n, rect}), do: UI.button(rect, "#{n}", scale: 4, selected: n == rule)

  # A neighborhood's three cells, centered at the top of its slot
  defp neighborhood(index, rect) do
    {left, top} = slot_origin(rect)

    Enum.flat_map(0..2, fn bit ->
      value = Bitwise.band(Bitwise.bsr(index, 2 - bit), 1)
      cell({left + bit * (@cell + @cell_gap), top, @cell, @cell}, value)
    end)
  end

  # The output cell below the middle of the neighborhood, cleared first so
  # that a 1 can turn into an outlined 0
  defp output(rule, index, rect) do
    {left, top} = slot_origin(rect)
    {x, y, w, h} = out_rect = {left + @cell + @cell_gap, top + @cell + 20, @cell, @cell}
    value = Bitwise.band(Bitwise.bsr(rule, index), 1)
    [{:rect, x, y, w, h, UI.black()} | cell(out_rect, value, UI.accent())]
  end

  defp slot_origin({x, y, w, _h}) do
    {x + div(w - (3 * @cell + 2 * @cell_gap), 2), y + 8}
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
