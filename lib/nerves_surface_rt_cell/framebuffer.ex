defmodule NervesSurfaceRtCell.Framebuffer do
  @moduledoc """
  Writes to the Linux framebuffer, `/dev/fb0`

  On the Surface RT this is the Tegra DRM driver's fbdev emulation of the
  1366×768 panel. The kernel's framebuffer console draws on the same
  screen, so `open/1` unbinds it and `close/1` binds it again. IEx stays
  available over SSH meanwhile.

  The file is owned by the process that opens it.
  """

  require Logger

  alias NervesSurfaceRtCell.Render

  defstruct [:fd, :geometry]

  @type t() :: %__MODULE__{fd: :file.io_device(), geometry: Render.geometry()}

  @sysfs "/sys/class/graphics"

  @doc """
  Open a framebuffer device, e.g. `"fb0"`
  """
  @spec open(String.t()) :: {:ok, t()} | {:error, term()}
  def open(name \\ "fb0") do
    with {:ok, geometry} <- geometry(name),
         {:ok, fd} <- :file.open("/dev/#{name}", [:read, :write, :raw, :binary]) do
      bind_console(false)
      {:ok, %__MODULE__{fd: fd, geometry: geometry}}
    end
  end

  @doc """
  Close the framebuffer and give the screen back to the console
  """
  @spec close(t()) :: :ok
  def close(%__MODULE__{fd: fd}) do
    _ = :file.close(fd)
    bind_console(true)
  end

  @doc """
  Write `{offset, iodata}` pairs from `NervesSurfaceRtCell.Render.writes/3`
  """
  @spec write(t(), [{non_neg_integer(), iodata()}]) :: :ok | {:error, term()}
  def write(_fb, []), do: :ok

  def write(%__MODULE__{fd: fd}, writes) do
    case :file.pwrite(fd, writes) do
      :ok -> :ok
      {:error, {_n, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp geometry(name) do
    dir = Path.join(@sysfs, name)

    with {:ok, stride} <- read_integers(dir, "stride"),
         {:ok, [bpp]} <- read_integers(dir, "bits_per_pixel"),
         {:ok, [vw, vh]} <- read_integers(dir, "virtual_size") do
      {w, h} = visible_size(dir) || {vw, vh}
      {:ok, %{width: w, height: h, stride: hd(stride), bpp: bpp}}
    end
  end

  # The visible mode, e.g. "U:1366x768p-60". The virtual size can be
  # taller when the driver allocates room for page flipping.
  defp visible_size(dir) do
    with {:ok, modes} <- File.read(Path.join(dir, "modes")),
         [_, w, h] <- Regex.run(~r/(\d+)x(\d+)/, modes) do
      {String.to_integer(w), String.to_integer(h)}
    else
      _ -> nil
    end
  end

  defp read_integers(dir, name) do
    case File.read(Path.join(dir, name)) do
      {:ok, contents} ->
        {:ok, contents |> String.trim() |> String.split(",") |> Enum.map(&String.to_integer/1)}

      error ->
        error
    end
  end

  # The framebuffer console is the vtcon whose name mentions "frame buffer"
  defp bind_console(bind?) do
    for dir <- Path.wildcard("/sys/class/vtconsole/vtcon*"),
        {:ok, name} <- [File.read(Path.join(dir, "name"))],
        name =~ "frame buffer" do
      case File.write(Path.join(dir, "bind"), if(bind?, do: "1", else: "0")) do
        :ok -> :ok
        {:error, reason} -> Logger.warning("Can't change #{dir}/bind: #{inspect(reason)}")
      end
    end

    :ok
  end
end
