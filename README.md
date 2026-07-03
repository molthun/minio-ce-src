# minio-ce-src — reproducible build & maintenance for the hardened MinIO CE deploy

This repo is the **source/build layer** for the `Work/minio-ce-deploy` artifact.
It does **not** vendor upstream source or binaries. Instead it *reproducibly
rebuilds* everything from official upstream at pinned commits, applies a small,
documented set of security + branding patches, and assembles the deploy package.

> Ongoing job: keep the isolated Proxmox MinIO up to date and **close new CVEs**.
> Workflow: edit a patch or a version pin → rebuild → re-scan → re-smoke → re-package → push.

## What gets built

| Artifact | Upstream | Local changes |
| --- | --- | --- |
| `minio` | official CE @ `RELEASE.2025-10-15` | 5 security dependency bumps + 3 local CVE code patches |
| `mc` | official CE @ `RELEASE.2025-08-13` | none (verbatim upstream) |
| `minio-console` | `opens3/console` fork @ `78fe28a` | OPENS3 → MinIO branding (logo, favicon, title) |

All pins live in [`versions.env`](versions.env). Change them there, nowhere else.

## Layout

```
versions.env               pinned commits / tags / dep versions
scripts/
  00-bootstrap-toolchain.sh  download the pinned Go toolchain into work/
  10-fetch-sources.sh        clone minio / mc / console at pinned commits
  20-patch-minio.sh          apply dep bumps + CVE code patches to minio
  30-patch-console.sh        apply MinIO branding to the console build assets
  40-build.sh                build all three linux/amd64 binaries into dist/
  50-scan.sh                 govulncheck the patched minio source
  60-smoke.sh                run server + console, exercise the admin API
  70-package.sh              assemble dist/minio-ce-deploy.tar.gz + CHECKSUMS
  build-all.sh               run 00→70 end to end
patches/minio/             CVE code patches (*.patch) + spec
console-branding/          logo-swap.js, MinIO SVGs, apply-branding.sh
```

`work/`, `dist/`, `pkg/`, `cache/` are build outputs — git-ignored.

## Prerequisites

- Linux / WSL with `git`, `curl`, `tar`, `perl`, `bash`, internet access (build host only).
- ~3 GB free for the cloned sources + Go build cache.
- No Node.js required — the console frontend is patched as prebuilt assets.

## Build from scratch

```bash
git clone https://git.molthun.ru/Work/minio-ce-src.git
cd minio-ce-src
bash scripts/build-all.sh
# result: dist/minio-ce-deploy.tar.gz  (+ CHECKSUMS.sha256)
```

## How to close a new CVE

1. `govulncheck` runs in `50-scan.sh`; note the module + fixed version, or the
   advisory + affected code path.
2. **Dependency CVE** → add/adjust a `go get module@fixed` line in
   `scripts/20-patch-minio.sh` (and `versions.env`).
3. **Code CVE in minio itself** → add a `patches/minio/CVE-XXXX-*.patch` and wire
   it into `20-patch-minio.sh`. See `patches/minio/CVE-PATCHES.md` for the
   existing three and the format.
4. Rebuild + verify:
   ```bash
   bash scripts/build-all.sh          # or 20/40/50/60/70 individually
   ```
   `50-scan.sh` must show the finding gone; `60-smoke.sh` must stay green.
5. Commit, push, then rebuild the deploy artifact and update `Work/minio-ce-deploy`.

## Provenance

- Full CVE scan + patch rationale: carried over in the deploy repo's `SECURITY.md`.
- Branding details: deploy repo's `BRANDING.md`.
- The console fork logo swap is a runtime asset patch (no minified-bundle edits).

## Trademark note

The MinIO name/logo are trademarks of MinIO, Inc. The console rebrand and the
built binaries are for an **isolated internal deployment only** — keep this repo
and the deploy repo **private**. Do not redistribute publicly.
