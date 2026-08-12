# Valkey Artifacts
[![Publish artifacts](https://github.com/canonical/valkey-artifacts/actions/workflows/publish.yaml/badge.svg)](https://github.com/canonical/valkey-artifacts/actions/workflows/publish.yaml)

This repository contains the packaging metadata for all Canonical-distributed artifacts of [Valkey](https://valkey.io/) — an open-source, in-memory key-value datastore released under the BSD-3-Clause licence.

This branch packages Valkey 7 as a snap and as a rock (OCI image) built from that snap:

| Variant  | Package name | Description                                                                     |
| -------- | ------------ | ------------------------------------------------------------------------------- |
| standard | `valkey`     | Full toolset: `server`, `cli`, `benchmark`, `check-aof`, `check-rdb`, `sentinel` |

The rock additionally bundles the Prometheus `redis_exporter` service alongside
`valkey` and `sentinel`.

See [CONTRIBUTOR.md](CONTRIBUTOR.md) for the repository structure, and build/test instructions.

## Licence

The packaging metadata in this repository is distributed under the Apache Software License, version 2.0. See the `licenses/` directory within each artifact for the full licence text, including the Valkey upstream licence.
