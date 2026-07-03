#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"
T="$WORK/smoke"; J="$T/cookies.txt"; C="http://127.0.0.1:19090"
rm -rf "$T"; mkdir -p "$T/data"
pass=0; fail=0
ok(){ echo "  [OK]   $1"; pass=$((pass+1)); }
bad(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

MINIO_ROOT_USER=minioadmin MINIO_ROOT_PASSWORD=minioadmin123 \
  "$DIST/minio-linux-amd64" server "$T/data" --address 127.0.0.1:19000 \
  --console-address 127.0.0.1:19001 >"$T/minio.log" 2>&1 &
mp=$!; cp=""
cleanup(){ [ -n "$cp" ] && kill "$cp" 2>/dev/null; kill "$mp" 2>/dev/null; wait 2>/dev/null; }
trap cleanup EXIT
for _ in $(seq 1 40); do curl -fsS http://127.0.0.1:19000/minio/health/live >/dev/null 2>&1 && break; sleep 0.5; done

CONSOLE_MINIO_SERVER=http://127.0.0.1:19000 CONSOLE_PBKDF_PASSPHRASE=p CONSOLE_PBKDF_SALT=s \
  "$DIST/console-linux-amd64" server --host 127.0.0.1 --port 19090 >"$T/console.log" 2>&1 &
cp=$!
for _ in $(seq 1 40); do [ "$(curl -s -o /dev/null -w '%{http_code}' "$C/")" = "200" ] && break; sleep 0.5; done
[ "$(curl -s -o /dev/null -w '%{http_code}' "$C/")" = "200" ] && ok "console web UI" || bad "console web UI"

curl -s -c "$J" -H 'Content-Type: application/json' \
  -d '{"accessKey":"minioadmin","secretKey":"minioadmin123"}' "$C/api/v1/login" >/dev/null
curl -s -b "$J" "$C/api/v1/session" | grep -q '"status"' && ok "login + session" || bad "login"
curl -s -b "$J" -H 'Content-Type: application/json' \
  -d '{"name":"smoke","versioning":{"enabled":false},"locking":false}' "$C/api/v1/buckets" >/dev/null
sleep 1
curl -s -b "$J" "$C/api/v1/buckets" | grep -q 'smoke' && ok "bucket create/list" || bad "bucket"
curl -s -b "$J" -H 'Content-Type: application/json' \
  -d '{"accessKey":"u1","secretKey":"secret123456","groups":[],"policies":[]}' "$C/api/v1/users" >/dev/null
curl -s -b "$J" "$C/api/v1/users" | grep -q 'u1' && ok "IAM user create/list" || bad "IAM"
curl -s -b "$J" "$C/api/v1/policies" | grep -q 'readwrite' && ok "policies" || bad "policies"
curl -s -b "$J" "$C/api/v1/admin/info" | grep -qE '"servers"|"buckets"|"mode"' && ok "admin info" || bad "admin info"

echo "==== smoke: pass=$pass fail=$fail ===="
exit "$fail"
