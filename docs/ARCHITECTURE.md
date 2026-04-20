# Architecture

Technical reference for the current NAILS OS system design and installer behavior.

## Overview

NAILS OS is a NixOS-based installed system with three defining properties:

1. **Amnesic root** — `/` is tmpfs and is recreated on every boot.
2. **Encrypted persistence** — most long-lived state lives on an encrypted `/persist` volume; UEFI still requires a small unencrypted EFI system partition.
3. **Tor-first networking** — Tor mode is the default installer choice; Direct mode is opt-in.

The installed user naming model is fixed:

- login name: `amnesia`
- display name: `Amnesia`
- UID: `1000`

The installer lets the user set the password and hostname, but **not** the username or full name. `amnesia` / `Amnesia` is the fixed account name, not a default credential.

## Installer flow

The Calamares UI sequence is:

1. **welcome**
2. **locale**
3. **keyboard**
4. **partition**
5. **users**
6. **network routing** (`Tor` default, `Direct` optional)
7. **shell history** (`disabled` default)
8. **home persistence** (`selective` default)
9. **summary**

The installer currently exposes:

- locale / timezone
- keyboard layout
- target disk and partitioning
- password for the fixed username `amnesia`
- hostname
- network mode
- shell history mode
- home persistence mode

The installer does **not** expose a bridge toggle.

## Boot and storage architecture

### Disk encryption policy

An encrypted system volume is mandatory. The installer does not provide an unencrypted path. In UEFI mode, this still includes a separate unencrypted EFI system partition for boot files.

### Partition layouts

| Boot mode | Layout |
|---|---|
| **UEFI** | GPT + FAT32 EFI system partition + LUKS2 encrypted system volume |
| **BIOS / Legacy** | MBR + single LUKS1 encrypted system volume |

### Boot-mode differences

#### UEFI

- bootloader: `systemd-boot`
- partition table: GPT
- separate EFI system partition: yes
- encrypted system volume format: LUKS2

#### BIOS / legacy

- bootloader: GRUB 2 with `cryptodisk`
- partition table: MBR
- separate plaintext `/boot`: no
- encrypted system volume format: LUKS1
- expected boot behavior: **double passphrase prompt**

On BIOS installs, `/boot` lives inside the encrypted system volume and is bind-mounted from `/persist/boot` at runtime.

See also: [`BIOS-SECURITY.md`](BIOS-SECURITY.md).

## Runtime filesystem layout

| Path | Backing storage | Notes |
|---|---|---|
| `/` | tmpfs | Wiped on shutdown |
| `/persist` | encrypted ext4 | Main persistent volume |
| `/nix` | bind mount from `/persist/nix` | Nix store lives on encrypted storage |
| `/etc/nixos` | persisted under `/persist` | Installed system configuration |
| `/boot/efi` | FAT32 EFI partition | UEFI only |
| `/boot` | bind mount from `/persist/boot` | BIOS only |

There is no separate plaintext `/boot` partition in BIOS mode.

## Generated configuration files

During installation, the custom Calamares exec module writes Nix snippets into `nix-config/hosts/nails-os/` on the target system.

| File | Written when | Effect |
|---|---|---|
| `boot-mode.nix` | Always | Selects `systemd-boot` for UEFI or GRUB for BIOS |
| `locale.nix` | Always | Stores installer locale/timezone and keyboard settings |
| `hostname.nix` | Always | Stores the chosen hostname |
| `modules/secrets.nix` + `modules/secrets/amnesia.passwd` | Always | Stores the hashed password for `amnesia` |
| `network-mode.nix` | Only when Direct mode is chosen | Disables Tor, sets Quad9 DNS, restores normal NetworkManager DNS handling |
| `shell-history-mode.nix` | Only when shell history is enabled | Restores normal shell history behavior; cross-reboot persistence still depends on full home persistence |
| `home-persistence-mode.nix` | Only when full home persistence is chosen | Switches from selective to full-home persistence |

