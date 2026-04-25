"""Tests for make_hardware_config() — generates hardware-configuration.nix.

Security-critical: wrong UUIDs or LUKS config means an unbootable or
unencrypted system.
"""

import pytest
from tests.conftest import main

make_hardware_config = main.make_hardware_config


@pytest.fixture
def sample_modules():
    return ["ahci", "dm_crypt", "dm_mod", "ext4", "sd_mod", "vfat"]


BOOT_UUID = "AAAA-BBBB"
LUKS_UUID = "12345678-abcd-ef01-2345-67890abcdef0"


class TestEfiMode:
    def test_contains_boot_efi_mount(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert '"/boot/efi"' in result
        assert BOOT_UUID in result

    def test_boot_efi_is_vfat(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert 'fsType = "vfat"' in result

    def test_no_bind_boot(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert '"/persist/boot"' not in result

    def test_no_grub_device(self, sample_modules):
        """EFI mode should not reference grub disk device."""
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        # No GRUB device reference in the hardware config (that's in boot-mode.nix)
        assert "grub" not in result.lower()


class TestBiosMode:
    def test_boot_bind_mount(self, sample_modules):
        result = make_hardware_config(
            None, LUKS_UUID, sample_modules, efi_mode=False, grub_disk_device="/dev/sda"
        )
        assert '"/persist/boot"' in result
        assert '"bind"' in result

    def test_no_boot_efi(self, sample_modules):
        result = make_hardware_config(
            None, LUKS_UUID, sample_modules, efi_mode=False, grub_disk_device="/dev/sda"
        )
        assert '"/boot/efi"' not in result

    def test_boot_needed_for_boot(self, sample_modules):
        result = make_hardware_config(
            None, LUKS_UUID, sample_modules, efi_mode=False, grub_disk_device="/dev/sda"
        )
        assert "neededForBoot = true" in result


class TestLuksConfig:
    def test_luks_uuid_in_config(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert LUKS_UUID in result

    def test_luks_device_path(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert f"/dev/disk/by-uuid/{LUKS_UUID}" in result

    def test_persist_mapper(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert '"persist"' in result
        assert "/dev/mapper/persist" in result

    def test_tmpfs_root(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert 'device = "tmpfs"' in result
        assert 'fsType = "tmpfs"' in result

    def test_tmpfs_root_has_no_fixed_size_cap(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert 'size=' not in result


class TestInitrdModules:
    def test_modules_formatted_as_nix_list(self, sample_modules):
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert '[ "ahci" "dm_crypt" "dm_mod" "ext4" "sd_mod" "vfat" ]' in result

    def test_empty_modules(self):
        result = make_hardware_config(BOOT_UUID, LUKS_UUID, [], efi_mode=True)
        assert "availableKernelModules = [  ]" in result

    def test_single_module(self):
        result = make_hardware_config(BOOT_UUID, LUKS_UUID, ["dm_mod"], efi_mode=True)
        assert '[ "dm_mod" ]' in result


class TestUuidEscaping:
    def test_uuid_with_normal_chars(self):
        """Standard UUID should appear verbatim."""
        uuid = "550e8400-e29b-41d4-a716-446655440000"
        result = make_hardware_config(BOOT_UUID, uuid, ["dm_mod"], efi_mode=True)
        assert uuid in result

    def test_nix_interpolation_in_uuid(self):
        """If a UUID somehow contained ${...}, it would be interpolated by Nix.
        The config uses double-braces for Nix but the UUID is inside a Python
        .format() — verify it appears literally."""
        uuid = "test-uuid-1234"
        result = make_hardware_config(BOOT_UUID, uuid, ["dm_mod"], efi_mode=True)
        # Verify Nix syntax is correct (double braces become single in output)
        assert "{ config, lib, pkgs, modulesPath, ... }:" in result
        assert 'device = "/dev/disk/by-uuid/test-uuid-1234"' in result

    def test_valid_nix_syntax(self, sample_modules):
        """Output should have balanced braces for valid Nix."""
        result = make_hardware_config(
            BOOT_UUID, LUKS_UUID, sample_modules, efi_mode=True
        )
        assert result.count("{") == result.count("}")
