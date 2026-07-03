# Security scan & patch report — MinIO CE build

Scan date: **2026-07-03**
Scanner: **govulncheck v1.5.0** (source mode / call-graph reachability), DB `https://vuln.go.dev`
Go toolchain: **go1.26.4**

This report documents the known-vulnerability scan of every shipped binary, the
patches applied at build time, the local code hardening applied for post-CE
MinIO advisories, and the disposition of every finding.

## 1. Method

`govulncheck ./...` was run in **source mode** against each source tree during
staging. Source mode performs call-graph reachability analysis, so a finding
means the vulnerable symbol is actually reachable from the program's entry
points — not merely present in a dependency. Raw staging reports are not shipped
in this deploy repository.

Only the latest official upstream versions were used as the baseline; there are no
newer official releases to bump to:

| Component | Pinned = latest upstream? |
| --- | --- |
| minio `RELEASE.2025-10-15T17-29-55Z` | yes — newest official release (repo in maintenance mode) |
| mc `RELEASE.2025-08-13T08-35-41Z` | yes — newest official release |
| opens3/console `78fe28a` | yes — fork HEAD |

## 2. Result summary

| Binary | Before | After | Action |
| --- | --- | --- | --- |
| **minio** | 18 reachable (6 modules) + 3 upstream post-CE advisories | **4** (1 module) | dependency bumps + 3 local code hardening patches |
| **mc** | 4 reachable (1 module) | 4 | none — see §5 (non-exploitable) |
| **console** | 4 reachable (1 module) | 4 | none — see §5 (non-exploitable) |

14 of the 18 minio findings were remediated. The 4 remaining in every binary are
the same non-exploitable Prometheus-library findings (§5).

## 3. Patch applied to minio (build-time dependency bumps)

Official minio source was **not** code-forked. Only `go.mod`/`go.sum` were updated
via `go get` + `go mod tidy`, then rebuilt. This is standard distribution-level
maintenance. Exact version changes:

| Module | From | To | Fixes |
| --- | --- | --- | --- |
| `golang.org/x/crypto` | v0.37.0 | **v0.52.0** | 9 SSH CVEs (GO-2026-5013/5014/5015/5017/5018/5019/5020/5023, GO-2025-4134) |
| `golang.org/x/net` | v0.39.0 | **v0.55.0** | GO-2026-4918 (HTTP/2 DoS), GO-2026-5026 (idna) |
| `github.com/go-jose/go-jose/v4` | v4.1.0 | **v4.1.4** | GO-2026-4945 (JWE decryption panic) |
| `go.opentelemetry.io/otel/sdk` (+otel core set) | v1.35.0 | **v1.40.0** | GO-2026-4394 (PATH-hijack code exec) |
| `github.com/eclipse/paho.mqtt.golang` | v1.5.0 | **v1.5.1** | GO-2025-4173 (MQTT string encoding) |

`go mod tidy` also carried transitive bumps (`x/sys`, `x/text`, `x/term`,
`x/mod`, `x/tools`, `x/sync`, `go-logr`, `otel/*`) and raised the `go` directive
1.24→1.25 (required by x/crypto v0.52). Built with go1.26.4.

## 4. Local code hardening for post-CE MinIO advisories

The official CE repository is archived, while newer advisories list fixes in
AIStor releases. To keep the CE server usable in an isolated deployment without
switching to an unknown fork, three minimal source patches were applied locally:

| Advisory | Surface | Local patch |
| --- | --- | --- |
| CVE-2026-41145 / GHSA-hv4r-mvr4-25vw | `STREAMING-UNSIGNED-PAYLOAD-TRAILER` object uploads | `PutObjectHandler` and `PutObjectPartHandler` reject the vulnerable combination of unsigned-trailer uploads with query-string V4 credentials and no `Authorization` header, while preserving normal `mc`/SDK header-auth uploads. |
| CVE-2026-42600 / GHSA-xh8f-g2qw-gcm7 | internode `ReadMultiple` storage REST endpoint | `xlStorage.ReadMultiple` now rejects any bucket/prefix/file combination whose cleaned path leaves the resolved volume root. This preserves compatibility while closing traversal. |
| CVE-2026-39414 / GHSA-h749-fxx7-pwpg | S3 Select CSV line splitting | CSV and JSON S3 Select splitters now read via bounded `ReadSlice` loops and reject records over 16 MiB, preventing memory exhaustion on newline-free input. |

