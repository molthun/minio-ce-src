#!/usr/bin/env bash
# End-to-end: toolchain -> sources -> patch -> build -> scan -> smoke -> package.
set -euo pipefail
D="$(dirname "$0")"
bash "$D/00-bootstrap-toolchain.sh"
bash "$D/10-fetch-sources.sh"
bash "$D/20-patch-minio.sh"
bash "$D/30-patch-console.sh"
bash "$D/40-build.sh"
bash "$D/50-scan.sh"
bash "$D/60-smoke.sh"
bash "$D/70-package.sh"
echo "DONE — deploy artifact under pkg/"
