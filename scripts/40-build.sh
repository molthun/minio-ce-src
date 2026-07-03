#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
GO="$GOROOT/bin/go"

say "build minio"
cd "$SRC/minio"
LDFLAGS="$("$GO" run buildscripts/gen-ldflags.go 2>/dev/null || echo '-s -w')"
"$GO" build -tags kqueue -trimpath --ldflags "$LDFLAGS" -o "$DIST/minio-linux-amd64" .

say "build mc"
cd "$SRC/mc"
LDFLAGS="$("$GO" run buildscripts/gen-ldflags.go 2>/dev/null || echo '-s -w')"
"$GO" build -trimpath --ldflags "$LDFLAGS" -o "$DIST/mc-linux-amd64" .

say "build console (embeds patched web-app/build)"
cd "$SRC/opens3-console"
"$GO" build -trimpath --tags=kqueue --ldflags "-s -w" -o "$DIST/console-linux-amd64" ./cmd/console

chmod +x "$DIST"/*-linux-amd64
( cd "$DIST" && for f in *-linux-amd64; do sha256sum "$f"; done )
"$DIST/minio-linux-amd64" --version | head -1
say "binaries in dist/"
