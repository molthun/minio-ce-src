#!/usr/bin/env bash
# Apply MinIO branding to a prebuilt opens3/console web-app/build directory.
# Requires: BUILD (path to web-app/build), ROOT (repo root). Idempotent.
set -euo pipefail
: "${BUILD:?set BUILD to the console web-app/build dir}"
: "${ROOT:?set ROOT to the repo root}"
BR="$ROOT/console-branding"
HTML="$BUILD/index.html"

cp -f "$BR/minio-logo-white.svg" "$BUILD/minio-logo-white.svg"
cp -f "$BR/minio-favicon.svg"    "$BUILD/minio-favicon.svg"
cp -f "$BR/logo-swap.js"         "$BUILD/logo-swap.js"

# title + textual brand strings
perl -0777 -i -pe 's/OpenS3 Console/MinIO Console/g; s/OpenS3/MinIO/g' "$HTML"
[ -f "$BUILD/manifest.json" ] && perl -0777 -i -pe 's/OpenS3 Console/MinIO Console/g; s/OpenS3/MinIO/g' "$BUILD/manifest.json"

# inject the runtime logo swapper (once)
grep -q 'logo-swap.js' "$HTML" || \
  perl -0777 -i -pe 's/<\/body>/<script src="\/logo-swap.js"><\/script><\/body>/' "$HTML"

# inject SVG favicon (once) — modern browsers prefer it over favicon.ico
grep -q 'minio-favicon.svg' "$HTML" || \
  perl -0777 -i -pe 's/<\/head>/<link rel="icon" type="image\/svg+xml" href="\/minio-favicon.svg"\/><\/head>/' "$HTML"

echo "branding applied:"
echo "  logo-swap.js referenced: $(grep -c 'logo-swap.js' "$HTML")"
echo "  favicon referenced:      $(grep -c 'minio-favicon.svg' "$HTML")"
echo "  OpenS3 left in html:     $(grep -c 'OpenS3' "$HTML" || true)"
