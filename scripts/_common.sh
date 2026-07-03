#!/usr/bin/env bash
# Common environment, sourced by every stage script.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/versions.env"

WORK="$ROOT/work"
SRC="$WORK/src"
DIST="$ROOT/dist"
export GOROOT="$WORK/go"
export GOPATH="$WORK/gopath"
export GOCACHE="$WORK/cache/go-build"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
export CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOFLAGS=-mod=mod

mkdir -p "$WORK" "$SRC" "$DIST" "$GOPATH" "$GOCACHE"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }
