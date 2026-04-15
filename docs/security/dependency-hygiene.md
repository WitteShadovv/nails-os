# Dependency Hygiene

How NAILS OS manages dependency risk with Nix flakes.

## Principles

- `flake.lock` is the source of truth for pinned dependencies.
- Updates must be intentional, reviewed, and validated.
- Critical security updates bypass normal cadence via emergency process.

Related docs:

- [Security hub](index.md)
- [Vulnerability handling](vulnerability-handling.md)
- [Security validation commands](security-validation.md)

## Canonical Artifacts

| Artifact | Purpose |
|---|---|
| `nix-config/flake.nix` | Declares dependency inputs |
| `nix-config/flake.lock` | Concrete pinned revisions (canonical) |
| Release SBOM artifact | Dependency inventory for a built release |

## Update Cadence

| Update type | Cadence | Trigger | Approval |
|---|---|---|---|
| Routine dependency refresh | Weekly | Scheduled maintainer pass | Required |
| Deep refresh / branch uplift | Quarterly | NixOS release cycle or planned hardening | Required |
| Emergency security update | Immediate | Critical/High CVE with relevant exposure | Required (expedited) |

## Standard Update Workflow (Routine)

1. Update lock file:

```bash
nix flake update ./nix-config
```

2. Validate configuration and build path:

```bash
nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath
nix build ./nix-config#nails-os-iso
```

3. Run security validation commands from [security-validation.md](security-validation.md).

4. Open PR with:

- lockfile diff summary
- scan results summary
- risk note for any accepted/known findings

## Emergency Update Path

Use this path when a relevant Critical/High vulnerability is confirmed.

1. Update only required input(s) when possible.
2. Rebuild + re-scan.
3. Release patched ISO.
4. Publish advisory/update notice.

See full workflow and SLA in [vulnerability-handling.md](vulnerability-handling.md).

## Maintainer Checklist

- [ ] `flake.lock` changed intentionally
- [ ] Build/evaluation passed
- [ ] SBOM regenerated or available for target release
- [ ] Vulnerability scans reviewed
- [ ] Any exceptions documented with justification and expiry
- [ ] Public policy alignment checked against [`../../SECURITY.md`](../../SECURITY.md)

## Ownership Recommendation

- Primary owner: release maintainer
- Backup owner: security maintainer
- Review SLA: within 48h for routine lockfile updates
