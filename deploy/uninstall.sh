#!/usr/bin/env bash
# Removes the MinIO services and binaries. Keeps data and config by default.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }

systemctl disable --now minio-console.service 2>/dev/null || true
systemctl disable --now minio.service 2>/dev/null || true
rm -f /etc/systemd/system/minio-console.service /etc/systemd/system/minio.service
systemctl daemon-reload
rm -f /usr/local/bin/minio /usr/local/bin/mc /usr/local/bin/minio-console

echo "Services and binaries removed."
echo "Kept: /etc/minio (config+secrets) and the data dir."
echo "To purge them too:  rm -rf /etc/minio  &&  userdel minio  &&  rm -rf <DATA_DIR>"
