# Support

NAILS OS is maintained through this repository. Use GitHub issues for actionable bug reports, focused feature proposals, and documentation improvements. The fastest way to get useful help is to provide a concise, reproducible report that stays within the project's documented scope.

## Where to Get Help

| Need | Best channel |
| --- | --- |
| Reproducible bug in NAILS OS | [GitHub Issues](https://github.com/WitteShadovv/nails-os/issues) using the bug report template |
| Feature request or documentation improvement | [GitHub Issues](https://github.com/WitteShadovv/nails-os/issues) using the appropriate template |
| Security vulnerability | `security@nails.run` or GitHub private advisory — see [SECURITY.md](SECURITY.md) |
| Contributor workflow or repository setup question | [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) |
| Question about current repository behavior or docs | Review the README and existing issues first; if you find a concrete product or documentation gap, open an issue with specifics |

If your issue is actually about the separate **NAILS** hidden-environment CLI rather than this installable operating system, report it in the sibling `nails` repository instead.

## Before You Open an Issue

Please:

1. Search existing issues for duplicates.
2. Confirm that the behavior is in scope for this repository.
3. Check the latest published prerelease, or note the exact commit if you are testing unreleased code.
4. Gather useful diagnostics such as:
   - ISO version or release tag
   - boot mode (`UEFI` or `BIOS`)
   - network mode (`Tor` or `Direct`)
   - relevant logs, screenshots, or installer output
   - hardware or virtualization details needed to reproduce the problem

When reporting problems, avoid posting passwords, recovery material, private keys, or other sensitive operational data.

## Security Reports

Do **not** report suspected vulnerabilities in public issues or discussions.

Use the private reporting path in [SECURITY.md](SECURITY.md). If you are unsure whether an issue is security-sensitive, err on the side of private reporting.

## Support Scope

- Reports are triaged based on reproducibility, user impact, and the information provided.
- We may ask for clarification or sanitized diagnostics before triage is complete.
- The latest published prerelease line is the primary target for fixes and documentation updates during the current alpha phase.
- We do not provide private consulting or troubleshooting for custom deployments, forks, unsupported environments, or third-party integrations.

NAILS OS is currently **alpha** software and support is best-effort. Clear, reproducible reports are the fastest way to get useful help.
