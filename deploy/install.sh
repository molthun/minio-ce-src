#!/usr/bin/env bash
# ============================================================
#  MinIO CE + full web console — installer for a single-node Linux VM
#  Run on the TARGET VM as root:  sudo ./install.sh
# ============================================================
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${DATA_DIR:-/mnt/minio/data}"
BIN_DIR="/usr/local/bin"
CFG_DIR="/etc/minio"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root (sudo ./install.sh)."

for f in bin/minio bin/mc bin/minio-console \
         systemd/minio.service systemd/minio-console.service \
         env/minio.env.example env/minio-console.env.example; do
  [ -f "$HERE/$f" ] || die "Missing packaged file: $f"
done

gen_secret() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 32
  else head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi
}

# --- 1. system user ---
if ! getent group minio >/dev/null; then groupadd --system minio; log "created group minio"; fi
if ! getent passwd minio >/dev/null; then
  useradd --system --gid minio --home-dir /var/lib/minio \
          --shell /usr/sbin/nologin --comment "MinIO service" minio
  log "created user minio"
fi

# --- 2. binaries ---
install -m 0755 "$HERE/bin/minio"         "$BIN_DIR/minio"
install -m 0755 "$HERE/bin/mc"            "$BIN_DIR/mc"
install -m 0755 "$HERE/bin/minio-console" "$BIN_DIR/minio-console"
log "installed binaries into $BIN_DIR"

# --- 3. data dir ---
if [ ! -d "$DATA_DIR" ]; then
  warn "$DATA_DIR does not exist yet."
  warn "Mount the presented Proxmox datastore disk there, then re-run, OR"
  warn "press ENTER to create it on the root filesystem (NOT recommended for prod)."
  read -r _
  mkdir -p "$DATA_DIR"
fi
if ! mountpoint -q "$DATA_DIR"; then
  warn "$DATA_DIR is NOT a separate mount point — data will live on the root disk."
fi
chown -R minio:minio "$DATA_DIR"
chmod 0750 "$DATA_DIR"
log "data dir ready: $DATA_DIR"

# --- 4. config + secrets ---
mkdir -p "$CFG_DIR"
chown root:minio "$CFG_DIR"
chmod 0750 "$CFG_DIR"

if [ ! -f "$CFG_DIR/minio.env" ]; then
  # gen_secret emits only [0-9a-f], so it is safe inside a sed replacement.
  ROOT_USER="admin-$(gen_secret | cut -c1-8)"
  ROOT_PASS="$(gen_secret)"
  # Replace values by key name (anchored) — robust regardless of placeholder text.
  sed -e "s|^MINIO_ROOT_USER=.*|MINIO_ROOT_USER=$ROOT_USER|" \
      -e "s|^MINIO_ROOT_PASSWORD=.*|MINIO_ROOT_PASSWORD=$ROOT_PASS|" \
      -e "s|^MINIO_VOLUMES=.*|MINIO_VOLUMES=$DATA_DIR|" \
      "$HERE/env/minio.env.example" > "$CFG_DIR/minio.env"
  chown root:minio "$CFG_DIR/minio.env"; chmod 0640 "$CFG_DIR/minio.env"
  GENERATED_CREDS=1
  log "generated $CFG_DIR/minio.env with fresh root credentials"
else
  warn "$CFG_DIR/minio.env already exists — left untouched."
fi

if [ ! -f "$CFG_DIR/minio-console.env" ]; then
  # Passphrase and salt MUST be independent values.
  PBKDF_PASS="$(gen_secret)"
  PBKDF_SALT="$(gen_secret)"
  sed -e "s|^CONSOLE_PBKDF_PASSPHRASE=.*|CONSOLE_PBKDF_PASSPHRASE=$PBKDF_PASS|" \
      -e "s|^CONSOLE_PBKDF_SALT=.*|CONSOLE_PBKDF_SALT=$PBKDF_SALT|" \
      "$HERE/env/minio-console.env.example" > "$CFG_DIR/minio-console.env"
  chown root:minio "$CFG_DIR/minio-console.env"; chmod 0640 "$CFG_DIR/minio-console.env"
  log "generated $CFG_DIR/minio-console.env with fresh cookie secrets"
else
  warn "$CFG_DIR/minio-console.env already exists — left untouched."
fi

# --- 5. systemd units ---
install -m 0644 "$HERE/systemd/minio.service"         /etc/systemd/system/minio.service
install -m 0644 "$HERE/systemd/minio-console.service" /etc/systemd/system/minio-console.service
systemctl daemon-reload
systemctl enable --now minio.service
sleep 2
systemctl enable --now minio-console.service
sleep 2
log "systemd services enabled and started"

# --- 6. report ---
IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')"
[ -n "${IP:-}" ] || IP="<VM-IP>"

echo
echo "=================================================================="
systemctl --no-pager --lines=0 status minio.service minio-console.service || true
echo "=================================================================="
echo "  S3 API endpoint  :  http://$IP:9000"
echo "  Web admin console:  http://$IP:9090"
if [ "${GENERATED_CREDS:-0}" = "1" ]; then
  echo "  ----------------------------------------------------------------"
  echo "  ROOT CREDENTIALS (shown ONCE — store them now):"
  echo "     user     : $(grep '^MINIO_ROOT_USER=' "$CFG_DIR/minio.env" | cut -d= -f2-)"
  echo "     password : $(grep '^MINIO_ROOT_PASSWORD=' "$CFG_DIR/minio.env" | cut -d= -f2-)"
fi
echo "=================================================================="
echo "  Client alias example:"
echo "     mc alias set local http://127.0.0.1:9000 <user> <password>"
echo "     mc admin info local"
echo "=================================================================="
