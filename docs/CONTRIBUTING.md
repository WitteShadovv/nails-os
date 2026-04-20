# Contributing

Canonical contributor guide for NAILS OS. The top-level [`../CONTRIBUTING.md`](../CONTRIBUTING.md) file is the public GitHub entry point; this document contains the full workflow and local commands.

NAILS OS is security-sensitive alpha software. Contributions should be clear, testable, and consistent with the documented threat model.

For general project overview, see [`../README.md`](../README.md).
For architecture details, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

> If you are reporting a security vulnerability, do **not** open a public issue. Follow [`../SECURITY.md`](../SECURITY.md).

## Before You Start

Before investing significant work:

1. Search for an existing issue or pull request.
2. For non-trivial changes, open an issue first so maintainers can confirm scope and fit.
3. Keep proposals grounded in the current alpha status of the project.
4. Make sure your change belongs in **NAILS OS** rather than the separate `nails` CLI repository.

## Development Setup

### Prerequisites

| Tool | Notes |
| --- | --- |
| Nix with flakes enabled | Recommended for reproducible development and evaluation |
| `pre-commit` | Recommended for running the repository's local validation hooks |
| QEMU | Useful for ISO smoke testing |
| OVMF | Needed for UEFI QEMU tests |
| Python 3 | Needed for some helper scripts |

### Basic setup

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

   Common prefixes include `feat/`, `fix/`, `docs/`, `refactor/`, and `ci/`.

4. Enable flakes in `~/.config/nix/nix.conf` if needed:

   ```text
   experimental-features = nix-command flakes
   ```

5. Enter the development shell if available:

   ```bash
   nix develop ./nix-config
   ```

6. Install local hooks if you use `pre-commit`:

   ```bash
   pre-commit install
   ```

The hook set is intentionally broader than formatting alone. It is meant to catch the same classes of problems that would otherwise fail later in review or CI.

## Local Validation

Run the relevant checks before opening a pull request:

```bash
# Validate the configuration evaluates successfully
nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath

# Build the ISO
nix build ./nix-config#nails-os-iso

# Run repository hooks
pre-commit run --all-files
```

Optional local cleanliness guard (matches CI's tracked-junk check):

```bash
python3 .github/scripts/check_tracked_cleanliness.py
```

This guard checks **tracked git paths only**. Ignored local files are allowed.

## Testing Changes

Test behavior in the modes affected by your change when practical:

```bash
# Test in QEMU (UEFI mode — requires OVMF)
qemu-system-x86_64 -enable-kvm -m 4096 -bios /usr/share/OVMF/OVMF_CODE.fd -cdrom result/iso/*.iso

# Test in QEMU (BIOS / legacy mode)
qemu-system-x86_64 -enable-kvm -m 4096 -cdrom result/iso/*.iso
```

If your change affects installer behavior, persistence defaults, routing, or boot flow, say clearly what you tested and what remains unverified.

## Contribution Guidelines

### Keep changes focused

- Prefer small, reviewable pull requests.
- Separate refactors from behavior changes when practical.
- Update documentation when behavior, interfaces, or contributor workflows change.
- Avoid broad claim changes unless the implementation and threat-model docs support them.

### Nix expectations

- Format with **nixfmt** (enforced by pre-commit).
- Use `lib.mk*` functions for option declarations.
- Guard optional imports with `lib.optional (builtins.pathExists ...)`.
- Keep modules focused — one concern per file.
- Avoid `with pkgs;` in module-level scope; prefer explicit `pkgs.foo`.

### Python expectations (Calamares modules)

- Follow PEP 8.
- Use `libcalamares.utils.debug()` for logging.
- Handle errors by returning `(title, message)` tuples — never raise unhandled exceptions in `run()`.
- Use `run_cmd()` / `run_stream()` helpers for subprocess calls.

### Security expectations

Because NAILS OS is security-sensitive:

- avoid logging or persisting sensitive material unless there is a documented reason
- fail safely when validation or cleanup cannot complete
- document tradeoffs clearly when a change affects persistence, routing, or boot assumptions
- call out threat-model implications in your PR description when relevant
- do not introduce unsupported or overstated security claims in docs or UI text

## Pull Request Process

1. Make the smallest change that solves the problem well.
2. Run the relevant local checks before opening a pull request.
3. Explain the motivation, approach, and any user-visible impact.
4. Note any effect on persistence, Tor/Direct routing behavior, boot mode handling, or release/operator guidance.
5. Link related issues when applicable.

Maintainers may request changes to scope, design, tests, or documentation before merge.

## Commit Messages

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) for consistency.

Examples:

- `feat(installer): add tor chooser with icons`
- `fix(ci): correct R2 upload path for releases`
- `docs(readme): update build instructions`
- `refactor(tor): extract bridge configuration`

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

- Primary private channel: `security@nails.run`
- Alternate private channel: <https://github.com/WitteShadovv/nails-os/security/advisories/new>

## Submitting Security Fixes

When your PR addresses a CVE, GHSA, or other security defect:

1. Reference the issue identifier in the PR title or body when it is safe to do so.
2. Include before/after scan evidence when relevant.
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
- user-facing README or support docs when operator expectations change

## Code of Conduct

All participation in this project is governed by [`../CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md).

Be respectful, assume good intent, and keep collaboration focused on the work.
