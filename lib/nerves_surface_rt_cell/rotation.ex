defmodule NervesSurfaceRtCell.Rotation do
  @moduledoc """
  Maps between logical (as the viewer sees the screen) and physical
  (framebuffer) coordinates

  The rotation is 0, 90, 180 or 270 degrees. At 0 the logical screen is
  the panel's native landscape screen. At 90 and 270 it's portrait, with
  width and height swapped.

  Rectangles stay rectangles under all four rotations, so everything is
  drawn as rectangles, and grids of cells are transposed or flipped as a
  whole.
  """

  @type t() :: 0 | 90 | 180 | 270
  @type size() :: {pos_integer(), pos_integer()}
  @type rect() :: {integer(), integer(), non_neg_integer(), non_neg_integer()}

  @doc """
  The logical screen size for a physical screen size
  """
  @spec logical_size(t(), size()) :: size()
  def logical_size(rotation, {w, h}) when rotation in [0, 180], do: {w, h}
  def logical_size(rotation, {w, h}) when rotation in [90, 270], do: {h, w}

  @doc """
  Map a logical rectangle to a physical one
  """
  @spec to_physical(t(), size(), rect()) :: rect()
  def to_physical(0, _size, rect), do: rect
  def to_physical(180, {pw, ph}, {x, y, w, h}), do: {pw - x - w, ph - y - h, w, h}
  def to_physical(90, {_pw, ph}, {x, y, w, h}), do: {y, ph - x - w, h, w}
  def to_physical(270, {pw, _ph}, {x, y, w, h}), do: {pw - y - h, x, h, w}

  @doc """
  Map a physical point, e.g. a touch, to a logical one
  """
  @spec to_logical(t(), size(), {integer(), integer()}) :: {integer(), integer()}
  def to_logical(0, _size, point), do: point
  def to_logical(180, {pw, ph}, {px, py}), do: {pw - 1 - px, ph - 1 - py}
  def to_logical(90, {_pw, ph}, {px, py}), do: {ph - 1 - py, px}
  def to_logical(270, {pw, _ph}, {px, py}), do: {py, pw - 1 - px}

  @doc """
  Turn a grid of logical rows (top to bottom, each left to right) into
  physical rows
  """
  @spec grid(t(), [[term()]]) :: [[term()]]
  def grid(0, rows), do: rows
  def grid(180, rows), do: rows |> Enum.reverse() |> Enum.map(&Enum.reverse/1)
  def grid(90, rows), do: rows |> transpose() |> Enum.reverse()
  def grid(270, rows), do: rows |> transpose() |> Enum.map(&Enum.reverse/1)

  defp transpose([]), do: []
  defp transpose(rows), do: rows |> Enum.zip() |> Enum.map(&Tuple.to_list/1)
end
