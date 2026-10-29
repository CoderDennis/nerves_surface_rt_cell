defmodule NervesSurfaceRtCell.Font do
  @moduledoc """
  A 5×7 bitmap font with digits, upper case letters and a few symbols

  Lower case letters are drawn in upper case, and other characters as
  spaces. Glyphs are 5 pixels wide with 1 pixel between them, and all
  sizes are multiplied by an integer scale.
  """

  @glyphs %{
    ?0 => ~w(.###. #...# #..## #.#.# ##..# #...# .###.),
    ?1 => ~w(..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.),
    ?2 => ~w(.###. #...# ....# ...#. ..#.. .#... #####),
    ?3 => ~w(##### ...#. ..#.. ...#. ....# #...# .###.),
    ?4 => ~w(...#. ..##. .#.#. #..#. ##### ...#. ...#.),
    ?5 => ~w(##### #.... ####. ....# ....# #...# .###.),
    ?6 => ~w(..##. .#... #.... ####. #...# #...# .###.),
    ?7 => ~w(##### ....# ...#. ..#.. .#... .#... .#...),
    ?8 => ~w(.###. #...# #...# .###. #...# #...# .###.),
    ?9 => ~w(.###. #...# #...# .#### ....# ...#. .##..),
    ?A => ~w(.###. #...# #...# ##### #...# #...# #...#),
    ?B => ~w(####. #...# #...# ####. #...# #...# ####.),
    ?C => ~w(.###. #...# #.... #.... #.... #...# .###.),
    ?D => ~w(###.. #..#. #...# #...# #...# #..#. ###..),
    ?E => ~w(##### #.... #.... ####. #.... #.... #####),
    ?F => ~w(##### #.... #.... ####. #.... #.... #....),
    ?G => ~w(.###. #...# #.... #.### #...# #...# .####),
    ?H => ~w(#...# #...# #...# ##### #...# #...# #...#),
    ?I => ~w(.###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.),
    ?J => ~w(..### ...#. ...#. ...#. ...#. #..#. .##..),
    ?K => ~w(#...# #..#. #.#.. ##... #.#.. #..#. #...#),
    ?L => ~w(#.... #.... #.... #.... #.... #.... #####),
    ?M => ~w(#...# ##.## #.#.# #.#.# #...# #...# #...#),
    ?N => ~w(#...# #...# ##..# #.#.# #..## #...# #...#),
    ?O => ~w(.###. #...# #...# #...# #...# #...# .###.),
    ?P => ~w(####. #...# #...# ####. #.... #.... #....),
    ?Q => ~w(.###. #...# #...# #...# #.#.# #..#. .##.#),
    ?R => ~w(####. #...# #...# ####. #.#.. #..#. #...#),
    ?S => ~w(.#### #.... #.... .###. ....# ....# ####.),
    ?T => ~w(##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..),
    ?U => ~w(#...# #...# #...# #...# #...# #...# .###.),
    ?V => ~w(#...# #...# #...# #...# #...# .#.#. ..#..),
    ?W => ~w(#...# #...# #...# #.#.# #.#.# #.#.# .#.#.),
    ?X => ~w(#...# #...# .#.#. ..#.. .#.#. #...# #...#),
    ?Y => ~w(#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..),
    ?Z => ~w(##### ....# ...#. ..#.. .#... #.... #####),
    ?% => ~w(##... ##..# ...#. ..#.. .#... #..## ...##),
    ?+ => ~w(..... ..#.. ..#.. ##### ..#.. ..#.. .....),
    ?- => ~w(..... ..... ..... ##### ..... ..... .....),
    ?. => ~w(..... ..... ..... ..... ..... .##.. .##..),
    ?: => ~w(..... .##.. .##.. ..... .##.. .##.. .....)
  }

  # Each glyph as a list of {x, y, width} horizontal runs of set pixels
  @runs Map.new(@glyphs, fn {char, rows} ->
          runs =
            for {row, y} <- Enum.with_index(rows),
                {start, len} <- Regex.scan(~r/#+/, row, return: :index) |> List.flatten(),
                do: {start, y, len}

          {char, runs}
        end)

  @glyph_width 5
  @glyph_height 7
  @advance 6

  @doc """
  Width in pixels of `text` at `scale`
  """
  @spec text_width(String.t(), pos_integer()) :: non_neg_integer()
  def text_width(text, scale) do
    case String.length(text) do
      0 -> 0
      n -> ((n - 1) * @advance + @glyph_width) * scale
    end
  end

  @doc """
  Height in pixels of a line of text at `scale`
  """
  @spec text_height(pos_integer()) :: pos_integer()
  def text_height(scale), do: @glyph_height * scale

  @doc """
  The rectangles `{x, y, width, height}` that draw `text` with its top left
  corner at `{x, y}`
  """
  @spec rects(String.t(), integer(), integer(), pos_integer()) :: [
          {integer(), integer(), pos_integer(), pos_integer()}
        ]
  def rects(text, x, y, scale) do
    text
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.flat_map(fn {char, i} ->
      left = x + i * @advance * scale

      for {rx, ry, len} <- Map.get(@runs, char, []) do
        {left + rx * scale, y + ry * scale, len * scale, scale}
      end
    end)
  end
end
