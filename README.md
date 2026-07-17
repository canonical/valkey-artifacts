# Valkey Artifacts
[![Build and test snaps](https://github.com/canonical/valkey-artifacts/actions/workflows/ci_snaps.yaml/badge.svg)](https://github.com/canonical/valkey-artifacts/actions/workflows/ci_snaps.yaml)

This repository contains the packaging metadata for all Canonical-distributed artifacts of [Valkey](https://valkey.io/) — an open-source, in-memory key-value datastore released under the BSD-3-Clause licence.

This branch packages Valkey as three snap variants:

| Variant  | Snap name         | Description                                                                      |
| -------- | ------------------ | --------------------------------------------------------------------------------- |
| standard | `valkey`          | Full toolset: `server`, `cli`, `benchmark`, `check-aof`, `check-rdb`, `sentinel`  |
| chiseled | `valkey-chiseled` | Minimal variant built from Ubuntu packages, exposing only `server` and `cli`     |
| charmed  | `valkey-charmed`  | Adds `sentinel` and the `metrics-exporter` app, for use by [Valkey charms](https://github.com/canonical/valkey-operator) |

See [CONTRIBUTOR.md](CONTRIBUTOR.md) for the repository structure, and build/test instructions.

## Licence

The packaging metadata in this repository is distributed under the Apache Software License, version 2.0. See the `licenses/` directory within each artifact for the full licence text, including the Valkey upstream licence.
