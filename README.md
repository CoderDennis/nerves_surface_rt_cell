# NervesSurfaceRtCell

A [Nerves](https://nerves-project.org/) app that turns the original Microsoft
Surface RT (2012, NVIDIA Tegra 3) into a touchscreen viewer for Stephen
Wolfram's elementary cellular automata, built on
[nerves_system_surface_rt](https://github.com/CoderDennis/nerves_system_surface_rt).

On the Surface RT it:

  * shows a rule picker: the rule number with − and + buttons, Wolfram's
    rule icon (the 8 neighborhoods from 111 to 000, each with its output
    cell below it; tap one to flip it) and presets for rules 30, 90, 110
    and 184
  * runs the rule from a single cell, white on black, one row per
    generation. Once it reaches the bottom it scrolls up a quarter of the
    screen at a time and keeps going.
  * stops when you tap Stop (or the automaton), then resumes or goes back
    to the picker for a new rule
  * shows the battery level in the top right corner, with a `+` while
    charging
  * turns the screen between landscape and portrait with the
    accelerometer

## How it works

Tegra 3 has no mainline GPU driver, so there's no OpenGL for Scenic. The
app draws straight into the Tegra DRM driver's framebuffer, `/dev/fb0`.
Everything on screen is rectangles, so drawing in any of the four
rotations is a matter of mapping rectangles.

| Module | Does |
| --- | --- |
| `Automaton` | The 256 rules, with 0 cells beyond the edges |
| `UI.Picker`, `UI.Runner`, `UI` | Screen layouts, buttons, battery indicator, tap handling |
| `Font` | A 5×7 bitmap font |
| `Rotation` | Logical (as you see the screen) ↔ framebuffer coordinates |
| `Render` | Drawing operations → `{offset, bytes}` writes for `:file.pwrite/2` |
| `Framebuffer` | Opens `/dev/fb0` and unbinds the framebuffer console from it |
| `Display` | The screens' state machine, and the only process that draws |
| `Touch` | Taps from the touchscreen, through [input_event](https://hex.pm/packages/input_event) |
| `Orientation` | Polls the accelerometer (IIO `accel_3d`) and rotates the screen |
| `Battery` | Battery status from `/sys/class/power_supply` |

The IEx console on the built-in screen is hidden while the app draws. Use
SSH (`ssh nerves.local`) for IEx.

## Getting started

You need a jailbroken Surface RT with Nerves installed on its eMMC. See the
system's
[JAILBREAK.md](https://github.com/CoderDennis/nerves_system_surface_rt/blob/main/JAILBREAK.md)
and
[INSTALLING.md](https://github.com/CoderDennis/nerves_system_surface_rt/blob/main/INSTALLING.md).

Screen rotation needs the accelerometer driver (`CONFIG_HID_SENSOR_ACCEL_3D`),
which isn't in a released system yet. Build against a local checkout of the
system that has it:

```sh
export MIX_TARGET=surface_rt
export SURFACE_RT_SYSTEM_PATH=../nerves_system_surface_rt
mix deps.get
mix firmware
mix upload nerves.local
```

The system is then built from source with Buildroot (in Docker on macOS).
Without `SURFACE_RT_SYSTEM_PATH` the app uses the released system from Hex,
and everything but rotation works.

The Erlang and Elixir versions in `.tool-versions` must match the system's
Erlang/OTP major version (29). Wi-Fi and SSH are set up as in
[nerves_surface_rt_hello](https://github.com/CoderDennis/nerves_surface_rt_hello):
`NERVES_WIFI_SSID` and `NERVES_WIFI_PSK` at build time, or
`VintageNetWiFi.quick_configure/2` at the IEx prompt.

## Tests

The automaton, layouts, rotation and rendering are pure modules:

```sh
mix test
```

## Calibration

How the touchscreen and accelerometer axes line up with the screen is only
known on the device. Over SSH:

```elixir
# Rotate by hand
NervesSurfaceRtCell.Display.rotate(90)

# The raw accelerometer reading {x, y, z}, to see which axis gravity is on
NervesSurfaceRtCell.Orientation.reading()
```

If the screen turns the wrong way, or taps land in the wrong place, set the
mappings in `config/target.exs`:

```elixir
config :nerves_surface_rt_cell,
  orientation: %{y_neg: 0, y_pos: 180, x_neg: 270, x_pos: 90},
  touch: [swap_xy: false, invert_x: false, invert_y: false]
```

## License

Copyright 2026 Dennis Palmer

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
