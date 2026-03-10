# NAILS OS (TAILS-like NixOS)

NAILS OS is a TAILS-inspired NixOS configuration focused on privacy, anti-forensics, and strong defaults. It uses impermanence (tmpfs root + explicit persistence), Tor-by-default networking with transparent proxying, and a curated application set.

This repo contains:
- A flake-based NixOS configuration under `nix-config/`
- An installer ISO build target
- A one-click installer that **wipes a disk**

## Quick start (build installer ISO)

Requirements: Nix with flakes enabled.

```
nix build ./nix-config#nails-os-iso
```

The ISO will be in:
```
result/iso/*.iso
```

## Installer ISO options

### 1) One-click install (DANGER: ERASES DISK)
The installer ISO includes a GUI-driven one-click installer:
- Launches from the desktop as **"NAILS OS One-Click Install (ERASES DISK)"**
- Prompts for target disk, confirmations, LUKS passphrase, and user password
- Prompts for a network mode during installation:
  - **Tor (recommended):** transparent Tor routing with Tor DNS
  - **Direct / non-Tor:** normal clearnet routing with Quad9 DNS (`9.9.9.9`, `149.112.112.112`)
- Creates a GPT disk layout with:
  - EFI system partition
  - A single encrypted `/persist` partition
- Installs NAILS OS using the embedded flake

**This process permanently deletes all data on the selected disk.**

### 2) Manual install
You can also install manually using the config embedded on the ISO:

```
# Partition/mount target to /mnt, then:
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix
nixos-install --flake /etc/nixos#nails-os
```

## Persistence model

- Root is a tmpfs.
- `/persist` is an encrypted ext4 volume.
- `/nix` is a bind-mount inside `/persist`.
- Persistence is explicit and minimal by default.

See `nix-config/modules/impermanence.nix` for the persisted paths.

## Tor and pluggable transports

- Transparent proxying redirects TCP through Tor by default.
- Snowflake transport is enabled by default (bridges are used automatically).
- obfs4 is included so you can add obfs4 bridge lines if needed.
- The installer can also generate a direct / non-Tor host override by writing `nix-config/hosts/nails-os/network-mode.nix` on the installed system.

### Network modes

- **Tor mode (default):**
  - `nailsOs.tor.enable = true`
  - `networking.nameservers = [ "127.0.0.1" ]`
  - `networking.networkmanager.dns = "none"`
  - Enables Tor service, transparent proxying, and nftables redirect rules
- **Direct / non-Tor mode:**
  - `nailsOs.tor.enable = false`
  - `networking.nameservers = [ "9.9.9.9" "149.112.112.112" ]`
  - `networking.networkmanager.dns = "default"`
  - Disables Tor service and Tor-specific transparent proxying

Tor config: `nix-config/modules/tor.nix`
Network defaults: `nix-config/modules/network.nix`

## User account

- Default user: `amnesia`
- The one-click installer prompts for the `amnesia` password and persists it.
- Password hash is stored under `/etc/nixos/modules/secrets` on the installed system.

User config: `nix-config/modules/users.nix`

## Unfree software

VeraCrypt is included and requires unfree allowance. This is handled in:
`nix-config/modules/base.nix` via `allowUnfreePredicate`.

## Repo layout

- `nix-config/flake.nix` - flake entry
- `nix-config/hardware-configuration.nix` - hardware config (canonical path)
- `nix-config/configuration.nix` - compatibility entry point
- `nix-config/hosts/nails-os/` - installed system host config
- `nix-config/hosts/nails-os-iso/` - installer ISO host config
- `nix-config/modules/` - reusable modules
- `nix-config/home/` - Home Manager config
- `.github/workflows/build-iso.yml` - manual ISO build + release upload

## CI/CD (manual)

A GitHub Actions workflow builds the ISO on demand and uploads the ISO and SHA256:
- Trigger: Actions → Build NAILS OS ISO → Run workflow
- Inputs: release tag (e.g. `v0.1.0`)

Workflow: `.github/workflows/build-iso.yml`

## Security notes

- This system is designed to minimize data persistence and enforce Tor-by-default routing.
- Tor remains the recommended mode for privacy. Direct / non-Tor mode is available for cases where Tor connectivity is undesirable or unavailable, but it exposes your IP address and disables Tor-based anonymity protections.
- The one-click installer is intentionally destructive. Use it only on a dedicated disk.
- Review and adjust persisted paths to fit your threat model.

## License

See `LICENSE`.
