# Contributing to valkey-artifacts

This repository holds the packaging metadata Canonical uses to build and
publish [Valkey](https://valkey.io/) artifacts — currently snaps, with rock
(OCI) images maintained alongside them. It does not contain Valkey source
code; upstream sources are pulled in at build time via `stage-packages` /
`stage-snaps`.

## Repository structure

```
.
├── snaps/
│   ├── standard/    # valkey — full CLI toolset (server, cli, benchmark, sentinel, ...)
│   ├── chiseled/    # valkey-chiseled — minimal variant, server + cli only
│   └── charmed/     # valkey-charmed — adds the Prometheus redis-exporter, used by charms
└── .github/workflows/
    ├── ci_snaps.yaml         # lint, build and test snaps on PR
    ├── snaps-discover.yaml   # discovers every snap/*/snap/snapcraft.yaml to build a matrix
    ├── snaps-publish.yaml    # builds and publishes to the Snap Store on release branches
    └── cla.yaml              # CLA check
```

Each snap/rock variant is self-contained: it has its own `snapcraft.yaml` (or
`rockcraft.yaml`), `spread.yaml` test suite, and `README.md`. CI discovers
variants dynamically by searching for `snap/snapcraft.yaml` files, so a new
variant only needs to be added under `snaps/<name>/` to be picked up by the
build and test matrix — no workflow changes required.

### Snap variants

| Variant  | Snap name         | Description                                                                                                                                  |
| -------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| standard | `valkey`          | Full toolset: `server`, `cli`, `benchmark`, `check-aof`, `check-rdb`, `sentinel`                                                             |
| chiseled | `valkey-chiseled` | Minimal variant built from Ubuntu packages, exposing only `server` and `cli`                                                                 |
| charmed  | `valkey-charmed`  | Adds `sentinel` wrapper scripts and the `metrics-exporter` app, for use by [Valkey charms](https://github.com/canonical/charmed-valkey-snap) |

## Building a snap for development

### Clone the repository

```bash
git clone git@github.com:canonical/valkey-artifacts.git
cd valkey-artifacts/snaps/standard   # or chiseled / charmed
```

### Install and configure prerequisites

```bash
sudo snap install snapcraft --classic
sudo snap install lxd
sudo lxd init --auto
```

### Pack and install the snap

```bash
snapcraft pack
sudo snap install ./valkey*.snap --dangerous
```

Use `--dangerous` to skip signature verification for a locally built snap.
`--devmode` is also acceptable while iterating, and additionally relaxes
confinement so you don't need to connect interfaces manually — but note that
disables confinement checks entirely, so don't use it to validate the final
`strict` confinement behaviour.

## Interacting with the snap

The `server` app runs as a daemon on install. Talk to it with the bundled
`cli`:

```bash
valkey.cli ping
# PONG
```

(Substitute `valkey-chiseled` / `valkey-charmed` for the snap name in the
variant you're working on.) All app names for a variant are listed via:

```bash
snap info ./valkey*.snap
```

## Testing your changes

Each variant ships a [spread](https://github.com/canonical/spread) suite
under `snap/spread.yaml` plus `spread/tests/smoke/task.yaml`, run against a
real `craft` (LXD) backend on `ubuntu-26.04`. To run it locally:

```bash
cd snaps/standard   # or chiseled / charmed
snapcraft pack
spread craft:
```

This mirrors what CI does in `ci_snaps.yaml`: it installs the freshly built
snap, starts the `server` (and `sentinel`, where present) service, waits for
`cli ping` to return `PONG`, then runs the smoke test.

To sanity-check manually instead of via spread:

```bash
sudo snap install ./valkey*.snap --dangerous
sudo snap start valkey.server

retry=0
until valkey.cli ping 2>/dev/null | grep -q PONG; do
  retry=$((retry + 1))
  [ "$retry" -ge 30 ] && { echo "server did not come up"; exit 1; }
  sleep 1
done

valkey.cli info
```

## Live debugging

**Snap logs:**

```bash
sudo snap logs valkey.server -f
```

**Service status:**

```bash
snap services valkey
```

## Continuous integration

`ci_snaps.yaml` runs on every pull request targeting `9.0/edge` and:

1. Lints all YAML under `snaps/` with `yamllint`.
2. Discovers every snap variant (`snaps-discover.yaml`).
3. Builds each discovered variant in parallel.
4. Installs each built snap and exercises `server` (and `sentinel`, if
   present) exactly as described above.

`snaps-publish.yaml` runs the same discover/build steps on pushes to release
branches (e.g. `9.0/edge`) and publishes the resulting snaps to the Snap
Store edge channel.

## License

The packaging metadata in this repository is distributed under the Apache
Software License, version 2.0. See [LICENSE](LICENSE) for details, and the
`licenses/` directory within each artifact for the Valkey upstream licence.
