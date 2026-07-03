# MinIO CE + full web console — single-node deploy package

Air-gapped, IP:port only. No domains, no TLS, no internet required on the target.

## Contents

```
bin/minio          official upstream MinIO CE server + documented security patches (linux/amd64)
bin/mc             official upstream MinIO client
bin/minio-console  full web console (opens3/console fork)
systemd/*.service  service units
env/*.example      environment templates
install.sh         installer (run as root on the VM)
uninstall.sh       remover
```

## What runs where

| Port | Bind | Purpose | Exposed |
| --- | --- | --- | --- |
| 9000 | `0.0.0.0` | S3 API | yes — `http://<VM-IP>:9000` |
| 9090 | `0.0.0.0` | **Full web admin console** | yes — `http://<VM-IP>:9090` |
| 9001 | `127.0.0.1` | MinIO built-in (stripped) console — hidden | no |

## Prerequisites on the Proxmox VM

- Linux x86-64 (Debian/Ubuntu/RHEL family), systemd.
- The datastore disk presented to the VM, formatted and mounted at the data path
  (default `/mnt/minio/data`). Put it in `/etc/fstab` so it mounts on boot.

Example (adjust device):

```bash
sudo mkfs.xfs /dev/sdb            # or ext4
sudo mkdir -p /mnt/minio/data
echo '/dev/sdb /mnt/minio/data xfs defaults,noatime 0 2' | sudo tee -a /etc/fstab
sudo mount -a
```

## Install

```bash
scp minio-ce-deploy.tar.gz user@<VM-IP>:/tmp/
ssh user@<VM-IP>
cd /tmp && tar xzf minio-ce-deploy.tar.gz && cd minio-ce-deploy
sudo ./install.sh
# custom data path:  sudo DATA_DIR=/data/minio ./install.sh
```

The installer creates a `minio` system user, installs the binaries, generates
strong root credentials and console cookie secrets, and enables both services.
**The root user/password is printed once at the end — save it.**

## After install

```bash
systemctl status minio minio-console
mc alias set local http://127.0.0.1:9000 <user> <password>
mc admin info local
```

Open `http://<VM-IP>:9090` and log in with the root credentials to manage
users, policies, buckets, lifecycle, etc. through the full UI.

## Firewall (recommended for an isolated segment)

Allow 9000 and 9090 only from your admin/app subnet:

```bash
# ufw example
sudo ufw allow from <ADMIN_SUBNET> to any port 9000 proto tcp
sudo ufw allow from <ADMIN_SUBNET> to any port 9090 proto tcp
```

## Notes / caveats

- **Single-node single-drive**: MinIO does no erasure coding or self-healing here.
  Redundancy is your responsibility at the storage layer (Proxmox datastore /
  ZFS / RAID) and via backups. This matches the "one host = one node" design.
- **systemd hardening**: services run as the dedicated non-root `minio` user with
  `NoNewPrivileges`, private `/tmp`, protected kernel/control-group settings,
  SUID/SGID restrictions, and network families limited to Unix/IPv4/IPv6.
- **Console is a community fork** (opens3/console), pinned to a known commit.
  The MinIO server is official upstream CE source with local security hardening
  documented in `SECURITY.md`; `mc` is unmodified official upstream. Before
  bumping the server version, rebuild from official source and re-test the
  server/console pair in a staging VM.
- **Version label**: the server currently reports `DEVELOPMENT.2025-10-15...`
  (built from source without release ldflags). Functionally identical to the
  release commit. Rebuild with release stamping if you need `RELEASE.*` in logs.

## Update procedure (later)

1. Build new binaries from official source in a separate staging workspace.
2. Run a smoke test to confirm the console still pairs with the new server.
3. `systemctl stop minio-console minio`, replace binaries in `/usr/local/bin`,
   `systemctl start minio minio-console`. Config/secrets in `/etc/minio` are kept.
