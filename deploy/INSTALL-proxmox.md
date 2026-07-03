# Install runbook — MinIO CE on a Proxmox VM (single node)

Isolated / air-gapped. Access by `ip:port` only. No domains, no TLS, no internet
needed on the target. One host = one node.

Artifact: `minio-ce-deploy.tar.gz` (this package).

---

## 0. Recommended VM (Proxmox)

| Resource | Recommendation |
| --- | --- |
| OS | Debian 12 or Ubuntu 22.04/24.04 LTS (minimal), systemd |
| vCPU | 2–4 |
| RAM | 4 GB minimum, 8 GB comfortable |
| System disk | 20–30 GB (OS + binaries) |
| Data disk | separate disk presented from the Proxmox datastore, sized to need |
| CPU type | `host` (for best performance) |
| Network | one NIC on the isolated segment; static IP |

Redundancy is handled by the storage layer (datastore / ZFS / RAID) + backups —
MinIO single-node single-drive does **no** erasure coding itself.

---

## 1. Prepare the data disk (on the VM)

Identify the presented disk (e.g. `/dev/sdb`) with `lsblk`, then:

```bash
sudo mkfs.xfs /dev/sdb                      # or ext4
sudo mkdir -p /mnt/minio/data
echo '/dev/sdb /mnt/minio/data xfs defaults,noatime 0 2' | sudo tee -a /etc/fstab
sudo mount -a
mountpoint /mnt/minio/data && echo "mounted OK"
```

> Use the disk's `/dev/disk/by-id/...` path in fstab if device names may change.

---

## 2. Transfer the package to the VM

From your workstation (has the tarball):

```bash
scp minio-ce-deploy.tar.gz user@<VM-IP>:/tmp/
```

If the VM is fully air-gapped: copy the tarball via the Proxmox ISO/v/mount or a
one-time attached disk instead of scp.

---

## 3. Install

```bash
ssh user@<VM-IP>
cd /tmp && tar xzf minio-ce-deploy.tar.gz && cd minio-ce-deploy
sudo ./install.sh
# custom data path:  sudo DATA_DIR=/data/minio ./install.sh
```

The installer:
- creates the `minio` system user,
- installs `minio`, `mc`, `minio-console` to `/usr/local/bin`,
- generates strong root credentials + console cookie secrets in `/etc/minio/`,
- installs and starts the hardened systemd services.

**Copy the ROOT credentials printed at the end — they are shown only once.**

---

## 4. Firewall (isolated segment)

Expose only the two ports, only to your admin/app subnet:

```bash
sudo ufw allow from <ADMIN_SUBNET> to any port 9000 proto tcp   # S3 API
sudo ufw allow from <ADMIN_SUBNET> to any port 9090 proto tcp   # web console
sudo ufw enable
```

The built-in stripped console stays bound to `127.0.0.1:9001` (not exposed).

---

## 5. Verify

```bash
systemctl status minio minio-console        # both active (running)
mc alias set local http://127.0.0.1:9000 <root-user> <root-pass>
mc admin info local                         # cluster reachable
mc mb local/test && mc ls local && mc rb local/test
```

Then open the web console and log in with the root credentials:

```
http://<VM-IP>:9090
```

You should see the MinIO-branded UI and be able to manage buckets, users, and
policies.

---

## 6. Endpoints

| Purpose | URL |
| --- | --- |
| S3 API (apps, `mc`, SDKs) | `http://<VM-IP>:9000` |
| Web admin console | `http://<VM-IP>:9090` |

---

## 7. Day-2 notes

- **Backups**: snapshot the data disk / datastore and back up `/etc/minio/`
  (contains root creds + console secrets) before any change.
- **Create app service accounts** in the console instead of sharing the root user.
- **Updates**: rebuild binaries from the build tree, re-run the smoke test to
  confirm the server↔console pair, then replace `/usr/local/bin/minio*` and
  restart. Config in `/etc/minio/` is preserved.
- Security posture, applied CVE patches, and accepted findings: see `SECURITY.md`.
- Console branding details / how to revert: see `BRANDING.md`.
- Full reference and caveats: see `README.md` (in this package).

## Uninstall

```bash
sudo ./uninstall.sh          # removes services + binaries; keeps data & config
```
