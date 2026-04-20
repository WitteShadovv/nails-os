# Support

This document explains where to ask for help and how to route reports for NAILS OS.

## Choose the Right Path

| Need | Use | Notes |
|---|---|---|
| Security vulnerability | [`SECURITY.md`](SECURITY.md) | **Do not** open a public issue. Use private reporting. |
| Bug or regression | [Open a bug report](https://github.com/WitteShadovv/nails-os/issues/new?template=bug_report.md) | Include reproduction steps, ISO version/date, boot mode, and logs if available. |
| Feature request | [Open a feature request](https://github.com/WitteShadovv/nails-os/issues/new?template=feature_request.md) | Explain the use case and any security/privacy tradeoffs. |
| Contributing help | [`CONTRIBUTING.md`](CONTRIBUTING.md) and [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | Use these for setup, build, test, and PR workflow guidance. |
| Question about current repository behavior or docs | [Open an issue](https://github.com/WitteShadovv/nails-os/issues/new/choose) | Be specific about what you expected, what you saw, and which release or docs page you used. |

If you are unsure which public route applies, start with the [issue chooser](https://github.com/WitteShadovv/nails-os/issues/new/choose) for non-security topics and use [`SECURITY.md`](SECURITY.md) for private vulnerability disclosure.

## Before Opening an Issue

- Check whether the issue or request already exists.
- Re-test on a current build or with the latest documented workflow if practical.
- Gather the exact command, error, log output, or screenshot that demonstrates the problem.
- Include environment details that matter for this project, such as boot mode (UEFI/BIOS) and network mode (Tor/Direct).

## Security vs. General Support

- Use [`SECURITY.md`](SECURITY.md) **only** for vulnerability disclosure and sensitive security reports.
- Do **not** use the security contact for general troubleshooting, feature requests, or usage questions.
- Do **not** post exploit details or unpatched vulnerability reports in public issues.

## Support Expectations

NAILS OS is currently an **alpha-stage** project and support is best-effort. Clear, reproducible reports are much easier to act on than broad or speculative ones.
