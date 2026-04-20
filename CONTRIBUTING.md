# Contributing to NAILS OS

Thanks for your interest in improving NAILS OS.

This top-level file exists as the public GitHub entry point. The **canonical contributor guide** lives in [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md), which contains the full workflow, local setup, build commands, testing steps, and security-specific contribution guidance.

## Start Here

- Read the full guide: [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)
- Follow the project code of conduct: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- For security vulnerabilities, use private reporting only: [`SECURITY.md`](SECURITY.md)
- For current SBOM, dependency, and vulnerability workflow docs: [`docs/security/index.md`](docs/security/index.md)
- For bug reports, feature requests, and general support routing: [`SUPPORT.md`](SUPPORT.md)

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
- Use descriptive commits in the project style: `type(scope): short description`.
- Do not open public issues for security vulnerabilities.

If you plan to contribute regularly, use [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) as the source of truth.
