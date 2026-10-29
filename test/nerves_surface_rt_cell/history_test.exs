defmodule NervesSurfaceRtCell.HistoryTest do
  use ExUnit.Case, async: true

  alias NervesSurfaceRtCell.History

  # Rows are [n] so they're easy to tell apart
  defp history(count, view_rows) do
    Enum.reduce(2..count//1, History.new([1]), fn n, history ->
      {history, _index} = History.push(history, [n], view_rows)
      history
    end)
  end

  defp visible(history, view_rows), do: history |> History.visible(view_rows, 1) |> List.flatten()

  test "appends until the view is full, then stops" do
    history = history(7, 8)
    refute History.full?(history, 8)

    assert {history, 7} = History.push(history, [8], 8)
    assert History.full?(history, 8)
    assert visible(history, 8) == Enum.to_list(1..8)

    assert History.push(history, [9], 8) == :full
  end

  test "reframe shows the newest rows of a different view" do
    # Portrait (12 rows) to landscape (8 rows) and back
    history = history(12, 12)
    assert visible(history, 12) == Enum.to_list(1..12)

    landscape = History.reframe(history, 8)
    assert visible(landscape, 8) == Enum.to_list(5..12)
    assert History.full?(landscape, 8)

    portrait = History.reframe(landscape, 12)
    assert visible(portrait, 12) == Enum.to_list(1..12)
    assert History.full?(portrait, 12)
  end

  test "turning to a taller view makes room to continue" do
    history = history(8, 8) |> History.reframe(12)
    refute History.full?(history, 12)
    assert {_history, 8} = History.push(history, [9], 12)
  end

  test "crops rows to the middle columns" do
    history = History.new([1, 2, 3, 4, 5, 6, 7])
    assert History.visible(history, 4, 3) == [[3, 4, 5]]
    assert History.row(history, 0, 7) == [1, 2, 3, 4, 5, 6, 7]
    assert History.row(history, 0, 10) == [1, 2, 3, 4, 5, 6, 7]
  end
end
