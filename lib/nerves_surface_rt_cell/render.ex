defmodule NervesSurfaceRtCell.Render do
  @moduledoc """
  Turns drawing operations in logical coordinates into framebuffer writes

  The result is a list of `{byte_offset, iodata}` for `:file.pwrite/2`, one
  per physical pixel row of each operation. Operations:

    * `{:rect, x, y, w, h, color}` fills a rectangle
    * `{:text, x, y, scale, text, color}` draws text in `NervesSurfaceRtCell.Font`
    * `{:cells, x, y, size, rows}` draws rows of automaton cells, each a
      `size`×`size` square, white for 1 and black for 0

  Colors are `{r, g, b}`. Operations are clipped to the screen.
  """

  alias NervesSurfaceRtCell.Font
  alias NervesSurfaceRtCell.Rotation

  @black {0, 0, 0}
  @white {255, 255, 255}

  @typedoc """
  Framebuffer geometry: visible size in pixels, bytes per row and bits per pixel
  """
  @type geometry() :: %{
          width: pos_integer(),
          height: pos_integer(),
          stride: pos_integer(),
          bpp: 16 | 32
        }

  @type color() :: {byte(), byte(), byte()}
  @type op() ::
          {:rect, integer(), integer(), integer(), integer(), color()}
          | {:text, integer(), integer(), pos_integer(), String.t(), color()}
          | {:cells, integer(), integer(), pos_integer(), [[0 | 1]]}

  @spec black() :: color()
  def black(), do: @black

  @spec white() :: color()
  def white(), do: @white

  @doc """
  Framebuffer writes for `ops`, drawn in order
  """
  @spec writes([op()], Rotation.t(), geometry()) :: [{non_neg_integer(), iodata()}]
  def writes(ops, rotation, geometry) do
    Enum.flat_map(ops, &op_writes(&1, rotation, geometry))
  end

  defp op_writes({:rect, x, y, w, h, color}, rotation, geometry) do
    rect_writes({x, y, w, h}, color, rotation, geometry)
  end

  defp op_writes({:text, x, y, scale, text, color}, rotation, geometry) do
    text
    |> Font.rects(x, y, scale)
    |> Enum.flat_map(&rect_writes(&1, color, rotation, geometry))
  end

  defp op_writes({:cells, _x, _y, _size, []}, _rotation, _geometry), do: []

  defp op_writes({:cells, x, y, size, [first | _] = rows}, rotation, geometry) do
    physical = {geometry.width, geometry.height}
    block = {x, y, length(first) * size, length(rows) * size}
    {px, py, _w, _h} = Rotation.to_physical(rotation, physical, block)
    white = :binary.copy(pixel(@white, geometry.bpp), size)
    black = :binary.copy(pixel(@black, geometry.bpp), size)
    bytes = div(geometry.bpp, 8)

    rotation
    |> Rotation.grid(rows)
    |> Enum.with_index()
    |> Enum.flat_map(fn {cells, r} ->
      line = for cell <- cells, into: <<>>, do: if(cell == 1, do: white, else: black)

      for i <- 0..(size - 1) do
        {(py + r * size + i) * geometry.stride + px * bytes, line}
      end
    end)
  end

  defp rect_writes(rect, color, rotation, geometry) do
    physical = {geometry.width, geometry.height}
    logical = Rotation.logical_size(rotation, physical)

    case clip(rect, logical) do
      nil ->
        []

      clipped ->
        {px, py, w, h} = Rotation.to_physical(rotation, physical, clipped)
        line = :binary.copy(pixel(color, geometry.bpp), w)
        bytes = div(geometry.bpp, 8)
        for row <- py..(py + h - 1), do: {row * geometry.stride + px * bytes, line}
    end
  end

  defp clip({x, y, w, h}, {sw, sh}) do
    x1 = max(x, 0)
    y1 = max(y, 0)
    x2 = min(x + w, sw)
    y2 = min(y + h, sh)
    if x2 > x1 and y2 > y1, do: {x1, y1, x2 - x1, y2 - y1}
  end

  @doc """
  One pixel in the framebuffer's format (XRGB8888 or RGB565, little endian)
  """
  @spec pixel(color(), 16 | 32) :: binary()
  def pixel({r, g, b}, 32), do: <<b, g, r, 0>>

  def pixel({r, g, b}, 16) do
    <<value::16>> = <<div(r, 8)::5, div(g, 4)::6, div(b, 8)::5>>
    <<value::little-16>>
  end
end
