# NAILS OS

**An amnesic, anti-forensic operating system. All traffic through Tor. Nothing survives reboot. Built declaratively on NixOS.**

[![Build ISO](https://github.com/WitteShadovv/nails-os/actions/workflows/build-iso.yml/badge.svg)](https://github.com/WitteShadovv/nails-os/actions/workflows/build-iso.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![NixOS 25.11](https://img.shields.io/badge/NixOS-25.11-5277C3.svg?logo=nixos&logoColor=white)](https://nixos.org)

NAILS OS is a live Linux distribution designed for privacy, anonymity, and anti-forensic resistance. It routes all network traffic through Tor, runs entirely from RAM, and leaves no trace on the host machine after shutdown. The desktop environment is **GNOME**. Built declaratively on NixOS for reproducibility and auditability.

Designed for journalists, activists, researchers, and anyone who needs to leave no trace on shared or borrowed hardware.

## Table of Contents

- [Key Features](#key-features)
- [Threat Model](#threat-model)
- [System Requirements](#system-requirements)
- [Download](#download)
- [Quick Start](#quick-start)
- [ISO Verification](#iso-verification)
- [Installation](#installation)
- [Network Modes](#network-modes)
- [Persistence Model](#persistence-model)
- [CI/CD Pipeline](#cicd-pipeline)
- [Repository Setup for CI/CD](#repository-setup-for-cicd)
- [Cost Tracking & Budget Protection](#cost-tracking--budget-protection)
- [Repository Structure](#repository-structure)
- [Security Documentation](#security-documentation)
- [Contributing](#contributing)
- [Acknowledgments](#acknowledgments)
- [License](#license)

## Key Features

- **Amnesic by default** — root filesystem is wiped on every reboot. Nothing persists unless explicitly declared on an encrypted volume.
- **Tor by default** — all network traffic is transparently routed through Tor, including DNS. No traffic leaks.
- **Pluggable transports** — obfs4 and Snowflake bridges are preconfigured for censorship circumvention.
- **Full-disk encryption** — the installer enforces LUKS2 encryption. It will refuse to proceed without it.
- **Kernel hardening** — memory zeroing on alloc/free, AppArmor, DMA attack surface removed (FireWire/Thunderbolt/USB4 blacklisted), SMT disabled, Spectre and MDS mitigations enabled.
- **MAC address randomization** — WiFi and Ethernet MAC addresses are randomized on every connection. DHCP hostname sending is disabled.
- **Curated privacy toolkit** — Tor Browser, OnionShare, Electrum, Thunderbird, Pidgin with OTR, KeePassXC, VeraCrypt, MAT2 (metadata removal), GnuPG, and more.
- **Unsafe Browser** — a sandboxed browser (separate system user, dedicated firewall rules) that bypasses Tor, strictly for captive portal login.
- **Reproducible builds** — CI performs two levels of reproducibility verification: L1 same-store check and L2 full rebuild comparison.
- **IPv6 disabled** — prevents IPv6 address leaks that could bypass Tor anonymity.

## Threat Model

NAILS OS is designed to protect against:

- **Forensic analysis of the device** — tmpfs root means no trace after shutdown, unless the attacker has access to the encrypted persistent volume.
- **Network surveillance** — all traffic goes through Tor; MAC addresses are randomized; DHCP does not leak the hostname.
- **Data persistence on shared or borrowed hardware** — boot from USB, leave no trace.
- **Censorship** — pluggable transports help circumvent Tor blocking in restrictive networks.

NAILS OS does **not** protect against:

- **Targeted attacks by well-resourced adversaries with physical access** to the running machine (cold boot attacks, hardware implants).
- **Compromised firmware or BIOS** — NAILS OS runs on commodity hardware and trusts the firmware layer.
- **Evil maid attacks on BIOS installs** — on BIOS/legacy hardware the `/boot` partition is unencrypted and can be tampered with by an attacker with physical access to the powered-off machine. See [`docs/SECURITY.md`](docs/SECURITY.md).
- **User error** — if you log into personal accounts over Tor, you deanonymize yourself.
- **Correlation attacks** — a global passive adversary can correlate Tor entry and exit traffic.
- **Exit node eavesdropping** — unencrypted traffic leaving the Tor network is visible to the exit relay. Always use HTTPS or end-to-end encryption for sensitive communications.

> The network protections listed above apply only in Tor mode. If you choose Direct mode during installation, your IP address and network traffic are fully visible.

No software can substitute for sound operational security practices.

## System Requirements

| Requirement | Details |
|---|---|
| Architecture | x86_64 only |
| Boot | UEFI (systemd-boot) or Legacy BIOS (GRUB 2) |
| RAM | 4 GB minimum (root filesystem runs entirely from RAM) |
| USB | 4 GB minimum for the installer ISO |
| Disk | Any size; fully encrypted. EFI: 1 GiB FAT32 + LUKS2. BIOS: 1 MiB bios_grub + 1 GiB ext4 `/boot` + LUKS2. |

## Download

Download the latest ISO from the [Releases](https://github.com/WitteShadovv/nails-os/releases) page. Each release includes:

- **ISO download link** (hosted on Cloudflare R2)
- `checksums.txt` — checksum file for integrity verification
- `build-metadata.json` — full build provenance (commit, Nix version, reproducibility status)
- Source code archives

> The ISO is ~4 GB. It is hosted externally on Cloudflare R2 because GitHub Releases has a 2 GB per-asset limit. The download link is in the release notes.

**Stable releases** use versioned tags (`v*`). **Rolling builds** from `main` are tagged `latest-{commit}` and marked as pre-releases.

After downloading, verify integrity:

```bash
# Download checksums.txt from the same release, then:
sha256sum -c checksums.txt
```

See [ISO Verification](#iso-verification) for build provenance verification.

## Quick Start

Requires [Nix with flakes enabled](https://nixos.org/download) (enable flakes in `~/.config/nix/nix.conf`).

```bash
nix build ./nix-config#nails-os-iso

# Find the built ISO
ls result/iso/

# Write to USB (replace /dev/sdX — double-check the target device!)
sudo dd if=result/iso/<filename>.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## ISO Verification

If you downloaded a release ISO, verify its integrity before writing to USB:

```bash
# Verify ISO checksum
sha256sum -c checksums.txt

# Verify build provenance attestation (requires gh CLI)
# The attestation covers checksums.txt, which contains the ISO checksum.
gh attestation verify checksums.txt --repo WitteShadovv/nails-os
```

## Installation

### GUI Installer

> :warning: **WARNING:** The installer erases the entire target disk. All existing data will be permanently destroyed.

1. Boot the ISO from USB.
2. The Calamares installer launches from the desktop.
3. Select locale, keyboard, and target disk.
4. Set a password for the `amnesia` user account.
5. Choose network routing: Tor (recommended) or Direct.
6. Review and install.
7. Reboot into NAILS OS. The system boots into a GNOME desktop.

The installer detects the boot mode and creates the appropriate layout. On UEFI systems: a 1 GiB FAT32 EFI partition and a LUKS2-encrypted root. On BIOS/legacy systems: a 1 MiB BIOS boot partition, a 1 GiB ext4 `/boot` (unencrypted), and a LUKS2-encrypted root. See [`docs/SECURITY.md`](docs/SECURITY.md) for the security implications of the unencrypted `/boot` on BIOS. Root runs as tmpfs; `/persist` holds the Nix store and user home on the encrypted volume.

**Default user:** `amnesia` (UID 1000, member of wheel, networkmanager, video, audio).

### Manual Installation

```bash
# Partition and mount your target to /mnt, then:
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
nixos-install --flake /etc/nixos#nails-os
```

## Network Modes

- **Tor (default):** All TCP transparently proxied through Tor. DNS resolved through Tor. Unsafe Browser available for captive portals. obfs4 and Snowflake bridges active.
- **Direct:** Normal clearnet routing with Quad9 DNS (9.9.9.9, 149.112.112.112). No Tor. Your IP address is visible to the network.

The network mode is chosen during installation. It can be changed post-install by editing `nix-config/hosts/nails-os/network-mode.nix`.

## Persistence Model

Root is tmpfs — wiped every reboot. Only these paths survive on the encrypted `/persist` volume:

- `/etc/nixos` — system configuration
- `/home/amnesia` — user home directory
- `/var/lib/nixos` — UID/GID state
- `/etc/machine-id` — systemd identity
- A small set of hardware state (Bluetooth pairings, backlight, rfkill)

Everything else — logs, temp files, browser state, application data outside home — is gone after power-off. Full list: [`nix-config/modules/impermanence.nix`](nix-config/modules/impermanence.nix).

## CI/CD Pipeline

The project uses an automated CI/CD pipeline with ephemeral Hetzner Cloud servers as GitHub Actions runners.

**Build pipeline** (`build-iso.yml`): Triggered on pushes to `main`, pull requests, manual dispatch, or as a reusable workflow. Provisions an ephemeral build server on Hetzner Cloud, builds the ISO, runs L1 and L2 reproducibility checks, then unconditionally destroys the server.

**Release pipeline** (`release.yml`): Triggered on `v*` tag pushes or manual dispatch. Calls the build pipeline, then creates a GitHub Release with the ISO, checksums.txt, and build metadata as release assets. Generates Sigstore build provenance attestation (verifiable with `gh attestation verify`).

**Failsafe cleanup** (`hetzner-cleanup.yml`): Runs daily at 00:01 UTC. Destroys any servers remaining in the Hetzner project to prevent orphaned servers from accruing charges. Creates a GitHub Issue notification if any servers were cleaned up.

## Repository Setup for CI/CD

### Required Secrets

Configure under Settings > Secrets and variables > Actions > Secrets:

| Secret | Description |
|---|---|
| `PERSONAL_ACCESS_TOKEN` | GitHub fine-grained PAT with Administration read/write scope on this repository. Used for self-hosted runner registration. |
| `HCLOUD_TOKEN` | Hetzner Cloud API token with Read & Write permissions. Used to provision and destroy build servers. |

### Required Variables

Configure under Settings > Secrets and variables > Actions > Variables:

| Variable | Description |
|---|---|
| `HCLOUD_SSH_KEY_ID` | **Numeric ID** of an SSH key uploaded to your Hetzner Cloud project. When set, the build server is provisioned with this key and Hetzner will not email a root password. If omitted, the pipeline still works but Hetzner sends a root password email for every build. |

**Important:** `HCLOUD_SSH_KEY_ID` requires the **numeric ID** of the SSH key — not its name or fingerprint. To find it: go to [Hetzner Cloud Console](https://console.hetzner.cloud) > your project > Security > SSH Keys, click the key, and copy the ID shown in the URL or key details (a number like `12345678`).

## Cost Tracking & Budget Protection

The CI pipeline includes automatic Hetzner Cloud cost tracking to prevent runaway spending.

### Budget gate (€20/month)

Before provisioning a build server, the pipeline queries the Hetzner Cloud API to estimate current project spending based on all running servers. If the estimate exceeds **€20 (gross)**, the workflow aborts immediately — no server is created.

> **Note:** This is an estimate based on currently running servers, not Hetzner's actual billing. It serves as a safety net against accidental resource leaks or runaway builds.

### Session cost reporting

After each build, the pipeline calculates the cost of the ephemeral CI runner session:
- Server hourly rate (from the Hetzner pricing API)
- Primary IPv4 hourly rate (if applicable)
- Hours billed (rounded up — Hetzner's minimum billing unit is 1 hour)

The session cost appears in the **Build Summary** table in the GitHub Actions job summary.

### Cumulative cost tracking

When the CI runner is cleaned up, the pipeline:
1. Calculates the session cost
2. Reads the running total from the repository variable `HETZNER_CUMULATIVE_COST_EUR`
3. Updates the total
4. Writes a cost summary (session, cumulative, budget remaining) to the job summary

The `HETZNER_CUMULATIVE_COST_EUR` variable is created automatically on the first run. To reset it (e.g., at the start of a new billing cycle), delete the variable or set it to `0`.

## Repository Structure

```
nails-os/
  .github/workflows/
    build-iso.yml              # ISO build + reproducibility CI
    release.yml                # GitHub Release publishing
    hetzner-cleanup.yml        # Daily failsafe server cleanup
  nix-config/
    flake.nix                  # Flake entry point
    flake.lock                 # Pinned dependencies
    configuration.nix          # Compatibility shim
    hardware-configuration.nix # Generated hardware config
    hosts/
      nails-os/                # Installed system configuration
      nails-os-iso/            # Installer ISO configuration + Calamares
    modules/                   # Reusable NixOS modules
      base.nix                 # Base system settings
      boot.nix                 # bootloader (systemd-boot or GRUB), initrd, kernel
      home.nix                 # Home Manager integration
      storage.nix              # Disk layout, LUKS, mount points
      tor.nix                  # Tor transparent proxy + bridges + nftables
      security.nix             # Kernel hardening, AppArmor
      impermanence.nix         # tmpfs root + persistence declarations
      network.nix              # MAC randomization, DNS, IPv6 disable
      packages.nix             # Application manifest
      users.nix                # User accounts
      ...
    home/                      # Home Manager configuration
    overlays/                  # Package overlays
  LICENSE
```

## Security Documentation

- Public vulnerability policy: [`SECURITY.md`](SECURITY.md)
- Security operations hub (SBOM, dependency hygiene, vulnerability workflow): [`docs/security/index.md`](docs/security/index.md)

## Contributing

The project uses pre-commit hooks for code quality:

```bash
pre-commit install
```

Hooks include: `nixfmt` (formatting), `deadnix` (dead code), `statix` (linting), `nix-instantiate --parse` (syntax), `detect-secrets`, standard checks (trailing whitespace, YAML/JSON validation, merge conflict detection), and a full NixOS configuration evaluation.

Dependency updates are intentional and maintainer-reviewed. Follow the policy in [`docs/security/dependency-hygiene.md`](docs/security/dependency-hygiene.md).

To test changes locally:

```bash
# Validate the configuration evaluates successfully
nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath

# Build the ISO
nix build ./nix-config#nails-os-iso

# Test in QEMU (no USB needed)
qemu-system-x86_64 -enable-kvm -m 4096 -bios /usr/share/OVMF/OVMF_CODE.fd -cdrom result/iso/*.iso

# Test BIOS/Legacy mode install
qemu-system-x86_64 -enable-kvm -m 4096 -cdrom result/iso/*.iso
```

## Acknowledgments

- [Tails](https://tails.net) — the original amnesic privacy OS, and the inspiration for this project
- [NixOS](https://nixos.org) — the declarative, reproducible Linux distribution that makes this possible
- [Tor Project](https://www.torproject.org) — for the anonymity network and pluggable transports
- [nix-community/impermanence](https://github.com/nix-community/impermanence) — tmpfs root and declarative persistence
- [Cyclenerd/hcloud-github-runner](https://github.com/Cyclenerd/hcloud-github-runner) — ephemeral Hetzner Cloud runners for GitHub Actions

Development of NAILS was assisted by Claude (Anthropic) — Sonnet and Opus models were used for code generation, testing, and documentation throughout the project.
All code has been reviewed, tested, and validated by the author.

## License

This project is licensed under the **GNU General Public License v3.0**.
See [LICENSE](LICENSE) for the full text.

> **Disclaimer:** This software is for educational and security research purposes.
> Users are solely responsible for compliance with applicable laws and regulations.
> The authors make no warranties — express or implied — about the security properties
> of this software in any specific threat environment.
>
> **Use at your own risk. Test thoroughly before relying on it.**
