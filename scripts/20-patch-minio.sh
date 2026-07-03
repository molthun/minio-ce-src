#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
cd "$SRC/minio" || die "run 10-fetch-sources.sh first"

say "backup pristine go.mod/go.sum"
cp -f go.mod "$ROOT/patches/minio/go.mod.pristine"
cp -f go.sum "$ROOT/patches/minio/go.sum.pristine"

say "security dependency bumps"
go get "golang.org/x/crypto@${BUMP_X_CRYPTO}"
go get "golang.org/x/net@${BUMP_X_NET}"
go get "github.com/go-jose/go-jose/v4@${BUMP_GO_JOSE}"
go get "go.opentelemetry.io/otel/sdk@${BUMP_OTEL_SDK}"
go get "github.com/eclipse/paho.mqtt.golang@${BUMP_PAHO_MQTT}"
go mod tidy

say "local CVE code patches"
shopt -s nullglob
applied=0
for p in "$ROOT"/patches/minio/CVE-*.patch; do
  say "  apply $(basename "$p")"
  git apply --3way "$p" || die "patch failed: $p (see patches/minio/CVE-PATCHES.md)"
  applied=$((applied+1))
done
[ "$applied" -eq 0 ] && say "  (no CVE-*.patch files yet — see patches/minio/CVE-PATCHES.md)"

say "go.mod diff:"
diff "$ROOT/patches/minio/go.mod.pristine" go.mod || true
say "minio patched: deps bumped, $applied code patch(es) applied"
