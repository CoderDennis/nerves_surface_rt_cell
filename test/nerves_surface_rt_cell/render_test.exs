defmodule NervesSurfaceRtCell.RenderTest do
  use ExUnit.Case, async: true

  alias NervesSurfaceRtCell.Font
  alias NervesSurfaceRtCell.Render
  alias NervesSurfaceRtCell.Rotation

  # A small 32 bpp framebuffer with padding at the end of each row
  @geometry %{width: 6, height: 4, stride: 6 * 4 + 8, bpp: 32}

  # Apply writes to a black framebuffer and return its pixels as rows of
  # "#" (white) and "." (anything else)
  defp screen(ops, rotation) do
    size = @geometry.stride * @geometry.height

    buffer =
      ops
      |> Render.writes(rotation, @geometry)
      |> Enum.reduce(:binary.copy(<<0>>, size), fn {offset, data}, buffer ->
        data = IO.iodata_to_binary(data)
        len = byte_size(data)
        <<before::binary-size(^offset), _::binary-size(^len), rest::binary>> = buffer
        <<before::binary, data::binary, rest::binary>>
      end)

    for y <- 0..(@geometry.height - 1) do
      for x <- 0..(@geometry.width - 1), into: "" do
        case binary_part(buffer, y * @geometry.stride + x * 4, 4) do
          <<255, 255, 255, 0>> -> "#"
          _ -> "."
        end
      end
    end
  end

  test "rect at each rotation" do
    rect = [{:rect, 0, 0, 2, 1, Render.white()}]

    assert screen(rect, 0) == ["##....", "......", "......", "......"]
    assert screen(rect, 180) == ["......", "......", "......", "....##"]
    # Portrait: logical 4×6, logical top left is physical bottom left
    assert screen(rect, 90) == ["......", "......", "#.....", "#....."]
    assert screen(rect, 270) == [".....#", ".....#", "......", "......"]
  end

  test "rects are clipped to the screen" do
    assert screen([{:rect, 4, 3, 10, 10, Render.white()}], 0) ==
             ["......", "......", "......", "....##"]

    assert screen([{:rect, 10, 10, 2, 2, Render.white()}], 0) ==
             ["......", "......", "......", "......"]
  end

  test "cells match rects at every rotation" do
    rows = [[1, 0, 1], [0, 1, 1]]

    rects =
      for {row, y} <- Enum.with_index(rows), {1, x} <- Enum.with_index(row) do
        {:rect, 1 + x, 1 + y, 1, 1, Render.white()}
      end

    for rotation <- [0, 90, 180, 270] do
      assert screen([{:cells, 1, 1, 1, rows}], rotation) == screen(rects, rotation),
             "rotation #{rotation}"
    end
  end

  test "cells are size×size squares" do
    assert screen([{:cells, 0, 0, 2, [[1, 0, 1]]}], 0) ==
             ["##..##", "##..##", "......", "......"]
  end

  test "points map back from physical to logical" do
    size = {1366, 768}

    for rotation <- [0, 90, 180, 270], {x, y} <- [{0, 0}, {10, 20}, {700, 300}] do
      {lw, lh} = Rotation.logical_size(rotation, size)
      assert x < lw and y < lh
      {px, py, 1, 1} = Rotation.to_physical(rotation, size, {x, y, 1, 1})
      assert Rotation.to_logical(rotation, size, {px, py}) == {x, y}
    end
  end

  test "16 bpp pixels are RGB565" do
    assert Render.pixel({255, 255, 255}, 16) == <<0xFF, 0xFF>>
    assert Render.pixel({255, 0, 0}, 16) == <<0x00, 0xF8>>
  end

  test "font" do
    assert Font.text_width("", 2) == 0
    assert Font.text_width("AB", 1) == 11
    assert Font.text_height(3) == 21
    # "-" is a single run 5 wide on the middle row
    assert Font.rects("-", 10, 20, 2) == [{10, 26, 10, 2}]
    assert Font.rects("a", 0, 0, 1) == Font.rects("A", 0, 0, 1)
  end
end
