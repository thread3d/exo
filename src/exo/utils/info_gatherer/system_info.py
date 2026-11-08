import platform
import socket
import sys
from pathlib import Path
from subprocess import CalledProcessError

import psutil
from anyio import run_process, to_thread

from exo.shared.types.memory import Memory
from exo.shared.types.profiling import InterfaceType, NetworkInterfaceInfo

_OS_RELEASE_PATH = Path("/etc/os-release")
_DMI_PRODUCT_NAME_PATH = Path("/sys/class/dmi/id/product_name")
_DMI_SYS_VENDOR_PATH = Path("/sys/class/dmi/id/sys_vendor")
_CPUINFO_PATH = Path("/proc/cpuinfo")


def _read_text(path: Path) -> str | None:
    """A file's contents, or None if it can't be read."""
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def _first_line(path: Path) -> str | None:
    """The first non-empty line of a file."""
    text = _read_text(path)
    if text is None:
        return None
    return next((line.strip() for line in text.splitlines() if line.strip()), None)


def _linux_distribution_name() -> str | None:
    """The distribution's own name for itself, e.g. "Fedora Linux 44 (KDE Plasma)"."""
    text = _read_text(_OS_RELEASE_PATH)
    if text is None:
        return None
    values: dict[str, str] = {}
    for line in text.splitlines():
        key, separator, value = line.partition("=")
        if separator:
            values[key.strip()] = value.strip().strip('"')
    return values.get("PRETTY_NAME") or values.get("NAME") or None


def get_os_version() -> str:
    """Return the OS version string for this node.

    On macOS this is the macOS version (e.g. ``"15.3"``). On Linux it is the
    distribution's name (e.g. ``"Fedora Linux 44 (KDE Plasma)"``), which is what a
    person running two different machines wants to tell apart. Otherwise it falls back
    to the platform name (e.g. ``"Linux"``).
    """
    if sys.platform == "darwin":
        version = platform.mac_ver()[0]
        return version if version else "Unknown"
    if sys.platform == "linux":
        distribution = _linux_distribution_name()
        if distribution:
            return distribution
    return platform.system() or "Unknown"


async def get_os_build_version() -> str:
    """Return the build identifier of the OS this node runs.

    On macOS this is the build version (e.g. ``"24D5055b"``). On Linux, whose
    distributions rebuild independently of a version string, it is the kernel release
    (e.g. ``"7.2.15-310.t2.fc44.x86_64"``), which is the part that decides what a build
    of exo can do. Elsewhere it is ``"Unknown"``.
    """
    if sys.platform == "linux":
        return platform.release() or "Unknown"
    if sys.platform != "darwin":
        return "Unknown"

    try:
        process = await run_process(["sw_vers", "-buildVersion"])
    except CalledProcessError:
        return "Unknown"

    return process.stdout.decode("utf-8", errors="replace").strip() or "Unknown"


def get_gpu_working_set() -> Memory | None:
    """The most memory this Mac's GPU should use: Metal's recommended working set, which is
    also the limit a runner wires its model's memory up to. None without Metal."""
    if sys.platform != "darwin":
        return None
    try:
        import mlx.core as mx
    except ImportError:
        return None
    if not mx.metal.is_available():
        return None
    return Memory.from_bytes(int(mx.device_info()["max_recommended_working_set_size"]))


async def get_friendly_name() -> str:
    """
    Asynchronously gets the 'Computer Name' (friendly name) of a Mac.
    e.g., "John's MacBook Pro"
    Returns the name as a string, or None if an error occurs or not on macOS.
    """
    hostname = socket.gethostname()

    if sys.platform != "darwin":
        return hostname

    try:
        process = await run_process(["scutil", "--get", "ComputerName"])
    except CalledProcessError:
        return hostname

    return process.stdout.decode("utf-8", errors="replace").strip() or hostname


