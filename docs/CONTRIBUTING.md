# Contributing

Canonical contributor guide for NAILS OS. The top-level [`../CONTRIBUTING.md`](../CONTRIBUTING.md) file is the public GitHub entry point; this document contains the full workflow and local commands.

For general project overview, see [`../README.md`](../README.md).
For architecture details, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Getting Started

### Fork → Branch → PR Workflow

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/nails-os.git
   cd nails-os
   ```
3. **Create a branch** from `main`:
   ```bash
   git checkout -b feat/my-change
   ```
   Use prefixes: `feat/`, `fix/`, `docs/`, `refactor/`, `ci/`.
4. **Make your changes**, commit with descriptive messages.
5. **Push** to your fork:
   ```bash
   git push origin feat/my-change
   ```
6. **Open a Pull Request** against `main` on the upstream repository. GitHub provides the repository pull request template; complete the relevant sections and note any threat-model impact.

### Dev Environment Setup

NAILS OS uses Nix flakes. Install [Nix](https://nixos.org/download) and enable flakes in `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

Enter the development shell (if a `devShell` is configured):

```bash
nix develop ./nix-config
```

Install pre-commit hooks:

```bash
pre-commit install
```

Hooks include: `nixfmt` (formatting), `deadnix` (dead code), `statix` (linting), `nix-instantiate --parse` (syntax), `detect-secrets`, standard checks (trailing whitespace, YAML/JSON validation, merge conflict detection), and a full NixOS configuration evaluation.

Optional local cleanliness guard (matches CI's tracked-junk check):

```bash
python3 .github/scripts/check_tracked_cleanliness.py
```

This guard checks **tracked git paths only**. Ignored local files are allowed.

### Building the ISO

```bash
nix build ./nix-config#nails-os-iso

# Find the built ISO
ls result/iso/
```

### Testing Changes

```bash
# Validate the configuration evaluates successfully
nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath

# Test in QEMU (UEFI mode — requires OVMF)
qemu-system-x86_64 -enable-kvm -m 4096 -bios /usr/share/OVMF/OVMF_CODE.fd -cdrom result/iso/*.iso

# Test in QEMU (BIOS/Legacy mode)
qemu-system-x86_64 -enable-kvm -m 4096 -cdrom result/iso/*.iso
```

## Coding Style

### Nix

- Format with **nixfmt** (enforced by pre-commit).
- Use `lib.mk*` functions for option declarations.
- Guard optional imports with `lib.optional (builtins.pathExists ...)`.
- Keep modules focused — one concern per file.
- Avoid `with pkgs;` in module-level scope; prefer explicit `pkgs.foo`.

### Python (Calamares modules)

- Follow PEP 8.
- Use `libcalamares.utils.debug()` for logging.
- Handle errors by returning `(title, message)` tuples — never raise unhandled exceptions in `run()`.
- Use `run_cmd()` / `run_stream()` helpers for subprocess calls.

### Commit Messages

Follow the conventional format used in the project:

```
type(scope): short description

# Examples:
feat(installer): add tor chooser with icons
fix(ci): correct R2 upload path for releases
docs(readme): update build instructions
refactor(tor): extract bridge configuration
```

## Pull Request Checklist

- [ ] Configuration evaluates: `nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath`
- [ ] ISO builds: `nix build ./nix-config#nails-os-iso`
- [ ] Pre-commit hooks pass
- [ ] No unrelated lockfile churn in `flake.lock`
- [ ] Documentation updated if behavior changed

## Security and Dependency Workflow

Security-related contributions must follow the docs in [`security/`](security/):

- [Security docs hub](security/index.md)
- [Dependency hygiene](security/dependency-hygiene.md)
- [Vulnerability handling](security/vulnerability-handling.md)
- [Security validation](security/security-validation.md)
- Public vulnerability policy: [`../SECURITY.md`](../SECURITY.md)

## Reporting Security Issues

Do **not** open public issues for vulnerabilities.

- Preferred: GitHub private advisory reporting
  - <https://github.com/WitteShadovv/nails-os/security/advisories/new>
- Alternate: `security@nails.run`

## Submitting Security Fixes

When your PR addresses a CVE/GHSA/security defect:

1. Reference the issue identifier in the PR title/body.
2. Include before/after scan evidence.
3. Update `nix-config/flake.lock` if dependency remediation is required.
4. Run validation commands from [`security/security-validation.md`](security/security-validation.md).

## Routine Dependency Update Contributions

- Use the cadence in [`security/dependency-hygiene.md`](security/dependency-hygiene.md).
- Do not rely on pre-commit hooks to auto-update `flake.lock`; update it intentionally in the PR when required.
- Keep updates small and reviewable.
- For emergency updates, follow [`security/vulnerability-handling.md`](security/vulnerability-handling.md).

## Documentation Maintenance

When changing security behavior, update docs in the same PR:

- public policy (`../SECURITY.md`) if user-facing impact changes
- internal operational docs under `security/`

Recommended maintenance cadence:

- weekly: scan + dependency review
- monthly: docs link/command verification
- quarterly: policy/SLA review

## Code of Conduct

All participation in this project is governed by [`../CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md).

Be respectful, assume good intent, and keep collaboration focused on the work.
