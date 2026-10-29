defmodule NervesSurfaceRtCell.UITest do
  use ExUnit.Case, async: true

  alias NervesSurfaceRtCell.Orientation
  alias NervesSurfaceRtCell.UI.Picker
  alias NervesSurfaceRtCell.UI.Runner

  @landscape {1366, 768}
  @portrait {768, 1366}

  defp center({x, y, w, h}), do: {x + div(w, 2), y + div(h, 2)}

  defp fits?({x, y, w, h}, {sw, sh}), do: x >= 0 and y >= 0 and x + w <= sw and y + h <= sh

  for size <- [@landscape, @portrait] do
    test "picker layout fits #{inspect(size)}" do
      size = unquote(size)
      layout = Picker.layout(size)
      rects = [layout.number, layout.minus, layout.plus, layout.start]

      rects =
        rects ++ Enum.map(layout.slots, &elem(&1, 1)) ++ Enum.map(layout.presets, &elem(&1, 1))

      assert Enum.all?(rects, &fits?(&1, size))
    end

    test "picker taps on #{inspect(size)}" do
      size = unquote(size)
      layout = Picker.layout(size)

      for {index, rect} <- layout.slots do
        assert Picker.hit(30, size, center(rect)) ==
                 {:rule, Bitwise.bxor(30, Bitwise.bsl(1, index))}
      end

      for {n, rect} <- layout.presets,
          do: assert(Picker.hit(30, size, center(rect)) == {:rule, n})

      assert Picker.hit(30, size, center(layout.start)) == :start
      assert Picker.hit(30, size, center(layout.plus)) == {:rule, 31}
      assert Picker.hit(255, size, center(layout.plus)) == {:rule, 0}
      assert Picker.hit(0, size, center(layout.minus)) == {:rule, 255}
      assert Picker.hit(30, size, {0, 0}) == nil
    end

    test "runner fills #{inspect(size)} with cells" do
      size = {w, h} = unquote(size)
      area = Runner.area(size)
      assert area.x + area.columns * area.cell <= w
      assert area.y + area.rows * area.cell <= h
    end
  end

  # Draw ops into a file the size of a framebuffer and return its pixels
  defp draw(path, ops_list, rotation) do
    geometry = geometry()
    File.write!(path, :binary.copy(<<0>>, geometry.stride * geometry.height))
    {:ok, fd} = :file.open(path, [:read, :write, :raw, :binary])

    for ops <- ops_list do
      :ok = :file.pwrite(fd, NervesSurfaceRtCell.Render.writes(ops, rotation, geometry))
    end

    :ok = :file.close(fd)
    File.read!(path)
  end

  @tag :tmp_dir
  test "picker update draws the same pixels as a full render", %{tmp_dir: dir} do
    for {rotation, size} <- [{0, @landscape}, {90, @portrait}],
        {old, new} <- [{30, 31}, {30, 90}, {255, 0}, {110, 110}] do
      updated =
        draw(
          Path.join(dir, "updated"),
          [Picker.render(old, size, nil), Picker.update(old, new, size)],
          rotation
        )

      full = draw(Path.join(dir, "full"), [Picker.render(new, size, nil)], rotation)
      assert updated == full, "#{old} -> #{new} at #{rotation}"
    end
  end

  test "picker update is much smaller than a full render" do
    full = NervesSurfaceRtCell.Render.writes(Picker.render(30, @landscape, nil), 0, geometry())
    update = NervesSurfaceRtCell.Render.writes(Picker.update(30, 31, @landscape), 0, geometry())

    assert IO.iodata_length(Enum.map(update, &elem(&1, 1))) * 5 <
             IO.iodata_length(Enum.map(full, &elem(&1, 1)))
  end

  defp geometry(), do: %{width: 1366, height: 768, stride: 1366 * 4, bpp: 32}

  test "slots are in Wolfram's order, 111 first" do
    assert [{7, _}, {6, _} | _] = Picker.layout(@landscape).slots
  end

  test "runner taps" do
    assert Runner.hit(:running, @landscape, {600, 400}) == :stop
    assert Runner.hit(:paused, @landscape, {600, 400}) == :resume
    assert Runner.hit(:running, @landscape, {20, 20}) == nil
    assert Runner.hit(:finished, @landscape, {600, 400}) == nil
  end

  test "orientation follows the dominant axis" do
    map = %{y_neg: 0, y_pos: 180, x_neg: 90, x_pos: 270}
    assert Orientation.classify({0, -100, 10}, map) == 0
    assert Orientation.classify({5, 100, 10}, map) == 180
    assert Orientation.classify({-100, 10, 30}, map) == 90
    assert Orientation.classify({100, 10, 30}, map) == 270
    # Flat on a table, or halfway between
    assert Orientation.classify({10, 10, 100}, map) == nil
    assert Orientation.classify({70, 70, 0}, map) == nil
  end
end