Absence of `network-mode.nix`, `shell-history-mode.nix`, or `home-persistence-mode.nix` means the safe defaults remain in effect.

## Network architecture

### Tor mode

Tor mode is the default installed behavior.

In Tor mode:

- Tor is enabled.
- nftables transparently redirects ordinary TCP traffic to Tor's `TransPort`.
- DNS is forced through Tor's `DNSPort`.
- bundled **obfs4** and **Snowflake** bridges remain enabled by default.
- `Unsafe Browser` is available for captive-portal login.
- NetworkManager is configured not to manage `resolv.conf`; the system points DNS at `127.0.0.1`.

Key implementation details:

- Tor process traffic is exempted so pluggable transports can reach the network directly.
- Tor's own DNS bootstrap path uses Quad9 so bundled pluggable transports can resolve broker addresses before circuits exist.
- IPv6 is disabled system-wide.

### Direct mode

Direct mode is opt-in during installation.

When the user selects Direct mode, the installer writes `network-mode.nix`, which:

- sets `nailsOs.tor.enable = false`
- forces Quad9 DNS servers (`9.9.9.9`, `149.112.112.112`)
- sets `networking.networkmanager.dns = "default"`

In Direct mode, the Tor transparent-proxy rules are not installed and the Tor-specific guarantees described above do not apply.

### Installer scope

The installer currently offers only a **Tor vs Direct** choice. It does **not** expose a bridge on/off control; Tor mode keeps the built-in defaults from `modules/tor.nix`.

## Persistence architecture

### System persistence

These locations persist regardless of home-persistence mode:

- `/etc/nixos`
- `/var/lib/nixos`
- `/var/lib/AccountsService`
- `/var/lib/systemd/backlight`
- `/var/lib/systemd/rfkill`
- `/var/lib/bluetooth`
- `/etc/machine-id`

### Home persistence modes

#### Selective persistence (default)

Selective mode persists only a curated set of user content and secrets:

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

Selective mode intentionally does **not** persist:

- full browser profiles (`~/.mozilla`, Chromium profile data, sessions, cookies, history)
- `~/.cache/`
- `~/.local/share/recently-used.xbel`
- `~/.local/share/gvfs-metadata/`
- `~/.local/share/tracker3/`
- `~/.local/share/zeitgeist/`

#### Full home persistence

If the user chooses full home persistence, the installer writes `home-persistence-mode.nix`, which sets `nailsOs.homePersistence.selective = false` and persists all of `/home/amnesia`.

## Shell history behavior

Shell history is disabled by default.

When disabled, NAILS OS applies multiple layers of history suppression for bash, zsh, and fish. If the user explicitly enables history during installation, the installer writes `shell-history-mode.nix` and the default suppression is lifted.

Under the default selective-persistence mode, shell history files are still wiped on reboot because they are not part of the persisted home set. Cross-reboot shell history only persists when the user also chooses full home persistence.

## Module map

| Module | Responsibility |
|---|---|
| `modules/impermanence.nix` | tmpfs root and persistence declarations |
| `modules/home-persistence.nix` | Selective vs full-home persistence option |
| `modules/shell-history.nix` | Shell history default-off behavior |
| `modules/tor.nix` | Tor daemon, bridges, transparent proxy, Unsafe Browser |
| `modules/network.nix` | NetworkManager defaults, MAC randomization, IPv6 disable |
| `modules/users.nix` | Fixed `amnesia` account and `clearnet` helper user |
| `modules/boot.nix` | EFI partition mount hardening |

## Security-relevant limitations

- NAILS OS does **not** currently configure verified boot.
- BIOS installs use the older GRUB + LUKS1 path for compatibility.
- A powered-off machine is still vulnerable to boot-chain tampering.
- Tor protections apply only when the installed system is in Tor mode.

For public-facing security policy, see [`../SECURITY.md`](../SECURITY.md).
