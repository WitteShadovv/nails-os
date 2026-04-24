"""Focused tests for the supported BIOS installer path."""

from unittest.mock import patch

from tests.conftest import _FakeGlobalStorage, main


def test_detect_partitions_supports_bios_single_luks1_without_separate_boot():
    gs = _FakeGlobalStorage()
    gs["partitions"] = [
        {
            "device": "/dev/sda1",
            "mountPoint": "/",
            "fileSystemType": "ext4",
            "luksPassphrase": "secret",
        }
    ]

    with (
        patch.object(main, "is_efi_boot", return_value=False),
        patch.object(main, "blkid_type", return_value="crypto_LUKS"),
        patch.object(main, "blkid_uuid", return_value="luks-uuid"),
        patch.object(main, "get_disk_device", return_value="/dev/sda"),
    ):
        result = main.detect_partitions(gs, "/tmp/fake-root")

    assert result == {
        "efi_mode": False,
        "boot_uuid": None,
        "luks_uuid": "luks-uuid",
        "luks_passphrase": "secret",
        "grub_disk_device": "/dev/sda",
    }