async def _get_interface_types_from_networksetup() -> dict[str, InterfaceType]:
    """Parse networksetup -listallhardwareports to get interface types."""
    if sys.platform != "darwin":
        return {}

    try:
        result = await run_process(["networksetup", "-listallhardwareports"])
    except CalledProcessError:
        return {}

    types: dict[str, InterfaceType] = {}
    current_type: InterfaceType = "unknown"

    for line in result.stdout.decode().splitlines():
        if line.startswith("Hardware Port:"):
            port_name = line.split(":", 1)[1].strip()
            if "Wi-Fi" in port_name:
                current_type = "wifi"
            elif "Ethernet" in port_name or "LAN" in port_name:
                current_type = "ethernet"
            elif port_name.startswith("Thunderbolt"):
                current_type = "thunderbolt"
            else:
                current_type = "unknown"
        elif line.startswith("Device:"):
            device = line.split(":", 1)[1].strip()
            # enX is ethernet adapters or thunderbolt - these must be deprioritised
            if device.startswith("en") and device not in ["en0", "en1"]:
                current_type = "maybe_ethernet"
            types[device] = current_type

    return types


async def get_network_interfaces() -> list[NetworkInterfaceInfo]:
    """
    Retrieves detailed network interface information on macOS.
    Parses output from 'networksetup -listallhardwareports' and 'ifconfig'
    to determine interface names, IP addresses, and types (ethernet, wifi, vpn, other).
    Returns a list of NetworkInterfaceInfo objects.
    """
    interfaces_info: list[NetworkInterfaceInfo] = []
    interface_types = await _get_interface_types_from_networksetup()

    for iface, services in psutil.net_if_addrs().items():
        for service in services:
            match service.family:
                case socket.AF_INET | socket.AF_INET6:
                    interfaces_info.append(
                        NetworkInterfaceInfo(
                            name=iface,
                            ip_address=service.address,
                            interface_type=interface_types.get(iface, "unknown"),
                        )
                    )
                case _:
                    pass

    return interfaces_info


def _linux_model_and_chip() -> tuple[str, str]:
    """The machine and the CPU, from DMI and /proc/cpuinfo.

    DMI names the machine as its vendor built it (a Mac Pro 7,1 reports "MacPro7,1" and
    "Apple Inc."), and /proc/cpuinfo names the CPU. Each is what the dashboard shows for
    a Mac, so a cluster of mixed machines reads the same way.
    """
    model = _first_line(_DMI_PRODUCT_NAME_PATH) or "Unknown Model"
    vendor = _first_line(_DMI_SYS_VENDOR_PATH)
    if vendor:
        model = f"{vendor} {model}"

    chip = "Unknown Chip"
    cpuinfo = _read_text(_CPUINFO_PATH)
    if cpuinfo is not None:
        for line in cpuinfo.splitlines():
            if line.startswith("model name"):
                chip = line.partition(":")[2].strip() or chip
                break
    return (model, chip)


async def get_model_and_chip() -> tuple[str, str]:
    """Get this machine's model and processor.

    On macOS, from system_profiler. On Linux, from DMI and /proc/cpuinfo.
    """
    model = "Unknown Model"
    chip = "Unknown Chip"

    if sys.platform == "linux":
        try:
            return await to_thread.run_sync(_linux_model_and_chip)
        except (OSError, IndexError, ValueError):
            return (model, chip)
    if sys.platform != "darwin":
        return (model, chip)

    try:
        process = await run_process(
            [
                "system_profiler",
                "SPHardwareDataType",
            ]
        )
    except CalledProcessError:
        return (model, chip)

    # less interested in errors here because this value should be hard coded
    output = process.stdout.decode().strip()

    model_line = next(
        (line for line in output.split("\n") if "Model Name" in line), None
    )
    model = model_line.split(": ")[1] if model_line else "Unknown Model"

    chip_line = next((line for line in output.split("\n") if "Chip" in line), None)
    chip = chip_line.split(": ")[1] if chip_line else "Unknown Chip"

    return (model, chip)
