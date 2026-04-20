# Security Policy

Public vulnerability policy for NAILS OS.

This file is the **canonical public policy** for vulnerability reporting, support boundaries, and disclosure expectations.

For the **canonical current SBOM, dependency hygiene, and vulnerability workflow docs**, start at [`docs/security/index.md`](docs/security/index.md).

Historical planning context remains in [`docs/SBOM-DEPENDENCY-VULNERABILITY-ARCHITECTURE.md`](docs/SBOM-DEPENDENCY-VULNERABILITY-ARCHITECTURE.md), but that file is archival/reference material and not the current source of truth.

## Supported Versions

NAILS OS is a rolling live ISO. Only the latest stable release is supported for security fixes.

| Version | Supported | Notes |
|---|---|---|
| Latest stable release | ✅ Yes | Security fixes are shipped here |
| Older stable releases | ❌ No | No backport/LTS policy |
| Pre-releases (`latest-*`) | ⚠️ Best effort | Testing only |

## Reporting a Vulnerability

> Do not open public GitHub issues for security vulnerabilities.

### Preferred channel (private)

Use GitHub private reporting:

- <https://github.com/WitteShadovv/nails-os/security/advisories/new>

### Alternate channel

- Email: `security@nails.run`

If available, include encrypted details (PGP/public key exchange by email).

### What to include

- Affected component (module/package/workflow)
- Reproduction steps
- Impact and likely attacker prerequisites
- Any logs, PoC, or suggested fix
- Disclosure intent/timeline (if any)

## Response SLA (by severity)

> **Note:** NAILS OS is maintained by a solo developer. The targets below are best-effort goals, not guaranteed SLAs. Response times may vary.

SLA starts after report acknowledgment.

| Severity | Acknowledge | Triage target | Fix target | Public advisory |
|---|---:|---:|---:|---:|
| Critical | 48h | 24h | 24–72h | Immediately after fix release |
| High | 48h | 3 days | 7 days | Within 7 days after fix |
| Medium | 7 days | 7 days | 30 days | Within 30 days after fix |
| Low | 14 days | 14 days | 90 days / next planned release | With release notes/advisory |

Severity is assigned in NAILS OS context (Tor routing, persistence, encryption, and anti-forensic guarantees).

## Disclosure Policy

- Coordinated disclosure default: **up to 90 days**.
- Critical user-safety issues may be disclosed earlier once a fix is available.
- We may request an extension when upstream fixes are pending.
- Reporter credit is included by default unless anonymity is requested.

## Dependency and SBOM Policy (public summary)

- Canonical current documentation hub: [`docs/security/index.md`](docs/security/index.md)
- `nix-config/flake.lock` is the canonical dependency pinning artifact.
- Security-relevant dependency updates are performed on a regular cadence, with an emergency path for Critical CVEs.
- SBOM and vulnerability validation are documented in:
  - [`docs/security/dependency-hygiene.md`](docs/security/dependency-hygiene.md)
  - [`docs/security/vulnerability-handling.md`](docs/security/vulnerability-handling.md)
  - [`docs/security/security-validation.md`](docs/security/security-validation.md)

## Related Security Notes

- BIOS/legacy evil-maid limitation: [`docs/BIOS-SECURITY.md`](docs/BIOS-SECURITY.md)

Thank you for helping improve NAILS OS security.
