#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
PKG="$ROOT/pkg/minio-ce-deploy"
rm -rf "$ROOT/pkg"; mkdir -p "$PKG/bin"

install -m 0755 "$DIST/minio-linux-amd64"   "$PKG/bin/minio"
install -m 0755 "$DIST/mc-linux-amd64"      "$PKG/bin/mc"
install -m 0755 "$DIST/console-linux-amd64" "$PKG/bin/minio-console"

# deploy scaffolding (systemd units, env templates, installer, docs)
cp -r "$ROOT/deploy/." "$PKG/"

say "generate CHECKSUMS.sha256"
( cd "$PKG" && find . -type f ! -name CHECKSUMS.sha256 -print0 | sort -z \
    | xargs -0 sha256sum > CHECKSUMS.sha256 )

OUT="$ROOT/pkg/minio-ce-deploy.tar.gz"
tar -C "$ROOT/pkg" -czf "$OUT" minio-ce-deploy
sha256sum "$OUT" | tee "$OUT.sha256"
say "deploy artifact: $OUT"
