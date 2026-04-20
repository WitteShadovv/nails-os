# Security Policy

NAILS OS is security-sensitive alpha software. This policy explains what qualifies as a security issue, how to report one privately, and how the project handles coordinated disclosure.

For the canonical current SBOM, dependency hygiene, and vulnerability workflow docs, start at [`docs/security/index.md`](docs/security/index.md).

## Scope

This policy applies to security issues in the NAILS OS repository and its officially published release artifacts, including:

- the live ISO, graphical installer, and NixOS configuration in this repository
- NAILS OS-specific persistence, routing, and boot-path behavior implemented here
- official release metadata such as published checksums and build metadata
- official GitHub prerelease ISO publications from this repository

This policy does **not** cover:

- vulnerabilities in upstream projects such as NixOS, Nixpkgs, Calamares, Tor, GRUB, the Linux kernel, or firmware
- local deployment mistakes, unsupported modifications, or custom fork behavior
- general hardening advice that does not describe a specific vulnerability in this repository
- physical access, coercion, firmware compromise, or other threats outside the software boundary

If you are unsure whether something is in scope, report it anyway. It is better to review a borderline report than miss a real issue.

## Supported Versions

NAILS OS is currently released as **alpha** software. Security fixes are applied to the latest supported release line first.

| Version | Status | Security support |
| --- | --- | --- |
| Latest GitHub prerelease from `main` | Current alpha ISO publication | Security fixes are applied here first |
| Earlier GitHub prereleases in the current alpha series | Superseded | Not supported |
| Locally modified or forked builds | Unofficial | Not supported |

There is no separate stable or LTS release line yet. Because the project is pre-1.0, we recommend upgrading to the latest published prerelease instead of relying on backported fixes.

## Reporting a Vulnerability

### Private reporting channel

Report vulnerabilities by email to **security@nails.run**.

If you prefer GitHub's private reporting flow, you may also use:

- <https://github.com/WitteShadovv/nails-os/security/advisories/new>

Please **do not** open public GitHub issues, discussions, or pull requests for suspected vulnerabilities.

If you accidentally disclose something sensitive in public, edit the report if possible and contact us at `security@nails.run`.

### What to include

Please include as much of the following as you can:

- affected version, release, or commit
- environment details relevant to reproduction
- clear reproduction steps or proof of concept
- expected security boundary and observed failure
- impact assessment and any suggested mitigations
- whether and how you would like to be credited

### What to expect from us

We normally:

- acknowledge receipt within **72 hours**
- communicate an initial triage assessment within **7 days**
- keep you informed if remediation will take longer

These are response targets rather than guaranteed SLAs, but they are the standards we use to keep reports moving and reporters informed.

## Coordinated Disclosure

We ask reporters to avoid public disclosure until:

- a fix is available, or
- we agree on a disclosure date together

In return, we will:

- investigate reports in good faith
- work toward a fix or mitigation appropriate to the severity
- coordinate publication when a fix is ready
- credit the reporter unless anonymity is requested

Our default goal is coordinated disclosure within **90 days**, but we may shorten or extend that window depending on severity, active exploitation, fix complexity, upstream dependencies, or mutual agreement with the reporter.

## Severity Guidelines

We prioritize issues based on impact to user safety, data exposure, persistence boundaries, release integrity, and the reliability of documented NAILS OS behavior.

| Severity | Typical impact |
| --- | --- |
| Critical | Release artifact compromise, installer compromise, or direct exposure of protected data/workflows |
| High | Significant local compromise, persistence boundary failure, routing bypass in documented Tor mode, or privilege escalation |
| Medium | Limited information disclosure, denial of service, or issues requiring narrow conditions |
| Low | Defense-in-depth gaps, low-impact leaks, or issues with practical mitigations |

Examples of potentially high-priority reports include:

- persistence or cleanup behavior that contradicts the documented model
- bypasses of Tor-routing guarantees in the documented Tor mode configuration
- installer or boot-path flaws that materially weaken expected security boundaries
- release artifact integrity or publication pipeline problems

## Security Advisories and Fix Publication

When we publish a security fix, we communicate it through the repository's public release channels, which can include:

- GitHub Security Advisories
- GitHub Releases
- `CHANGELOG.md`

Publication format and timing depend on severity, remediation, and disclosure coordination. During the current alpha phase, some fixes may appear first in GitHub prerelease notes before a formal advisory is published.

## Non-sensitive Security Questions

For non-sensitive questions about hardening, threat model, or secure use:

- review the existing documentation first
- use the repository's public issue tracker for concrete documentation or product gaps
- use `security@nails.run` only when the discussion itself would be sensitive

## Related Security Notes

- BIOS / legacy boot limitations: [`docs/BIOS-SECURITY.md`](docs/BIOS-SECURITY.md)
- Current SBOM and dependency workflow documentation: [`docs/security/index.md`](docs/security/index.md)

## Policy Updates

This policy is maintained with the repository. Material updates will be reflected in this file.

**Last updated:** 2026-04-20