Changed files:

- `cmd/object-handlers.go`
- `cmd/object-multipart-handlers.go`
- `cmd/xl-storage.go`
- `internal/s3select/csv/reader.go`
- `internal/s3select/json/preader.go`

New minio binary SHA256: `beebdd52649d9b931104d4b9fa787ec3d0ca8e7b1b3791c404d773a31c26e505`

## 5. Fixed CVEs — relevance in this deployment

All 14 fixed issues were feature-gated (only reachable when the named optional
feature is enabled). They are now patched regardless.

| CVE | Component | Trigger surface |
| --- | --- | --- |
| GO-2026-5013…5023, GO-2025-4134 | x/crypto SSH | minio **SFTP server** (`--sftp`) |
| GO-2026-4918 | x/net HTTP/2 | outbound HTTP client (metrics push, replication, webhooks) |
| GO-2026-5026 | x/net idna | hostname handling in outbound requests |
| GO-2026-4945 | go-jose | **OIDC** identity provider login |
| GO-2026-4394 | otel/sdk | **GCS** warm-tier backend |
| GO-2025-4173 | paho.mqtt | **MQTT** event notification target |

## 6. Accepted findings — the 4 remaining (all binaries)

These are **left unpatched deliberately** and assessed as non-exploitable in this
deployment. Remediating them requires bumping `github.com/prometheus/prometheus`
by 8+ minor versions (v0.303 → v0.311), which is high-risk for the build and, for
one of them, has no fix at all.

| CVE | Description | Why not exploitable here |
| --- | --- | --- |
| GO-2026-5710 | Prometheus Azure AD OAuth secret exposure via config API | minio/mc/console never run Prometheus' config API server |
| GO-2026-5662 | Stored XSS in Prometheus **web UI** (no fix available) | no Prometheus web UI is served by any of these binaries |
| GO-2026-5381 | Stored XSS in Prometheus old web UI heatmap | same — no Prometheus web UI served |
| GO-2026-5264 | DoS on Prometheus **remote-read** endpoint | no remote-read endpoint is exposed |

Why govulncheck still flags them: the vulnerable module is pulled in transitively
(via `madmin`), and the reachable symbols are only the `histogram` bucket
iterators used to **parse/encode metric values** — not the vulnerable web-UI /
remote-read / config-API code paths, which are never instantiated. The advisories
concern Prometheus-the-server, not the library math these binaries use.

**Re-evaluate** if a future minio release moves to a fixed Prometheus, or if you
ever front these services with the actual Prometheus web UI.

## 7. Operational hardening (defence in depth)

The isolated `ip:port` deployment already removes most external surface. In
addition:

- Leave **SFTP, OIDC, MQTT, and GCS tiering disabled** unless required — that keeps
  even the *patched* code paths dormant.
- Block `X-Amz-Content-Sha256: STREAMING-UNSIGNED-PAYLOAD-TRAILER` at a reverse
  proxy/WAF if one is introduced later. The server patch rejects the vulnerable
  no-Authorization variant; the proxy rule is still useful defence in depth.
- Run the MinIO service as the dedicated non-root `minio` user created by the
  installer, not as root.
- Keep the console (9090) and S3 API (9000) reachable only from the admin/app
  subnet (see `README.md` and `INSTALL-proxmox.md` firewall sections).
- The built-in stripped console is bound to `127.0.0.1:9001` and not exposed.

## 8. Verification

Latest verification after the code hardening:

- `go test ./internal/s3select/...` — passed.
- `verify-after-patch.sh` — passed.
- Deep console smoke test — passed: web UI HTTP 200, console login, bucket
  create/list, server-side `mc` bucket confirmation, IAM user create/list,
  policy list, admin info.
- `govulncheck ./...` against patched MinIO still reports only the four accepted
  Prometheus-library findings in §6.

## 9. Reproduce / re-verify

This repository is the production deploy artifact, not the build workspace. To
re-verify or prepare a CVE update:

1. Create a separate staging workspace.
2. Clone the official upstream sources listed in `PROVENANCE.md`.
3. Apply the dependency bumps and local hardening patches described above.
4. Run `govulncheck ./...` in source mode for each source tree.
5. Run functional smoke tests against a staging VM or container.
6. Replace the shipped binaries here only after the scan and smoke tests pass.
7. Update `CHECKSUMS.sha256`, `SECURITY.md`, and `PROVENANCE.md` in the same
   commit as the binary update.
