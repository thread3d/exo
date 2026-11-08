"""What a Linux node tells the cluster about itself.

The dashboard and the master's placement both read these, and on a Mac they come from
system_profiler and sw_vers. Linux has no such tools: the machine's name is in DMI, its
processor in /proc/cpuinfo, its distribution in /etc/os-release and its build in the kernel
release. Without these, every Linux node reported "Unknown Model"/"Unknown Chip" and its OS as
just "Linux", so a cluster of mixed machines could not be told apart.
"""

from pathlib import Path

import pytest

from exo.utils.info_gatherer import system_info

DMI_PRODUCT_NAME = "MacPro7,1"
DMI_SYS_VENDOR = "Apple Inc."
CPUINFO = """processor\t: 0
vendor_id\t: GenuineIntel
model name\t: Intel(R) Xeon(R) W-3275 CPU @ 2.50GHz
cpu MHz\t\t: 2500.000

processor\t: 1
model name\t: Intel(R) Xeon(R) W-3275 CPU @ 2.50GHz
"""


@pytest.fixture
def linux_files(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> Path:
    """Files standing in for the ones this machine has, with sys.platform saying Linux."""
    os_release = tmp_path / "os-release"
    os_release.write_text(
        'NAME="Fedora Linux"\nPRETTY_NAME="Fedora Linux 44 (KDE Plasma Desktop Edition)"\n'
        "ID=fedora\n",
        encoding="utf-8",
    )
    product_name = tmp_path / "product_name"
    product_name.write_text(f"{DMI_PRODUCT_NAME}\n", encoding="utf-8")
    sys_vendor = tmp_path / "sys_vendor"
    sys_vendor.write_text(f"{DMI_SYS_VENDOR}\n", encoding="utf-8")
    cpuinfo = tmp_path / "cpuinfo"
    cpuinfo.write_text(CPUINFO, encoding="utf-8")

    monkeypatch.setattr(system_info.sys, "platform", "linux")
    monkeypatch.setattr(system_info, "_OS_RELEASE_PATH", os_release)
    monkeypatch.setattr(system_info, "_DMI_PRODUCT_NAME_PATH", product_name)
    monkeypatch.setattr(system_info, "_DMI_SYS_VENDOR_PATH", sys_vendor)
    monkeypatch.setattr(system_info, "_CPUINFO_PATH", cpuinfo)
    return tmp_path


async def test_the_distribution_names_the_os(linux_files: Path) -> None:
    assert (
        system_info.get_os_version() == "Fedora Linux 44 (KDE Plasma Desktop Edition)"
    )


async def test_a_distribution_without_a_pretty_name_still_names_itself(
    linux_files: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    os_release = linux_files / "os-release"
    os_release.write_text('NAME="Fedora Linux"\nID=fedora\n', encoding="utf-8")
    assert system_info.get_os_version() == "Fedora Linux"


async def test_without_os_release_the_platform_name_is_kept(
    linux_files: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(system_info, "_OS_RELEASE_PATH", linux_files / "missing")
    assert system_info.get_os_version() in ("Linux", "Unknown")


async def test_the_kernel_release_is_the_build(linux_files: Path) -> None:
    build = await system_info.get_os_build_version()
    assert build == system_info.platform.release()
    assert build != "Unknown"


async def test_the_machine_and_its_processor_are_named(linux_files: Path) -> None:
    model, chip = await system_info.get_model_and_chip()
    assert model == f"{DMI_SYS_VENDOR} {DMI_PRODUCT_NAME}"
    assert chip == "Intel(R) Xeon(R) W-3275 CPU @ 2.50GHz"


async def test_missing_hardware_files_are_reported_as_unknown(
    linux_files: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    for name in (
        "_DMI_PRODUCT_NAME_PATH",
        "_DMI_SYS_VENDOR_PATH",
        "_CPUINFO_PATH",
    ):
        monkeypatch.setattr(system_info, name, linux_files / f"missing{name}")
    assert await system_info.get_model_and_chip() == ("Unknown Model", "Unknown Chip")


async def test_macos_still_reports_its_own_version(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """The Linux path must not change what a Mac reports."""
    monkeypatch.setattr(system_info.sys, "platform", "darwin")
    monkeypatch.setattr(
        system_info.platform, "mac_ver", lambda: ("15.3", ("", "", ""), "")
    )
    assert system_info.get_os_version() == "15.3"
