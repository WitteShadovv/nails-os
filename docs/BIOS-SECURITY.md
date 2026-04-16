# Security Notes

## BIOS/Legacy Boot and the Evil Maid Attack

When NAILS OS is installed on a BIOS/legacy system, the `/boot` partition is
**not encrypted**. This is a deliberate architectural constraint, not an oversight.

### Why /boot is unencrypted on BIOS systems

GRUB 2 cannot unlock LUKS2 containers that use **argon2id** as the key
derivation function. Argon2id is the default PBKDF for LUKS2 (the format
Calamares produces), because it is memory-hard and resistant to brute force.
GRUB's LUKS2 support only covers the older `pbkdf2` KDF.

The standard workaround — used by most BIOS-era full-disk-encryption setups
including Debian and Fedora — is a small, unencrypted `/boot` partition. GRUB
reads the kernel and initrd from plaintext `/boot`, loads them into memory, and
exits. The initrd then prompts for the LUKS passphrase and unlocks the
encrypted root volume. The LUKS2 argon2id protection on `/persist` is fully
intact.

### The evil maid attack

An attacker with **physical access to the machine while it is powered off**
can modify the contents of the unencrypted `/boot` partition without leaving
obvious traces. On the next boot, GRUB loads the tampered kernel or initrd,
which can silently capture the LUKS passphrase or exfiltrate data before
handing off to the real system.

This is the **evil maid attack**: a physically present adversary tampers with
the boot chain in a way the user cannot detect at boot time.

NAILS OS on BIOS **does not protect against this attack**. Neither does Tails,
nor most other encrypted Linux distributions on BIOS hardware. It is an
inherent limitation of the BIOS boot model.

### Mitigations

1. **Use UEFI hardware.** On EFI systems NAILS OS uses systemd-boot. The EFI
   system partition is also unencrypted, but with Secure Boot enabled the
   firmware verifies the bootloader signature before executing it, preventing
   an attacker from loading unsigned code. NAILS OS does not currently enroll
   custom Secure Boot keys, so this protection depends on the platform's
   default key database.

2. **Prefer UEFI over BIOS whenever possible.** Most hardware manufactured
   after 2012 supports UEFI. If your machine offers both, boot the NAILS OS
   installer in UEFI mode to get the EFI partition layout and systemd-boot.

3. **Physical tamper evidence.** If you must use BIOS, apply tamper-evident
   measures to the machine (case seals, glitter nail polish on screws, chassis
   intrusion detection). These are low-tech but reliable at detecting
   interference.

4. **Do not leave the machine unattended in a hostile environment.** The evil
   maid attack requires physical access. Remove the drive or take the machine
   with you when leaving an untrusted location.

### Summary

| Property                            | EFI install       | BIOS install          |
|-------------------------------------|-------------------|-----------------------|
| Bootloader                          | systemd-boot      | GRUB 2                |
| `/boot` partition encrypted         | No (FAT32)        | No (ext4)             |
| Evil maid via `/boot` tampering     | Possible          | Possible              |
| Secure Boot mitigation available    | Yes (partial)     | No                    |
| Recommended                         | Yes               | Only if no UEFI       |
| `/persist` LUKS2 argon2id strength  | Full              | Full                  |

The encrypted `/persist` volume provides identical LUKS2 argon2id protection
on both EFI and BIOS installs. The difference is only in the boot chain —
once the system is booted and the passphrase has been entered, security is
equivalent.
