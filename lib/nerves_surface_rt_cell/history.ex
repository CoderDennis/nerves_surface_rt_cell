defmodule NervesSurfaceRtCell.History do
  @moduledoc """
  The automaton's recent rows and which of them are on screen

  The automaton always runs at one width, wide enough for landscape, and
  keeps enough rows to fill the tallest view. A view (landscape or
  portrait) shows rows from `top` on, cropped to the middle columns that
  fit. Rotating the screen only changes the view, so the pattern stays.

  Once the rows reach the bottom of the view, it scrolls up a quarter of
  the view at a time.
  """

  alias NervesSurfaceRtCell.Automaton

  defstruct rows: [], length: 0, capacity: 1, top: 0

  @type t() :: %__MODULE__{
          rows: [Automaton.row()],
          length: non_neg_integer(),
          capacity: pos_integer(),
          top: non_neg_integer()
        }

  @doc """
  A history that starts with `row` and keeps up to `capacity` rows
  """
  @spec new(Automaton.row(), pos_integer()) :: t()
  def new(row, capacity), do: %__MODULE__{rows: [row], length: 1, capacity: capacity}

  @doc """
  The newest row
  """
  @spec last(t()) :: Automaton.row()
  def last(history), do: List.last(history.rows)

  @doc """
  Add a row, for a view `view_rows` tall

  Returns `{:append, index}` when the new row fits below the others (at
  `index` in the view), or `:redraw` when the view scrolled.
  """
  @spec push(t(), Automaton.row(), pos_integer()) :: {t(), {:append, non_neg_integer()} | :redraw}
  def push(history, row, view_rows) do
    history = %{history | rows: history.rows ++ [row], length: history.length + 1}

    {history, result} =
      if history.length - history.top <= view_rows do
        {history, {:append, history.length - 1 - history.top}}
      else
        {%{history | top: history.top + max(div(view_rows, 4), 1)}, :redraw}
      end

    {trim(history), result}
  end

  @doc """
  Show the newest rows that fill a view `view_rows` tall, e.g. after rotating
  """
  @spec reframe(t(), pos_integer()) :: t()
  def reframe(history, view_rows), do: %{history | top: max(history.length - view_rows, 0)}

  @doc """
  The rows in view, cropped to the middle `columns`
  """
  @spec visible(t(), pos_integer(), pos_integer()) :: [Automaton.row()]
  def visible(history, view_rows, columns) do
    history.rows
    |> Enum.slice(history.top, view_rows)
    |> Enum.map(&crop(&1, columns))
  end

  @doc """
  The row at `index` in the view, cropped to the middle `columns`
  """
  @spec row(t(), non_neg_integer(), pos_integer()) :: Automaton.row()
  def row(history, index, columns),
    do: history.rows |> Enum.at(history.top + index) |> crop(columns)

  defp crop(row, columns) do
    case length(row) - columns do
      extra when extra > 0 -> Enum.slice(row, div(extra, 2), columns)
      _ -> row
    end
  end

  defp trim(%{length: length, capacity: capacity} = history) when length > capacity do
    drop = length - capacity

    %{
      history
      | rows: Enum.drop(history.rows, drop),
        length: capacity,
        top: max(history.top - drop, 0)
    }
  end

  defp trim(history), do: history
end
