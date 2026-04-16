"""Tests for get_initrd_modules() — kernel modules for initrd.

Missing modules = unbootable system (can't unlock LUKS or mount filesystems).
"""

import pytest
from unittest.mock import patch
from tests.conftest import main

get_initrd_modules = main.get_initrd_modules

REQUIRED_MODULES = {"dm_mod", "dm_crypt", "ext4", "vfat"}
ALWAYS_FALLBACK = {"ahci", "sd_mod", "ata_piix"}  # added unconditionally at end


class TestBaseModules:
    @patch.object(main, "run_cmd", side_effect=Exception("no lsmod"))
    def test_always_includes_required(self, _):
        result = get_initrd_modules()
        for mod in REQUIRED_MODULES:
            assert mod in result

    @patch.object(main, "run_cmd", side_effect=Exception("no lsmod"))
    def test_always_includes_fallback(self, _):
        result = get_initrd_modules()
        for mod in ALWAYS_FALLBACK:
            assert mod in result


class TestLsmodDetection:
    LSMOD_HEADER = "Module                  Size  Used by\n"

    @patch.object(
        main,
        "run_cmd",
        return_value=LSMOD_HEADER
        + "nvme                   12345  0\nnvme_core              67890  1 nvme\n",
    )
    def test_detects_nvme(self, _):
        result = get_initrd_modules()
        assert "nvme" in result
        assert "nvme_core" in result

    @patch.object(
        main, "run_cmd", return_value=LSMOD_HEADER + "virtio_blk             1234  0\n"
    )
    def test_detects_virtio(self, _):
        result = get_initrd_modules()
        assert "virtio_blk" in result

    @patch.object(
        main, "run_cmd", return_value=LSMOD_HEADER + "some_random_mod        1234  0\n"
    )
    def test_ignores_unknown_modules(self, _):
        result = get_initrd_modules()
        assert "some_random_mod" not in result


class TestDeduplicationAndSorting:
    @patch.object(
        main,
        "run_cmd",
        return_value="Module                  Size  Used by\nahci                   1234  0\nsd_mod                 5678  0\n",
    )
    def test_no_duplicates(self, _):
        """ahci and sd_mod are in lsmod AND in the fallback list — should not duplicate."""
        result = get_initrd_modules()
        assert result.count("ahci") == 1
        assert result.count("sd_mod") == 1

    @patch.object(main, "run_cmd", side_effect=Exception("fail"))
    def test_sorted(self, _):
        result = get_initrd_modules()
        assert result == sorted(result)

    @patch.object(
        main, "run_cmd", return_value="Module                  Size  Used by\n"
    )
    def test_empty_lsmod(self, _):
        """lsmod returns header only — still get base + fallback modules."""
        result = get_initrd_modules()
        for mod in REQUIRED_MODULES | ALWAYS_FALLBACK:
            assert mod in result
