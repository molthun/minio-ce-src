#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
if [ -x "$GOROOT/bin/go" ] && "$GOROOT/bin/go" version 2>/dev/null | grep -q "go$GO_VERSION "; then
  say "Go $GO_VERSION already present"; exit 0
fi
say "downloading Go $GO_VERSION"
url="https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
tmp="$WORK/go-${GO_VERSION}.tar.gz"
curl -fL "$url" -o "$tmp"
rm -rf "$GOROOT"
tar -C "$WORK" -xzf "$tmp"      # extracts to $WORK/go
rm -f "$tmp"
"$GOROOT/bin/go" version
