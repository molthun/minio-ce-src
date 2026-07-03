# Console branding

The bundled `bin/minio-console` is built from the AGPL `opens3/console` project
and rebranded for this internal deployment so the web UI presents as
`MinIO Console`.

## What changed

- Browser title and web-app metadata: `OpenS3 Console` -> `MinIO Console`.
- Login/sidebar logo: OPENS3 wordmark -> MinIO wordmark.
- Collapsed sidebar icon and browser favicon: MinIO mark.

The branding patch is embedded in the shipped `bin/minio-console` binary. No
frontend source tree or Node build chain is included in this deploy repository.

## Verification

The rebuilt console binary in this repository has SHA256:

```text
0d067424272e132e287687b3821f423e22c7d38f3c6bb7aec34579acb35b9703  bin/minio-console
```

At runtime the web UI should show:

- tab title `MinIO Console`;
- MinIO wordmark on the login page;
- MinIO wordmark in the expanded sidebar;
- MinIO mark in the collapsed sidebar.

## Trademark note

The MinIO name and logo are trademarks of MinIO, Inc. This rebrand is intended
for an isolated internal deployment. Do not redistribute this rebranded console
binary publicly without reviewing trademark and license obligations.
