"""Tests for LUKS enforcement logic in run().

NAILS OS mandates full-disk encryption. The installer must abort if:
  1. No LUKS partition is found on the root mount point
  2. The root partition's blkid TYPE is not LUKS
  3. No LUKS passphrase was provided
"""

import pytest
from unittest.mock import patch, MagicMock
from tests.conftest import main, _FakeGlobalStorage
import libcalamares


def _make_gs(partitions, hostname="testhost", password="obscured"):
    gs = _FakeGlobalStorage()
    gs["rootMountPoint"] = "/tmp/fake-root"
    gs["partitions"] = partitions
    gs["hostname"] = hostname
    gs["password"] = password
    return gs


class TestNoLuksPartition:
    """No LUKS partition detected → error."""

    @patch.object(main, "blkid_type", return_value="ext4")
    @patch.object(main, "find_luks_backing_device", return_value=None)
    @patch.object(main, "run_cmd", return_value="")
    def test_no_luks_device_returns_error(self, mock_run, mock_find, mock_blkid):
        gs = _make_gs(
            [
                {
                    "device": "/dev/sda1",
                    "mountPoint": "/boot",
                    "fileSystemType": "fat32",
                },
                {"device": "/dev/sda2", "mountPoint": "/", "fileSystemType": "ext4"},
            ]
        )
        libcalamares.globalstorage = gs

        with patch.object(main, "is_efi_boot", return_value=True):
            result = main.run()

        assert result is not None
        assert "LUKS" in result[1] or "encryption" in result[1].lower()


class TestWrongBlkidType:
    """Root partition exists but blkid says it's not LUKS."""

    @patch.object(main, "blkid_uuid", return_value="fake-uuid")
    @patch.object(main, "run_cmd", return_value="")
    def test_non_luks_type_returns_error(self, mock_run, mock_uuid):
        gs = _make_gs(
            [
                {
                    "device": "/dev/sda1",
                    "mountPoint": "/boot",
                    "fileSystemType": "fat32",
                },
                {
                    "device": "/dev/sda2",
                    "mountPoint": "/",
                    "fileSystemType": "ext4",
                    "luksPassphrase": "secret",
                },
            ]
        )
        libcalamares.globalstorage = gs

        # First call: blkid_type for root device detection → "crypto_LUKS" (find it)
        # Second call: blkid_type enforcement check → "ext4" (fail enforcement)
        call_count = {"n": 0}

        def fake_blkid_type(dev):
            call_count["n"] += 1
            if call_count["n"] == 1:
                return "crypto_LUKS"  # detection finds it
            return "ext4"  # enforcement fails

        with patch.object(main, "blkid_type", side_effect=fake_blkid_type):
            with patch.object(main, "is_efi_boot", return_value=True):
                result = main.run()

        assert result is not None
        assert "not LUKS" in result[1] or "encryption" in result[1].lower()


class TestMissingPassphrase:
    """LUKS partition found but no passphrase provided."""

    @patch.object(main, "blkid_type", return_value="crypto_LUKS")
    @patch.object(main, "blkid_uuid", return_value="fake-uuid")
    @patch.object(main, "run_cmd", return_value="")
    def test_no_passphrase_returns_error(self, mock_run, mock_uuid, mock_blkid):
        gs = _make_gs(
            [
                {
                    "device": "/dev/sda1",
                    "mountPoint": "/boot",
                    "fileSystemType": "fat32",
                },
                {
                    "device": "/dev/sda2",
                    "mountPoint": "/",
                    "fileSystemType": "ext4",
                    # No luksPassphrase key!
                },
            ]
        )
        libcalamares.globalstorage = gs

        with patch.object(main, "is_efi_boot", return_value=True):
            result = main.run()

        assert result is not None
        assert "passphrase" in result[1].lower()
