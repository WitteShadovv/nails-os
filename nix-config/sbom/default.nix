{ pkgs, target, nixpkgsRev ? "unknown" }:

let
  generator = pkgs.callPackage ./generate-sbom.nix { };
  closure = pkgs.closureInfo { rootPaths = [ target ]; };
in pkgs.runCommand "nails-os-sbom" {
  nativeBuildInputs = [ generator pkgs.jq ];
  passthru = {
    format = "CycloneDX-1.6-JSON";
    inheritsTarget = target;
  };
} ''
  mkdir -p "$out"

  generate-nails-sbom \
    --system-path "${target}" \
    --paths-file "${closure}/store-paths" \
    --output "$out/sbom.cdx.json" \
    --nixpkgs-rev "${nixpkgsRev}"

  # Basic schema-level smoke check.
  jq -e '.bomFormat == "CycloneDX" and .specVersion == "1.6"' "$out/sbom.cdx.json" > /dev/null
''
