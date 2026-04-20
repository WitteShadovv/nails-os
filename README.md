<div align="center">
  <img src="nix-config/hosts/nails-os-iso/calamares/branding/nails-os/logo.png" alt="NAILS OS logo" width="160" />
  <h1>NAILS OS</h1>

[![Build ISO](https://github.com/WitteShadovv/nails-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/WitteShadovv/nails-os/actions/workflows/build-iso.yml)
[![Status: Alpha](https://img.shields.io/badge/Status-Alpha-orange)](https://github.com/WitteShadovv/nails-os)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![NixOS 25.11](https://img.shields.io/badge/NixOS-25.11-5277C3.svg?logo=nixos&logoColor=white)](https://nixos.org)

</div>

> **A privacy-oriented NixOS distribution with a tmpfs root, a mandatory encrypted system volume, and Tor as the default network mode.**

NAILS OS is a bootable ISO with a graphical installer. It installs an amnesic desktop system that runs from RAM, keeps most persistent state on encrypted storage, and defaults to Tor-routed networking. In UEFI mode, boot files still live on a small unencrypted EFI system partition. The project is built with Nix for auditability and reproducibility, and the security claims are scoped to the documented threat model.

## What NAILS OS does

- **Amnesic root filesystem** — `/` is tmpfs and is wiped on shutdown.
- **Mandatory encrypted system volume** — the installer does not offer unencrypted installs; UEFI still requires a small unencrypted EFI system partition.
- **Tor by default** — Tor mode transparently proxies TCP through Tor and forces DNS through Tor.
- **Direct mode available** — you can opt out of Tor during installation if you need ordinary clearnet routing.
- **Selective persistence by default** — documents and selected secrets persist; browser profiles, caches, and several activity metadata stores do not.
- **Shell history disabled by default** — you can opt in during installation.
- **Fixed account naming** — the installed username is always `amnesia` and the display name is `Amnesia`; you choose the password during installation.
- **Public build artifacts** — releases include checksums and build metadata; public releases also support GitHub attestation verification for `checksums.txt`.

Additional safeguards include AppArmor, disabled IPv6, MAC address randomization, no swap, and a curated desktop app set focused on privacy and everyday use.

## Current status

> [!WARNING]
> NAILS OS is **alpha-stage** software. Test it carefully before relying on it.

- **Architecture:** x86_64
- **Boot modes:** UEFI and legacy BIOS
- **Desktop:** GNOME
- **Recommended boot mode:** UEFI

## Quick start

If you are evaluating NAILS OS, try it in a VM first:

1. Download the latest release ISO.
2. Boot it in a UEFI VM with at least 4 GB RAM.
3. Install with the defaults unless you have a specific reason to change them.
4. Review the persistence and boot notes below before using real hardware.

## Threat model summary

NAILS OS is intended to reduce risk from:

- forensic recovery of ordinary system state after shutdown
- local data persistence on shared or borrowed hardware
- network observers when the system is installed in **Tor mode**
- some censorship environments, using bundled Tor pluggable transports in Tor mode

NAILS OS does **not** claim to protect against:

- compromised firmware or malicious hardware
- physical tampering of a powered-off machine
- verified-boot / measured-boot attacks (not currently configured)
- Tor correlation attacks or exit-node observation
- user deanonymization through account use or operational mistakes
- network exposure in **Direct mode**

> [!IMPORTANT]
> Tor-related protections described in this README apply only when the system is installed in **Tor mode**. If you choose **Direct mode**, your traffic uses the clearnet and your IP address is visible.

For BIOS-specific boot-chain limitations, see [`docs/BIOS-SECURITY.md`](docs/BIOS-SECURITY.md).

## Installer choices

The graphical installer currently exposes these choices:

| Step | What you choose |
|---|---|
| Locale / timezone | Regional settings |
| Keyboard | Layout and variant |
| Partitioning | Target disk; encryption is required |
| Password + hostname | Password for the fixed username `amnesia` (you choose it during installation) and system hostname |
| Network routing | **Tor** (default) or **Direct** |
| Shell history | **Disabled** (default) or enabled |
| Home persistence | **Selective** (default) or full home persistence |

The installer does **not** expose a bridge toggle. In Tor mode, the built-in defaults remain in effect.

## Boot and disk layout

| Boot mode | Partitioning and encryption |
|---|---|
| **UEFI** | GPT + separate FAT32 EFI system partition + LUKS2 encrypted system volume |
| **BIOS / Legacy** | MBR + single LUKS1 encrypted system volume; `/boot` lives inside that encrypted volume |

Important behavior differences:

- **An encrypted system volume is mandatory in both modes.**
- **UEFI** uses a separate unencrypted EFI system partition plus an encrypted system volume.
- **BIOS** uses GRUB-compatible **LUKS1**, keeps `/boot` encrypted inside the system volume, and prompts for the passphrase **twice** at boot.

For the full rationale and limitations, see [`docs/BIOS-SECURITY.md`](docs/BIOS-SECURITY.md).

## Network modes

### Tor mode (default)

Tor mode keeps the built-in network defaults:

- transparent proxying for TCP traffic
- DNS forced through Tor
- bundled **obfs4** and **Snowflake** bridges enabled by default
- **Unsafe Browser** available for captive-portal login

This is the mode NAILS OS is primarily designed around.

### Direct mode

If you choose Direct mode during installation, the installer writes `network-mode.nix`, which:

- disables Tor
- uses Quad9 DNS (`9.9.9.9`, `149.112.112.112`)
- re-enables normal NetworkManager DNS handling

Direct mode is faster and simpler, but it removes Tor-routing protections.

## Persistence model

### Runtime layout

- `/` → tmpfs
- `/persist` → encrypted ext4
- `/nix` → bind-mounted from `/persist/nix`
- on BIOS installs, `/boot` → bind-mounted from `/persist/boot`

### What persists by default

By default, NAILS OS uses **selective persistence**. It persists system configuration plus these user locations:

- `Documents`
- `Downloads`
- `Music`
- `Pictures`
- `Videos`
- `Desktop`
- `~/.config/dconf`
- `~/.local/share/keyrings`
- `~/.ssh`
- `~/.gnupg`

### What does not persist in selective mode

These are intentionally left on tmpfs and wiped on reboot:

- full browser profiles and browser session state
- `~/.cache/`
- `~/.local/share/recently-used.xbel`
- `~/.local/share/gvfs-metadata/`
- `~/.local/share/tracker3/`
- `~/.local/share/zeitgeist/`

If you choose **full home persistence**, the installer writes `home-persistence-mode.nix` and persists all of `/home/amnesia` instead.

## Shell history

Shell history is **disabled by default**. If you opt in, the installer writes `shell-history-mode.nix` to restore normal shell history behavior for interactive shells.

Under the default **selective persistence** mode, shell history files still do **not** survive reboot because they are not part of the persisted home set. Cross-reboot shell history requires **full home persistence**.

## Download and verify

Download releases from the [Releases](https://github.com/WitteShadovv/nails-os/releases) page.

Release notes link to the ISO hosted on Cloudflare R2 and include:

- `checksums.txt`
- `build-metadata.json`
- source archives

Verify integrity after downloading:

```bash
sha256sum -c checksums.txt
```

For public releases, you can also verify the GitHub attestation for `checksums.txt`:

```bash
gh attestation verify checksums.txt --repo WitteShadovv/nails-os
```

For current SBOM, dependency, and vulnerability workflow documentation, start at [`docs/security/index.md`](docs/security/index.md). Public vulnerability disclosure remains in [`SECURITY.md`](SECURITY.md).

## Documentation map

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Technical system design and installer behavior |
| [`docs/BIOS-SECURITY.md`](docs/BIOS-SECURITY.md) | BIOS / legacy boot limitations and rationale |
| [`docs/security/index.md`](docs/security/index.md) | Canonical hub for SBOM, dependency hygiene, and vulnerability workflow docs |
| [`SECURITY.md`](SECURITY.md) | Public vulnerability reporting policy |
| [`SUPPORT.md`](SUPPORT.md) | Bug reports, feature requests, and support routing |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Contributor entry point |
| [`docs/CI-OPERATIONS.md`](docs/CI-OPERATIONS.md) | Maintainer CI / release / publication operations |

## For contributors and maintainers

- Contributors should start with [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md).
- Maintainers handling releases or infrastructure should use [`docs/CI-OPERATIONS.md`](docs/CI-OPERATIONS.md).

## Acknowledgments

- [Tails](https://tails.net)
- [NixOS](https://nixos.org)
- [Tor Project](https://www.torproject.org)
- [nix-community/impermanence](https://github.com/nix-community/impermanence)

NAILS has been developed with AI-assisted tooling for drafting code, tests, and documentation. All security-relevant design decisions, code changes, and published documentation remain the responsibility of the maintainer and are intended to be reviewed and validated before release.

## License

NAILS OS is licensed under the **GNU General Public License v3.0**. See [LICENSE](LICENSE).

> [!CAUTION]
> This software is provided without warranties. Use it only after testing it in your own threat environment.
