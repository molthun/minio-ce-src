#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
GO="$GOROOT/bin/go"
command -v govulncheck >/dev/null 2>&1 || "$GO" install golang.org/x/vuln/cmd/govulncheck@latest
OUT="$ROOT/dist/scan"; mkdir -p "$OUT"
for m in minio mc opens3-console; do
  say "govulncheck: $m"
  ( cd "$SRC/$m" && govulncheck ./... ) > "$OUT/$m.txt" 2>&1 || true
  printf '  %s: %s reachable vulnerabilities\n' "$m" "$(grep -c 'Vulnerability #' "$OUT/$m.txt" 2>/dev/null || echo 0)"
done
say "reports in dist/scan/ — review remaining findings against SECURITY.md §6"
