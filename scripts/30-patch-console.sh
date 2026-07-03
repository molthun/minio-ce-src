#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
BUILD="$SRC/opens3-console/web-app/build"
[ -d "$BUILD" ] || die "console build/ not found — run 10-fetch-sources.sh first"
say "applying MinIO branding to console assets"
ROOT="$ROOT" BUILD="$BUILD" bash "$ROOT/console-branding/apply-branding.sh"
say "console branding applied"
