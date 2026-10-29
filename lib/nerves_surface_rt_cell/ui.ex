defmodule NervesSurfaceRtCell.UI do
  @moduledoc """
  Shared screen elements: the top bar, buttons and the battery indicator

  Everything here returns `NervesSurfaceRtCell.Render` operations in
  logical coordinates.
  """

  alias NervesSurfaceRtCell.Font

  @bar_height 64
  @bar_color {24, 24, 24}
  @button_color {64, 64, 64}
  @accent {255, 170, 0}
  @grey {110, 110, 110}
  @low {230, 50, 50}
  @white {255, 255, 255}
  @black {0, 0, 0}

  @label_scale 3
  @button_padding 16
  @battery_width 170

  @type rect() :: {integer(), integer(), pos_integer(), pos_integer()}

  def bar_height(), do: @bar_height
  def accent(), do: @accent
  def grey(), do: @grey
  def white(), do: @white
  def black(), do: @black

  @doc """
  Whether `point` is inside `rect`
  """
  @spec inside?(rect(), {integer(), integer()}) :: boolean()
  def inside?({x, y, w, h}, {px, py}), do: px >= x and px < x + w and py >= y and py < y + h

  @doc """
  The top bar's background with `title` on the left
  """
  @spec bar(pos_integer(), String.t()) :: [NervesSurfaceRtCell.Render.op()]
  def bar(width, title) do
    [
      {:rect, 0, 0, width, @bar_height, @bar_color},
      {:text, 16, div(@bar_height - Font.text_height(@label_scale), 2), @label_scale, title,
       @white}
    ]
  end

  @doc """
  Buttons in the top bar, laid out from the right edge (left of the battery)

  Returns `[{id, rect}]`.
  """
  @spec bar_buttons(pos_integer(), [{atom(), String.t()}]) :: [{atom(), rect()}]
  def bar_buttons(width, buttons) do
    {laid_out, _x} =
      buttons
      |> Enum.reverse()
      |> Enum.map_reduce(width - @battery_width - 16, fn {id, label}, right ->
        w = button_width(label, @label_scale)
        {{id, {right - w, 8, w, @bar_height - 16}}, right - w - 12}
      end)

    Enum.reverse(laid_out)
  end

  @doc """
  Width of a button that fits `label` at `scale`
  """
  @spec button_width(String.t(), pos_integer()) :: pos_integer()
  def button_width(label, scale), do: Font.text_width(label, scale) + 2 * @button_padding

  @doc """
  A filled button with a centered label
  """
  @spec button(rect(), String.t(), keyword()) :: [NervesSurfaceRtCell.Render.op()]
  def button({x, y, w, h}, label, opts \\ []) do
    scale = Keyword.get(opts, :scale, @label_scale)
    {fill, text_color} = if opts[:selected], do: {@accent, @black}, else: {@button_color, @white}
    tx = x + div(w - Font.text_width(label, scale), 2)
    ty = y + div(h - Font.text_height(scale), 2)
    [{:rect, x, y, w, h, fill}, {:text, tx, ty, scale, label, text_color}]
  end

  @doc """
  An outlined square, as used for a 0 cell on the rule picker
  """
  @spec outline(rect(), pos_integer(), NervesSurfaceRtCell.Render.color()) :: [
          NervesSurfaceRtCell.Render.op()
        ]
  def outline({x, y, w, h}, t, color) do
    [
      {:rect, x, y, w, t, color},
      {:rect, x, y + h - t, w, t, color},
      {:rect, x, y, t, h, color},
      {:rect, x + w - t, y, t, h, color}
    ]
  end

  @doc """
  The battery indicator in the top right corner of the bar

  `battery` is `NervesSurfaceRtCell.Battery.info/0`, or `nil` when there's
  no battery (e.g. on the host).
  """
  @spec battery(pos_integer(), map() | nil) :: [NervesSurfaceRtCell.Render.op()]
  def battery(width, battery) do
    # Battery body 46×24 with a 4×10 nub on the right, 3 px border
    bw = 46
    bh = 24
    bx = width - 16 - 4 - bw
    by = div(@bar_height - bh, 2)

    {label, level, color} =
      case battery do
        nil ->
          {"--", 0, @white}

        %{capacity: capacity, ac_online: ac?} ->
          color = if capacity < 15 and not ac?, do: @low, else: @white
          {if(ac?, do: "+", else: "") <> "#{capacity}%", min(capacity, 100), color}
      end

    inner = bw - 2 * 5
    fill = div(inner * level, 100)
    tx = bx - 10 - Font.text_width(label, @label_scale)

    [{:rect, width - @battery_width, 0, @battery_width, @bar_height, @bar_color}] ++
      outline({bx, by, bw, bh}, 3, color) ++
      [
        {:rect, bx + bw, by + 7, 4, bh - 14, color},
        {:rect, bx + 5, by + 5, fill, bh - 10, color},
        {:text, tx, div(@bar_height - Font.text_height(@label_scale), 2), @label_scale, label,
         color}
      ]
  end
end
