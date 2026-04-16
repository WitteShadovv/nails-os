# NAILS OS development tasks
# https://github.com/WitteShadovv/nails-os

# Default: list available targets
default:
    @just --list

# Build the NAILS OS ISO image
build:
    nix build ./nix-config#nails-os-iso -L

# Validate that the NixOS configuration evaluates successfully
eval:
    nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath

# Run Nix flake checks (vulnix smoke test)
check:
    nix flake check ./nix-config

# Test the ISO in QEMU with UEFI boot (requires prior `just build`)
test-uefi:
    qemu-system-x86_64 -enable-kvm -m 4096 \
        -bios /usr/share/OVMF/OVMF_CODE.fd \
        -cdrom result/iso/*.iso

# Test the ISO in QEMU with legacy BIOS boot (requires prior `just build`)
test-bios:
    qemu-system-x86_64 -enable-kvm -m 4096 \
        -cdrom result/iso/*.iso

# Run Python unit tests
test-python:
    pytest tests/

# Run linters: nixfmt (check mode), deadnix, statix
lint:
    nixfmt --check nix-config/
    deadnix --fail nix-config/
    statix check nix-config/

# Format all Nix files with nixfmt
fmt:
    nixfmt nix-config/

# Generate a CycloneDX SBOM for the ISO closure
sbom:
    nix build ./nix-config#sbom -L

# Run vulnerability scan against the ISO closure
vuln-scan target="" output="vulnix-results.json":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{target}}" ]; then
        nix run ./nix-config#vulnix-scan -- "{{target}}" "{{output}}"
    else
        TARGET=$(nix path-info ./nix-config#nixosConfigurations.nails-os-iso.config.system.build.toplevel)
        nix run ./nix-config#vulnix-scan -- "$TARGET" "{{output}}"
    fi

# L1 reproducibility check: verify store outputs match their derivations
repro-l1:
    #!/usr/bin/env bash
    set -euo pipefail
    DRV=$(nix path-info --derivation ./nix-config#nails-os-iso)
    nix-store --realise "$DRV" --check -K

# Update flake inputs (nixpkgs, home-manager, impermanence)
update:
    nix flake update --flake ./nix-config

# Verify flake.lock is consistent with flake.nix (no update needed)
lock-check:
    nix flake lock --no-update-lock-file ./nix-config

# Run pre-commit hooks on all files
pre-commit:
    pre-commit run --all-files

# Enter development shell
dev:
    nix develop ./nix-config

# Clean up Nix build result symlinks
clean:
    rm -f result result-*
