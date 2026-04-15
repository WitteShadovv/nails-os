# SBOM Generation Script for NAILS OS
# Generates CycloneDX 1.6 JSON format SBOM from a Nix closure target.
{ pkgs, lib }:

pkgs.writeShellApplication {
  name = "generate-nails-sbom";
  runtimeInputs = with pkgs; [ nix jq coreutils gnugrep gawk ];

  text = ''
    set -euo pipefail

    SYSTEM_PATH=""
    OUTPUT_FILE="sbom.cdx.json"
    NIXPKGS_REV="unknown"
    PATHS_FILE=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --system-path)
          SYSTEM_PATH="$2"
          shift 2
          ;;
        --paths-file)
          PATHS_FILE="$2"
          shift 2
          ;;
        --output)
          OUTPUT_FILE="$2"
          shift 2
          ;;
        --nixpkgs-rev)
          NIXPKGS_REV="$2"
          shift 2
          ;;
        -h|--help)
          echo "Usage: generate-nails-sbom --system-path <store-path> [--paths-file <file>] [--output <file>] [--nixpkgs-rev <rev>]"
          echo
          echo "Generates a CycloneDX 1.6 JSON SBOM for the runtime closure of SYSTEM-PATH."
          exit 0
          ;;
        *)
          echo "Unknown argument: $1" >&2
          exit 2
          ;;
      esac
    done

    if [[ -z "$SYSTEM_PATH" ]]; then
      echo "--system-path is required" >&2
      exit 2
    fi

    echo "Generating SBOM for system: $SYSTEM_PATH" >&2
    echo "Collecting runtime dependencies..." >&2

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT

    if [[ -n "$PATHS_FILE" ]]; then
      deps_file="$tmpdir/runtime-deps.txt"
      sort -u "$PATHS_FILE" > "$deps_file"
    else
      deps_file="$tmpdir/runtime-deps.txt"
      nix-store -qR "$SYSTEM_PATH" | sort -u > "$deps_file"
    fi

    TOTAL_PKGS=$(wc -l < "$deps_file")
    echo "Found $TOTAL_PKGS packages in system closure" >&2

    components_file="$tmpdir/components.json"

    while IFS= read -r store_path; do
      if [[ ! "$store_path" =~ ^/nix/store/ ]]; then
        continue
      fi

      base_name=$(basename "$store_path")
      name_version=''${base_name:33}

      if [[ "$name_version" =~ ^(.+)-([0-9][0-9a-zA-Z._-]*)$ ]]; then
        pkg_name="''${BASH_REMATCH[1]}"
        pkg_version="''${BASH_REMATCH[2]}"
      else
        pkg_name="$name_version"
        pkg_version="unknown"
      fi

      jq -n \
        --arg type "library" \
        --arg bom_ref "$store_path" \
        --arg name "$pkg_name" \
        --arg version "$pkg_version" \
        --arg purl "pkg:nix/$pkg_name@$pkg_version" \
        '{
          "type": $type,
          "bom-ref": $bom_ref,
          "name": $name,
          "version": $version,
          "purl": $purl
        }'
    done < "$deps_file" | jq -s '.' > "$components_file"

    BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    jq -n \
      --slurpfile components "$components_file" \
      --arg nixpkgs_rev "$NIXPKGS_REV" \
      --arg timestamp "$BUILD_TIMESTAMP" \
      --arg system_path "$SYSTEM_PATH" \
      '{
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "serialNumber": ("urn:uuid:" + (now | tostring | @base64)),
        "version": 1,
        "metadata": {
          "timestamp": $timestamp,
          "tools": [
            {
              "vendor": "NAILS OS",
              "name": "generate-nails-sbom",
              "version": "1.0.0"
            }
          ],
          "component": {
            "type": "operating-system",
            "bom-ref": $system_path,
            "name": "NAILS OS",
            "version": "rolling",
            "description": "Privacy-focused NixOS-based live operating system",
            "properties": [
              {
                "name": "nixpkgs:revision",
                "value": $nixpkgs_rev
              }
            ]
          }
        },
        "components": ($components[0] // [])
      }' > "$OUTPUT_FILE"

    echo "SBOM generated successfully: $OUTPUT_FILE" >&2
    echo "Total components: $(jq 'length' "$components_file")" >&2
  '';

  meta = with lib; {
    description = "Generate CycloneDX SBOM for NAILS OS system closure";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
