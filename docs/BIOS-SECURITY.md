# BIOS / Legacy Boot Security Notes

## What BIOS installs actually do today

On BIOS/legacy systems, NAILS OS does **not** create a separate plaintext `/boot`
partition.

Instead, the installer uses:

- an MBR partition table
- a single **LUKS1-encrypted** system volume covering the disk
- GRUB 2 with `cryptodisk` support so GRUB can unlock that volume before loading the kernel

This differs from the UEFI path, which uses an unencrypted EFI system partition
plus a LUKS2-encrypted system volume.

## Why BIOS uses LUKS1

Current NAILS OS BIOS installs use LUKS1 because GRUB must unlock the encrypted
disk before the kernel and initrd can be loaded, and the deployed GRUB path is
the compatibility constraint here.

Practical consequence: BIOS installs prompt for the disk passphrase twice at
boot — once in GRUB, then again in the initrd.

## What the real limitation is

The main BIOS/legacy limitation is **boot-chain trust**, not a plaintext `/boot`
partition.

NAILS OS does not currently configure verified boot on installed systems. An
attacker with physical access to a powered-off machine may still be able to
tamper with firmware, GRUB components, or other early-boot code and capture the
passphrase on a later boot.

That risk is broader than BIOS alone, but BIOS/legacy mode keeps the older
GRUB-based path and its LUKS1 compatibility trade-offs.

## Practical guidance

1. **Prefer UEFI when available.** It avoids the BIOS-specific GRUB+LUKS1 path.
2. **Treat physical access as out of scope.** Do not leave the machine
   unattended in hostile environments.
3. **Use tamper-evident measures** if you must rely on shared or exposed
   hardware.
4. **Understand the boot prompts.** A BIOS install asking for the passphrase
   twice is expected with the current design.

## Summary

| Property | UEFI install | BIOS install |
|---|---|---|
| Bootloader | systemd-boot | GRUB 2 |
| Separate plaintext `/boot` partition | EFI system partition only | No |
| Encrypted system volume format | LUKS2 | LUKS1 |
| Verified boot configured by NAILS OS | No | No |
| Double passphrase prompt at boot | No | Yes |
| Recommended | Yes | Fallback when UEFI is unavailable |
