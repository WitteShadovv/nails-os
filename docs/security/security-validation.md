# Security Validation

Operational commands for validating dependency and vulnerability posture.

Related docs:

- [Security hub](index.md)
- [Dependency hygiene](dependency-hygiene.md)
- [Vulnerability handling](vulnerability-handling.md)

## Preconditions

- Nix with flakes enabled
- Repository checkout at target commit
- Write access to `dist/` for security artifacts

## Canonical command flow

Use project-provided interfaces and canonical output filenames:

```bash
# Build release SBOM artifact
nix build ./nix-config#sbom

# Run Nix-aware vulnerability scan
nix run ./nix-config#vulnix-scan -- <target> <output>

# Example
TARGET=$(nix path-info ./nix-config#nixosConfigurations.nails-os-iso.config.system.build.toplevel)
nix run ./nix-config#vulnix-scan -- "$TARGET" dist/vulnix-results.json
```

Canonical outputs:

- `dist/nails-os-sbom.cdx.json`
- `dist/vulnix-results.json`

## 1) Validate lockfile and evaluation

```bash
nix flake lock --no-update-lock-file ./nix-config
nix eval ./nix-config#nixosConfigurations.nails-os.config.system.build.toplevel.drvPath
```

## 2) Build ISO derivation

```bash
nix build ./nix-config#nails-os-iso
```

## 3) Generate SBOM (CycloneDX)

Use the canonical project interface:

```bash
nix build ./nix-config#sbom
```

Expected artifact: `dist/nails-os-sbom.cdx.json`

## 4) Run vulnerability scans

### vulnix (Nix-aware)

```bash
nix run ./nix-config#vulnix-scan -- <target> <output>

# Example
TARGET=$(nix path-info ./nix-config#nixosConfigurations.nails-os-iso.config.system.build.toplevel)
nix run ./nix-config#vulnix-scan -- "$TARGET" dist/vulnix-results.json
```

Expected artifact: `dist/vulnix-results.json`

### Optional: grype against SBOM

```bash
grype sbom:dist/nails-os-sbom.cdx.json
```

> `grype` is optional and not part of the canonical project flow. Use it as an additional external check when available.

## 5) Release artifact verification (consumer side)

```bash
sha256sum -c checksums.txt
gh attestation verify checksums.txt --repo WitteShadovv/nails-os
```

## Security Validation Checklist

- [ ] `flake.lock` consistent and intentional
- [ ] Nix evaluation succeeds
- [ ] ISO build succeeds
- [ ] SBOM generated for release candidate
- [ ] vulnix scan reviewed
- [ ] grype scan reviewed (where available)
- [ ] Any accepted risk is documented with rationale and follow-up date

## CI Recommendations

- Run validation on every PR touching `nix-config/**`, workflows, or security docs.
- Block merge on unresolved Critical findings unless explicit documented exception is approved.
- Keep scan outputs as CI artifacts for auditability.
