defmodule NervesSurfaceRtCell.HistoryTest do
  use ExUnit.Case, async: true

  alias NervesSurfaceRtCell.History

  # Rows are [n] so they're easy to tell apart
  defp history(count, capacity, view_rows) do
    Enum.reduce(2..count//1, History.new([1], capacity), fn n, history ->
      {history, _} = History.push(history, [n], view_rows)
      history
    end)
  end

  defp visible(history, view_rows), do: history |> History.visible(view_rows, 1) |> List.flatten()

  test "appends until the view is full, then scrolls a quarter" do
    history = history(8, 20, 8)
    assert visible(history, 8) == Enum.to_list(1..8)

    assert {history, :redraw} = History.push(history, [9], 8)
    assert visible(history, 8) == Enum.to_list(3..9)

    assert {_history, {:append, 7}} = History.push(history, [10], 8)
  end

  test "keeps at most capacity rows" do
    history = history(30, 12, 8)
    assert history.length == 12
    assert List.flatten(history.rows) == Enum.to_list(19..30)
    assert visible(history, 8) |> List.last() == 30
  end

  test "reframe shows the newest rows of a different view" do
    # Portrait (12 rows) to landscape (8 rows) and back
    history = history(12, 12, 12)
    assert visible(history, 12) == Enum.to_list(1..12)

    landscape = History.reframe(history, 8)
    assert visible(landscape, 8) == Enum.to_list(5..12)

    assert visible(History.reframe(landscape, 12), 12) == Enum.to_list(1..12)
  end

  test "crops rows to the middle columns" do
    history = History.new([1, 2, 3, 4, 5, 6, 7], 4)
    assert History.visible(history, 4, 3) == [[3, 4, 5]]
    assert History.row(history, 0, 7) == [1, 2, 3, 4, 5, 6, 7]
    assert History.row(history, 0, 10) == [1, 2, 3, 4, 5, 6, 7]
  end
end
