defmodule NervesSurfaceRtCell.Automaton do
  @moduledoc """
  Wolfram's elementary cellular automata

  A row is a list of cells, each 0 or 1. The cells beyond both ends are
  always 0. Bit `n` of the rule (0-255) is the next state of a cell whose
  left neighbor, the cell itself and its right neighbor spell `n` in
  binary, so rule 30 (`0b00011110`) turns `100`, `011`, `010` and `001`
  into 1.
  """

  @type cell() :: 0 | 1
  @type row() :: [cell()]
  @type rule() :: 0..255

  @doc """
  A row of `width` cells with a single 1 in the middle
  """
  @spec initial(pos_integer()) :: row()
  def initial(width) do
    middle = div(width, 2)
    for i <- 0..(width - 1), do: if(i == middle, do: 1, else: 0)
  end

  @doc """
  The row that follows `row` under `rule`
  """
  @spec next(row(), rule()) :: row()
  def next(row, rule) do
    next(0, row, rule, [])
  end

  defp next(left, [center, right | rest], rule, acc) do
    next(center, [right | rest], rule, [output(rule, left, center, right) | acc])
  end

  defp next(left, [center], rule, acc) do
    Enum.reverse([output(rule, left, center, 0) | acc])
  end

  defp next(_left, [], _rule, acc), do: Enum.reverse(acc)

  @doc """
  The next state of a cell with the given neighborhood under `rule`
  """
  @spec output(rule(), cell(), cell(), cell()) :: cell()
  def output(rule, left, center, right) do
    Bitwise.band(Bitwise.bsr(rule, left * 4 + center * 2 + right), 1)
  end

  @doc """
  Flip the output bit for neighborhood `index` (0-7) of `rule`
  """
  @spec toggle(rule(), 0..7) :: rule()
  def toggle(rule, index) do
    Bitwise.bxor(rule, Bitwise.bsl(1, index))
  end
end
