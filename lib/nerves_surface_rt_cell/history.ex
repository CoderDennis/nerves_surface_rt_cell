defmodule NervesSurfaceRtCell.History do
  @moduledoc """
  The automaton's rows and which of them are on screen

  The automaton always runs at one width, wide enough for landscape. A
  view (landscape or portrait) shows rows from `top` on, cropped to the
  middle columns that fit. Rotating the screen only changes the view, so
  the pattern stays.

  The automaton stops once its rows reach the bottom of the view.
  """

  alias NervesSurfaceRtCell.Automaton

  defstruct rows: [], length: 0, top: 0

  @type t() :: %__MODULE__{
          rows: [Automaton.row()],
          length: non_neg_integer(),
          top: non_neg_integer()
        }

  @doc """
  A history that starts with `row`
  """
  @spec new(Automaton.row()) :: t()
  def new(row), do: %__MODULE__{rows: [row], length: 1}

  @doc """
  The newest row
  """
  @spec last(t()) :: Automaton.row()
  def last(history), do: List.last(history.rows)

  @doc """
  Whether the rows fill a view `view_rows` tall
  """
  @spec full?(t(), pos_integer()) :: boolean()
  def full?(history, view_rows), do: history.length - history.top >= view_rows

  @doc """
  Add a row below the others, for a view `view_rows` tall

  Returns `{history, index}` with the new row's index in the view, or
  `:full` if the view has no room for it.
  """
  @spec push(t(), Automaton.row(), pos_integer()) :: {t(), non_neg_integer()} | :full
  def push(history, row, view_rows) do
    if full?(history, view_rows) do
      :full
    else
      history = %{history | rows: history.rows ++ [row], length: history.length + 1}
      {history, history.length - 1 - history.top}
    end
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
end
