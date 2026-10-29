# New firmware boots as a trial until Nerves.Runtime.StartupGuard validates
# it, about 10 s after boot. During the first minute of uptime, wait up to
# 30 s for that, so the MOTD shows the result instead of "Not validated".
{uptime, _} = File.read!("/proc/uptime") |> Float.parse()

if uptime < 60 do
  Enum.find(1..30, fn _ ->
    valid? = Nerves.Runtime.firmware_valid?()
    unless valid?, do: Process.sleep(1000)
    valid?
  end)
end

NervesMOTD.print()

# Add Toolshed helpers to the IEx session
use Toolshed

# battery() prints the battery level
import NervesSurfaceRtCell.Battery, only: [battery: 0]

# start() shows the cellular automata on the screen, stop() brings the
# console back
import NervesSurfaceRtCell, only: [start: 0, stop: 0]
