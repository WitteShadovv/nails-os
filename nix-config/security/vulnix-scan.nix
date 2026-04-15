{ pkgs, lib, target, ignoredCvesFile ? null }:

pkgs.writeShellApplication {
  name = "nails-vulnix-scan";
  runtimeInputs = with pkgs; [ nix vulnix jq coreutils ];

  text = ''
        set -euo pipefail

        if [[ "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
          cat <<'EOF'
    Usage: nails-vulnix-scan [--help] [<target-store-path> <output-json-path>]

    Run vulnix on a Nix store path closure and write JSON findings to OUTPUT-JSON-PATH.

    Examples:
      nails-vulnix-scan
      nails-vulnix-scan /nix/store/...-nixos-system-... ./dist/vulnix-results.json
    EOF
          exit 0
        fi

        if [[ $# -gt 2 ]]; then
          echo "Expected at most 2 positional arguments: <target-store-path> <output-json-path>" >&2
          exit 2
        fi

        TARGET="''${1:-${target}}"
        OUTPUT_FILE="''${2:-vulnix-results.json}"
        OUTPUT_DIR="$(dirname "$OUTPUT_FILE")"
        IGNORED_CVES_FILE="${
          if ignoredCvesFile != null then toString ignoredCvesFile else ""
        }"

        mkdir -p "$OUTPUT_DIR"

        echo "Scanning target: $TARGET" >&2

        RAW_FILE="''${OUTPUT_FILE}.raw"

        # vulnix returns non-zero when vulnerabilities are found. We still want
        # the JSON report artifact, so suppress hard-fail here and let policy
        # enforcement happen in CI.
        if ! vulnix --json --closure "$TARGET" > "$RAW_FILE" 2>"''${OUTPUT_FILE}.stderr"; then
          echo "vulnix exited non-zero (vulnerabilities and/or evaluation warnings)." >&2
        fi

        if [[ -n "$IGNORED_CVES_FILE" && -f "$IGNORED_CVES_FILE" ]]; then
          jq -e '
            (.version == 1) and
            (.entries | type == "array") and
            (all(.entries[]?; (.cve | type == "string") and (.expires | type == "string") and (.reason | type == "string")))
          ' "$IGNORED_CVES_FILE" >/dev/null

          now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          jq \
            --arg now "$now" \
            --slurpfile policy "$IGNORED_CVES_FILE" '
              def active_ignores:
                ($policy[0].entries // [])
                | map(select(.expires > $now))
                | map(.cve);

              def is_ignored($id):
                active_ignores | index($id) != null;

              map(
                . as $item |
                ($item.affected_by // []) as $affected |
                ($affected | map(select(is_ignored(.) | not))) as $remaining |
                if ($remaining | length) > 0 then
                  ($item + { affected_by: $remaining })
                else
                  empty
                end
              )
            ' "$RAW_FILE" > "$OUTPUT_FILE"
        else
          cp "$RAW_FILE" "$OUTPUT_FILE"
        fi

        # Ensure output is valid JSON array for downstream policy parsing.
        jq -e 'if type == "array" then true else false end' "$OUTPUT_FILE" >/dev/null

        TOTAL=$(jq 'length' "$OUTPUT_FILE")
        CRITICAL=$(jq '[.[] | select((.cvssv3_basescore // 0) >= 9.0)] | length' "$OUTPUT_FILE")
        HIGH=$(jq '[.[] | select((.cvssv3_basescore // 0) >= 7.0 and (.cvssv3_basescore // 0) < 9.0)] | length' "$OUTPUT_FILE")

        echo "total_findings=$TOTAL"
        echo "critical_findings=$CRITICAL"
        echo "high_findings=$HIGH"
  '';

  meta = with lib; {
    description = "Run vulnix scan and emit JSON findings";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
