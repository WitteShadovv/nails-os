# Contributing

Contributor workflow for NAILS OS.

For general project overview, see [`../README.md`](../README.md).

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
- Alternate: `security@[project-domain]` (placeholder)

## Submitting Security Fixes

When your PR addresses a CVE/GHSA/security defect:

1. Reference the issue identifier in the PR title/body.
2. Include before/after scan evidence.
3. Update `nix-config/flake.lock` if dependency remediation is required.
4. Run validation commands from [`security/security-validation.md`](security/security-validation.md).

Minimum PR checklist:

- [ ] Evaluation/build succeeds
- [ ] Relevant vulnerability scans included
- [ ] No unrelated lockfile churn
- [ ] Docs updated when behavior/policy changed

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
