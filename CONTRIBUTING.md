# Contributing to NAILS OS

Thanks for your interest in improving NAILS OS.

NAILS OS is security-sensitive alpha software. We value contributions that are clear, testable, and consistent with the project's documented threat model.

> If you are reporting a security vulnerability, do **not** open a public issue. Follow [SECURITY.md](SECURITY.md) instead.

This top-level file is the public GitHub entry point. The **canonical contributor guide** lives in [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md), which contains the full workflow, local setup, build commands, testing steps, and security-specific contribution guidance.

## Start Here

- Read the full guide: [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)
- Follow the project code of conduct: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- For security vulnerabilities, use private reporting only: [`SECURITY.md`](SECURITY.md)
- For current SBOM, dependency, and vulnerability workflow docs: [`docs/security/index.md`](docs/security/index.md)
- For bug reports, feature requests, and general support routing: [`SUPPORT.md`](SUPPORT.md)

## Before You Start

Before investing significant work:

1. Search for an existing issue or pull request.
2. For non-trivial changes, open an issue first so maintainers can confirm scope and fit.
3. Keep proposals grounded in the current alpha status of the project.
4. Make sure your change belongs in **NAILS OS** rather than the separate `nails` CLI repository.

## Contributor Quick Start

1. Fork the repository and create a branch from `main`.
2. Set up a Nix environment with flakes enabled.
3. Install pre-commit hooks:

   ```bash
   pre-commit install
   ```

4. Validate and test your change before opening a pull request:

   ```bash
   nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath
   nix build ./nix-config#nails-os-iso
   ```

5. Open a pull request against `main`. GitHub provides the repository pull request template; fill in the relevant sections and note any threat-model impact.

## Before You Open a Pull Request

- Keep changes focused and reviewable.
- Update documentation when behavior or operator workflow changes.
- Call out any impact on persistence, routing defaults, boot behavior, or release/operator guidance.
- Use descriptive commits in the project style: `type(scope): short description`.
- Do not open public issues for security vulnerabilities.

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) for consistency.

If you plan to contribute regularly, use [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) as the source of truth.
