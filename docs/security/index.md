# Security Documentation Hub

Canonical current documentation for SBOM, dependency hygiene, vulnerability handling, and security validation.

> [!IMPORTANT]
> This `docs/security/` directory is the authoritative documentation path for current SBOM and security operations guidance.
>
> The older [`../SBOM-DEPENDENCY-VULNERABILITY-ARCHITECTURE.md`](../SBOM-DEPENDENCY-VULNERABILITY-ARCHITECTURE.md) file is retained only as archival design/reference context and may describe proposed or superseded workflows.

## Scope

These documents define how NAILS OS handles:

- dependency pinning in a NixOS/flakes workflow
- SBOM generation and validation
- vulnerability triage, remediation, and disclosure

Canonical dependency pinning artifact: [`nix-config/flake.lock`](../../nix-config/flake.lock).

## Read in Order

1. [Dependency Hygiene](dependency-hygiene.md)
2. [Vulnerability Handling](vulnerability-handling.md)
3. [Security Validation](security-validation.md)

## Canonical Interfaces

Use these project interfaces and artifact names in docs, CI, and release workflows:

| Interface / Artifact | Canonical command or filename |
|---|---|
| SBOM generation command | `nix build ./nix-config#sbom` |
| vulnix scan command | `nix run ./nix-config#vulnix-scan -- <target> <output>` |
| SBOM artifact filename | `dist/nails-os-sbom.cdx.json` |
| vulnix results filename | `dist/vulnix-results.json` |
| CI/release security artifact path | Cloudflare R2 `${R2_PREFIX}/security/` (for example `stable/security/nails-os-sbom.cdx.json`) |

## Public Policy

- Public vulnerability policy and reporting SLA: [`../../SECURITY.md`](../../SECURITY.md)
- BIOS/legacy boot limitation notes: [`../BIOS-SECURITY.md`](../BIOS-SECURITY.md)
- Archival design/reference context: [`../SBOM-DEPENDENCY-VULNERABILITY-ARCHITECTURE.md`](../SBOM-DEPENDENCY-VULNERABILITY-ARCHITECTURE.md)

## Ownership and Maintenance Cadence

Recommended minimum cadence:

- **Weekly:** dependency review + vulnerability scan review
- **Monthly:** security doc accuracy pass (commands, links, workflow drift)
- **Quarterly:** policy/SLA review and exception cleanup

Recommended owners:

- **Security policy owner:** repository maintainer
- **Dependency hygiene owner:** release/infra maintainer
- **Validation tooling owner:** CI maintainer

If the project has a single maintainer, one person can hold all roles; keep cadence explicit.
