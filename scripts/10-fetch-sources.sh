#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

clone_at() {
  name="$1"; repo="$2"; commit="$3"; dir="$SRC/$name"
  if [ -d "$dir/.git" ]; then
    say "$name: fetching"
    git -C "$dir" fetch --all --tags --quiet
  else
    say "$name: cloning $repo"
    git clone --quiet "$repo" "$dir"
  fi
  git -C "$dir" checkout --quiet "$commit"
  git -C "$dir" reset --hard --quiet "$commit"
  git -C "$dir" clean -fdx --quiet
  printf '  %s @ %s\n' "$name" "$(git -C "$dir" rev-parse --short HEAD)"
}

clone_at minio          "$MINIO_REPO"   "$MINIO_COMMIT"
clone_at mc             "$MC_REPO"      "$MC_COMMIT"
clone_at opens3-console "$CONSOLE_REPO" "$CONSOLE_COMMIT"
say "sources ready under work/src/"
