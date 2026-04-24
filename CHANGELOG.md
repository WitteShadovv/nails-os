# Changelog

All notable changes to NAILS OS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for commit history.

GitHub Releases currently publish automated **prerelease** ISO builds from `main`, often using
`latest-*` tags. Tagged releases are also supported for versioned snapshots. This changelog remains
the source of truth for ongoing project changes during the current alpha phase. Numbered sections
document project history, but they do not by themselves define a separate long-term supported
release line.

## [Unreleased]

### Added
- Network routing, shell history, and home persistence choosers with icons in the Calamares installer
- Selective home persistence with a curated set of user directories and secrets, plus full-home opt-in
- Shell history disabling option in Calamares
- BIOS/Legacy boot support alongside existing UEFI support (GRUB 2 with LUKS1)
- SBOM generation and dependency hygiene release controls
- Cloudflare R2 hosting for ISO artifacts (bypasses GitHub's 2 GB release-asset limit)
- Hetzner Cloud cost tracking with a €20/month budget gate
- Daily Hetzner failsafe cleanup workflow
- Reproducible ISO build pipeline with ephemeral Hetzner runners (L1 + L2 checks)
- Rolling `latest-*` pre-releases from `main`
- Sigstore build provenance attestation for releases
- obfs4 and Snowflake pluggable-transport bridges enabled by default in Tor mode
- Transparent Tor proxying with nftables — all TCP + DNS routed through Tor in Tor mode
- Unsafe Browser for captive-portal login (sandboxed clearnet user)
- MAC address randomization on every connection
- Kernel hardening (memory zeroing, AppArmor, DMA blacklist, SMT disabled)
- Full-disk encryption enforcement in the installer (UEFI: LUKS2 system volume; BIOS/Legacy: single LUKS1 system volume for GRUB compatibility)
- tmpfs root with declarative persistence via nix-community/impermanence
- Calamares GUI installer with automatic partition layout detection
- GNOME desktop with curated privacy toolkit
- IPv6 disabled to prevent Tor bypass

### Changed
- Clarified public-facing documentation so NAILS OS is described consistently as alpha software with
  current GitHub Releases treated as prerelease ISO publications from `main`.
- Tightened security, support, and contribution language so public claims stay bounded by the
  documented threat model and maintainer review.
- Added clearer explanation of the relationship between NAILS OS and the separate NAILS CLI.

### Fixed
- EFI mount path aligned with the Calamares NixOS mount module
- Chooser icon sizing and scrollbar visibility in the installer
- BIOS boot end-to-end with LUKS1
- Tor transparent-proxy DNS resolution and obfs4 bridge connectivity
- Duplicate EFI partition in the partition layout
- World-writable build directory in the installer
- Username locked to `amnesia` via Calamares preset

## [0.1.0] — Initial development snapshot

Barebones version of NAILS OS — NixOS-based amnesic live system with Tor routing.

[Unreleased]: https://github.com/WitteShadovv/nails-os/compare/main...HEAD
