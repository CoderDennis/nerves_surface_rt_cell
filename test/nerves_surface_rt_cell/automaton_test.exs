defmodule NervesSurfaceRtCell.AutomatonTest do
  use ExUnit.Case, async: true

  alias NervesSurfaceRtCell.Automaton

  defp run(rule, width, generations) do
    width
    |> Automaton.initial()
    |> Stream.iterate(&Automaton.next(&1, rule))
    |> Enum.take(generations)
    |> Enum.map(fn row -> Enum.map_join(row, &if(&1 == 1, do: "#", else: ".")) end)
  end

  test "initial row has one cell in the middle" do
    assert Automaton.initial(5) == [0, 0, 1, 0, 0]
    assert Automaton.initial(1) == [1]
  end

  test "rule 90 draws a Sierpinski triangle" do
    assert run(90, 9, 4) == [
             "....#....",
             "...#.#...",
             "..#...#..",
             ".#.#.#.#."
           ]
  end

  test "rule 30" do
    assert run(30, 9, 4) == [
             "....#....",
             "...###...",
             "..##..#..",
             ".##.####."
           ]
  end

  test "rule 0 clears and rule 255 fills" do
    assert run(0, 5, 2) == ["..#..", "....."]
    assert run(255, 5, 2) == ["..#..", "#####"]
  end

  test "cells beyond the edges are 0" do
    # Rule 2 shifts the single cell left until it falls off
    assert run(2, 3, 3) == [".#.", "#..", "..."]
  end

  test "toggle flips one output bit" do
    assert Automaton.toggle(30, 0) == 31
    assert Automaton.toggle(30, 4) == 14
    assert Automaton.output(30, 1, 0, 0) == 1
    assert Automaton.output(30, 1, 1, 1) == 0
  end
end
