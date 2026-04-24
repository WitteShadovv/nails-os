"""Tests for get_disk_device() — maps partition to parent disk.

Used to determine the GRUB install target in BIOS mode.
Wrong result = unbootable system.
"""

import pytest
from unittest.mock import patch
from tests.conftest import main

get_disk_device = main.get_disk_device


class TestRegexFallback:
    """When lsblk fails, the regex fallback is used."""

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_sda2_to_sda(self, _):
        assert get_disk_device("/dev/sda2") == "/dev/sda"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_sda1_to_sda(self, _):
        assert get_disk_device("/dev/sda1") == "/dev/sda"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_sdb3_to_sdb(self, _):
        assert get_disk_device("/dev/sdb3") == "/dev/sdb"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_nvme0n1p3_to_nvme0n1(self, _):
        assert get_disk_device("/dev/nvme0n1p3") == "/dev/nvme0n1"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_nvme0n1p1_to_nvme0n1(self, _):
        assert get_disk_device("/dev/nvme0n1p1") == "/dev/nvme0n1"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_nvme1n1p2_to_nvme1n1(self, _):
        assert get_disk_device("/dev/nvme1n1p2") == "/dev/nvme1n1"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_vda1_to_vda(self, _):
        assert get_disk_device("/dev/vda1") == "/dev/vda"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_mapper_device_returns_none(self, _):
        """Mapper devices don't match the regex → None."""
        assert get_disk_device("/dev/mapper/luks-abc123") is None

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_loop_device_matched_by_regex(self, _):
        """/dev/loop0 matches the regex as /dev/loop (strips trailing digit).
        This is a known quirk — loop devices aren't real disk+partition pairs."""
        assert get_disk_device("/dev/loop0") == "/dev/loop"

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_mapper_returns_none(self, _):
        """Mapper paths don't match the regex at all."""
        assert get_disk_device("/dev/mapper/crypt-root") is None

    @patch.object(main, "run_cmd", side_effect=Exception("no lsblk"))
    def test_whole_disk_no_partition(self, _):
        """A whole disk device without partition number doesn't match."""
        assert get_disk_device("/dev/sda") is None


class TestLsblkPrimary:
    """When lsblk succeeds, its PKNAME is preferred."""

    @patch.object(main, "run_cmd", return_value="sda\n")
    def test_lsblk_result_used(self, _):
        assert get_disk_device("/dev/sda2") == "/dev/sda"

    @patch.object(main, "run_cmd", return_value="nvme0n1\n")
    def test_lsblk_nvme(self, _):
        assert get_disk_device("/dev/nvme0n1p1") == "/dev/nvme0n1"

    @patch.object(main, "run_cmd", return_value="")
    def test_lsblk_empty_falls_to_regex(self, _):
        """Empty lsblk output → regex fallback."""
        assert get_disk_device("/dev/sda2") == "/dev/sda"

    @patch.object(main, "run_cmd", return_value="\n")
    def test_lsblk_blank_line_falls_to_regex(self, _):
        assert get_disk_device("/dev/sda2") == "/dev/sda"
