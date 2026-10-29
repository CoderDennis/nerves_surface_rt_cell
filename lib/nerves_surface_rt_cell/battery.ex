defmodule NervesSurfaceRtCell.Battery do
  @moduledoc """
  Battery status of the Microsoft Surface RT

  Reads the power supplies that the Surface RT's embedded controller driver
  (`surface-rt-ec`) registers under `/sys/class/power_supply`.
  """

  @battery "/sys/class/power_supply/surface-rt-battery"
  @ac_adapter "/sys/class/power_supply/surface-rt-ac-adapter"

  @typedoc """
  Battery information

  Voltages are in mV, currents in mA and charges in mAh. The current is
  negative while discharging.
  """
  @type info() :: %{
          capacity: non_neg_integer(),
          status: String.t(),
          ac_online: boolean(),
          voltage: integer(),
          current: integer(),
          charge_now: integer(),
          charge_full: integer(),
          charge_full_design: integer(),
          cycle_count: integer()
        }

  @doc """
  Return the battery information, or `nil` if there's no battery
  """
  @spec info() :: info() | nil
  def info() do
    if File.dir?(@battery) do
      %{
        capacity: read_integer(@battery, "capacity"),
        status: read(@battery, "status"),
        ac_online: read(@ac_adapter, "online") == "1",
        voltage: div(read_integer(@battery, "voltage_now"), 1000),
        current: div(read_integer(@battery, "current_now"), 1000),
        charge_now: div(read_integer(@battery, "charge_now"), 1000),
        charge_full: div(read_integer(@battery, "charge_full"), 1000),
        charge_full_design: div(read_integer(@battery, "charge_full_design"), 1000),
        cycle_count: read_integer(@battery, "cycle_count")
      }
    end
  end

  @doc """
  Print a one-line battery summary

  Imported into IEx by `iex.exs`, so `battery` at the prompt prints e.g.:

      82% Discharging (-598 mA, 7952 mV)
  """
  @spec battery() :: :ok
  def battery() do
    IO.puts(summary(info()))
  end

  @doc """
  Rows for `NervesMOTD.print/1`'s `:extra_rows` option
  """
  @spec motd_rows() :: [[{String.t(), String.t()}]]
  def motd_rows() do
    [[{"Battery", summary(info())}]]
  end

  defp summary(nil), do: "not found"

  defp summary(info) do
    "#{info.capacity}% #{info.status} (#{info.current} mA, #{info.voltage} mV)"
  end

  defp read(dir, name) do
    case File.read(Path.join(dir, name)) do
      {:ok, value} -> String.trim(value)
      {:error, _} -> ""
    end
  end

  defp read_integer(dir, name) do
    case Integer.parse(read(dir, name)) do
      {value, _} -> value
      :error -> 0
    end
  end
end
