# CI / Release Operations

Maintainer-facing operational reference for NAILS OS CI, release publishing, and hosted build infrastructure.

For the public project overview, see [`../README.md`](../README.md).

## Workflow overview

| Workflow | Purpose |
|---|---|
| `.github/workflows/build-iso-pr.yml` | PR wrapper for the Hetzner ISO lane: always runs on PRs to `main`, performs metadata-only relevance detection, uses the native `hetzner-pr` environment approval gate for relevant PRs, and exposes the stable top-level required check `Hetzner ISO PR Result` |
| `.github/workflows/build-iso.yml` | Trusted Hetzner ISO lane used by `main`, manual/release invocations, and the approved PR wrapper; builds the ISO, runs reproducibility checks, uploads publication artifacts, publishes rolling `latest-*` pre-releases from `main`, and emits the stable final check `Hetzner ISO Result` |
| `.github/workflows/release.yml` | Build a stable release from a `v*` tag or manual dispatch and create the GitHub Release |
| `.github/workflows/hetzner-cleanup.yml` | Daily failsafe cleanup for orphaned Hetzner servers |
| `.github/workflows/security-scan.yml` | Weekly vulnerability scan |
| `.github/workflows/repo-cleanliness.yml` | Guard against tracked repository junk |

## Publication model

### Rolling builds from `main`

- Triggered by pushes to `main`
- Built by `build-iso.yml`
- Published as GitHub pre-releases tagged `latest-<commit>`
- ISO is hosted on Cloudflare R2; the GitHub release carries metadata assets and links

### Pull requests to `main`

- The top-level PR workflow is `build-iso-pr.yml`, triggered by `pull_request_target` for every PR to `main`
- It first runs a metadata-only relevance job that inspects the PR file list through the GitHub API; no repository checkout happens in that step
- Every PR therefore gets the same stable top-level check: `Hetzner ISO PR Result`
- Irrelevant PRs pass that result check quickly without approval or Hetzner provisioning
- Relevant PRs stop at a metadata-only approval job bound to the GitHub Actions environment `hetzner-pr`
- That approval job does **not** check out or execute PR code
- After approval, the trusted reusable workflow fetches the current PR head repository/ref/SHA from the GitHub API and passes that exact target into the Hetzner-backed jobs
- Hetzner-backed jobs check out the exact approved SHA with `persist-credentials: false` and verify `HEAD` before executing PR code

### Stable releases

- Triggered by `v*` tag pushes or manual dispatch in `release.yml`
- `release.yml` calls `build-iso.yml` with `r2_prefix: stable`
- Stable publication requires a successful R2 upload and a configured `R2_PUBLIC_URL`
- The GitHub release attaches `checksums.txt`, `build-metadata.json`, and security-reference assets; the ISO itself is linked from R2

### Public attestation

For public repositories, stable releases publish GitHub build provenance attestation for `checksums.txt`. The attestation does **not** directly attest the ISO binary in the release runner; instead it attests the checksum file that contains the ISO checksum.

## Required repository secrets

Configure these in **Settings → Secrets and variables → Actions → Secrets**.

| Secret | Required for | Notes |
|---|---|---|
| `PERSONAL_ACCESS_TOKEN` | Hetzner self-hosted runner registration | Fine-grained PAT with the repository access needed by the workflow |
| `HCLOUD_TOKEN` | Hetzner provisioning and cleanup | Read/write Hetzner Cloud API token |
| `HCLOUD_SSH_KEY_ID` | Hetzner runner provisioning | Preferred/canonical location. Must be the **numeric Hetzner SSH key ID**, not the key name |
| `R2_ENDPOINT` | R2 publication | Required for stable ISO upload |
| `R2_ACCESS_KEY_ID` | R2 publication | Required for stable ISO upload |
| `R2_SECRET_ACCESS_KEY` | R2 publication | Required for stable ISO upload |

## Required repository variables

Configure these in **Settings → Secrets and variables → Actions → Variables**.

| Variable | Required for | Notes |
|---|---|---|
| `HCLOUD_SSH_KEY_ID` | Hetzner runner provisioning | Backward-compatible fallback only. If both secret and variable are set, CI prefers the secret. Must be the **numeric Hetzner SSH key ID**, not the key name |
| `R2_BUCKET_NAME` | R2 upload steps | Bucket used for `latest/` and `stable/` publication paths |
| `R2_PUBLIC_URL` | Release notes and download links | Public base URL used in GitHub release notes |
| `HETZNER_CUMULATIVE_COST_EUR` | Monthly cost tracking | Auto-managed by CI; stores month and cumulative total |

For Hetzner runner provisioning, configure `HCLOUD_SSH_KEY_ID` as an Actions **secret** whenever possible. Existing variable-based setups remain supported as a fallback for backward compatibility.

## Required GitHub environment for PR Hetzner builds

Create a repository environment named **`hetzner-pr`** in **Settings → Environments** and configure it with:

- **Required reviewers**: the maintainers allowed to approve privileged Hetzner-backed PR builds
- Optional deployment branch restrictions if you want approvals limited to the default-branch workflow context

The `hetzner-pr` environment is approval-only for PR runs. It does not need environment secrets; the workflow continues to use explicitly mapped repository secrets after approval.

If you use required status checks for `main`, require the stable PR wrapper check **`Hetzner ISO PR Result`** rather than any internal job from the reusable workflow.

## Cost controls and cleanup

The build workflow includes several safeguards to limit accidental spend:

- **Budget gate:** before provisioning a runner, CI estimates current monthly Hetzner cost and aborts if the estimate exceeds **€20 gross**.
- **Ephemeral runners:** build infrastructure is created for the workflow run and then destroyed.
- **Unconditional teardown:** the runner-deletion path executes even when earlier jobs fail.
- **Daily failsafe cleanup:** `hetzner-cleanup.yml` removes any leftover servers and opens a GitHub issue if it had to act.

## Release outputs

Expected public release outputs include:

- R2-hosted ISO
- `checksums.txt`
- `build-metadata.json`
- `security-artifacts.txt` with security artifact references
- optional downloadable SBOM / vulnerability artifacts when publication is configured; when uploaded to R2 they are published under `stable/security/` for stable releases and `latest/security/` for rolling builds

## Repository cleanliness guard

`repo-cleanliness.yml` runs:

```bash
python3 .github/scripts/check_tracked_cleanliness.py
```

It fails the workflow if forbidden junk is **tracked by git** (for example `dist/`, editor state, cache directories, or `result*`). It does **not** fail on ignored local files.

## Operational notes

- `build-iso-pr.yml` intentionally does **not** use a workflow-level `paths:` filter; PR relevance is decided inside the workflow so the stable required check is always present.
- Stable releases depend on successful R2 upload outputs from `build-iso.yml`.
- Rolling `latest-*` releases are pre-releases, not stable support targets.
- The repository's public security policy remains in [`../SECURITY.md`](../SECURITY.md); deeper security operations documentation lives under [`security/`](security/).
