# Contributing to valkey-artifacts

This repository holds the packaging metadata Canonical uses to build and
publish [Valkey](https://valkey.io/) artifacts as both snaps and rocks (OCI
images) built from those snaps. It does not contain Valkey source code;
upstream sources are pulled in at build time via `stage-packages` /
`stage-snaps`.

## Repository structure

```
.
├── valkey/
│   ├── snaps/
│   │   ├── standard/    # valkey — full CLI toolset (server, cli, benchmark, sentinel, ...)
│   │   ├── chiseled/    # valkey-chiseled — minimal variant, server + cli only
│   │   └── charmed/     # valkey-charmed — adds the Prometheus redis-exporter, used by charms
│   └── rocks/
│       ├── standard/    # valkey — OCI image built from the standard snap
│       ├── chiseled/    # valkey-chiseled — OCI image built from the chiseled snap
│       └── charmed/     # valkey-charmed — OCI image built from the charmed snap
└── .github/
    ├── workflows/
    │   ├── lint.yaml               # yamllint on valkey/snaps/ and valkey/rocks/ on PR
    │   ├── snaps-discover.yaml     # discovers every */snap/snapcraft.yaml to build a matrix
    │   ├── rocks-discover.yaml     # discovers every */rockcraft.yaml to build a matrix
    │   ├── pr-rocks-from-snaps.yaml  # PR: publish snaps to a PR channel, then build/test rocks against them
    │   ├── snaps-pr-publish.yaml   # builds and publishes snaps to a PR channel
    │   ├── rocks-pr-tests.yaml     # builds, tests and secscan-scans rocks against a given snap channel
    │   ├── secscan-scan.yaml       # secscan vulnerability scan for a built snap or rock
    │   ├── publish.yaml            # release: publish snaps to edge, then build/test/scan/publish rocks to GHCR
    │   ├── snaps-publish.yaml      # builds and publishes snaps to the Snap Store edge channel
    │   ├── rocks-publish.yaml      # builds, tests, scans and publishes rocks to GHCR
    │   └── cla.yaml                # CLA check
    └── actions/
        └── test-rock/              # composite action: installs rockcraft/LXD, runs `rockcraft test`
```

Each snap/rock variant is self-contained: it has its own `snapcraft.yaml` (or
`rockcraft.yaml`), `spread.yaml` test suite, and `README.md`. CI discovers
variants dynamically — snaps by searching for `snap/snapcraft.yaml` files,
rocks by searching for `rockcraft.yaml` files — so a new variant only needs
to be added under `valkey/snaps/<name>/` or `valkey/rocks/<name>/` to be picked up by the
build and test matrix, no workflow changes required.

### Variants

| Variant  | Package name      | Description                                                                                                                              |
| -------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| standard | `valkey`          | Full toolset: `server`, `cli`, `benchmark`, `check-aof`, `check-rdb`, `sentinel`                                                         |
| chiseled | `valkey-chiseled` | Minimal variant built from Ubuntu packages, exposing only `server` and `cli`                                                             |
| charmed  | `valkey-charmed`  | Adds `sentinel` wrapper scripts and the `metrics-exporter` app, for use by [Valkey charms](https://github.com/canonical/valkey-operator) |

Each variant's snap and rock share the same package name, and every rock
stages the snap of the same name (see each `rockcraft.yaml`'s `stage-snaps`).

## Building a snap for development

### Clone the repository

```bash
git clone git@github.com:canonical/valkey-artifacts.git
cd valkey-artifacts/valkey/snaps/standard   # or chiseled / charmed
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
sudo snap install ./valkey*.snap --dangerous --jailmode
```

Use `--dangerous` to skip signature verification for a locally built snap.
`--devmode` is also acceptable while iterating, and additionally relaxes
confinement so you don't need to connect interfaces manually — but note that
disables confinement checks entirely, so don't use it to validate the final
`strict` confinement behaviour. 
`--jailmode` is the recommended option for development as it tests how a snap published with developer mode will behave when strictly confined.

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

## Building a rock for development

Each rock stages the snap of the same name from the Snap Store, so it always
builds against the latest published snap revision on the channel set in its
`rockcraft.yaml` (`stage-snaps`) — there's no need to build the snap locally
first.

### Clone the repository

```bash
git clone git@github.com:canonical/valkey-artifacts.git
cd valkey-artifacts/valkey/rocks/standard   # or chiseled / charmed
```

### Install and configure prerequisites

```bash
sudo snap install rockcraft --edge --classic
sudo snap install docker
sudo snap install lxd
sudo usermod -aG docker "$USER"
sudo lxd init --auto
```

You'll need to open a new shell (e.g. `su - $USER`) for the `docker` group
change to take effect.

### Pack and run the rock

```bash
rockcraft pack
rockcraft.skopeo --insecure-policy copy oci-archive:valkey*.rock docker-daemon:valkey:<tag>
docker run --rm -it valkey:<tag>
```

(Substitute `valkey-chiseled` / `valkey-charmed` for the rock name in the
variant you're working on.)

## Testing your changes

### Snaps

Each snap variant ships a [spread](https://github.com/canonical/spread) suite
under `snap/spread.yaml` plus `spread/tests/smoke/task.yaml`, run against a
real `craft` (LXD) backend on `ubuntu-26.04`. To run it locally:

```bash
cd valkey/snaps/standard   # or chiseled / charmed
snapcraft test
```

This mirrors what CI does: it installs the freshly built snap, starts the
`server` (and `sentinel`, where present) service, waits for `cli ping` to
return `PONG`, then runs the smoke test.

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

### Rocks

Each rock variant ships a `spread.yaml` at its root, run against a real
`craft` (LXD) backend on `ubuntu-26.04`. `rockcraft test` packs the rock and
runs the spread suite against it:

```bash
cd valkey/rocks/standard   # or chiseled / charmed
rockcraft test
```

This mirrors what CI does via `.github/actions/test-rock`: it loads the
packed rock into Docker, starts a container from it, and waits for
`valkey-cli ping` to return `PONG` before the suite's tasks run.

## Live debugging

**Snap logs:**

```bash
sudo snap logs valkey.server -f
```

**Service status:**

```bash
snap services valkey
```

**Rock container logs:**

```bash
docker logs -f <container-name>
```

## Continuous integration

On every pull request:

1. `lint.yaml` runs `yamllint` over `valkey/snaps/` and `valkey/rocks/`.
2. `pr-rocks-from-snaps.yaml` orchestrates the rest:
   - `snaps-pr-publish.yaml` builds every discovered snap, secscan-scans it
     (`secscan-scan.yaml`) and publishes it to a PR-scoped Snap Store channel
     (`9.0/edge/pr-<number>`).
   - Once the new snap revisions are live, `rocks-pr-tests.yaml` retargets
     each rock's `stage-snaps` at that PR channel, builds and tests the rock
     (via `.github/actions/test-rock`) on both `amd64` and `arm64`, then
     secscan-scans it (`secscan-scan.yaml`).

On every push to a release branch (e.g. `9.0/edge`), `publish.yaml`
orchestrates the same shape for real releases:

1. `snaps-publish.yaml` builds, secscan-scans and publishes every snap to the
   Snap Store edge channel.
2. Once those revisions are live, `rocks-publish.yaml` builds, tests, and
   secscan-scans every rock (staging the snap just published), then
   publishes it to GHCR.

Secscan scans use the `run-secscan` action from
[data-platform-workflows](https://github.com/skourta/data-platform-workflows/tree/secscan)
and submit results for SSDLC (product `valkey`, cycle `26.04`, channel
`edge`). Scan reports are uploaded as `secscan-results-*` workflow artifacts.
Set the optional `NVD_API_KEY` repository secret to enrich results with patch
information without hitting NVD rate limits.

## License

The packaging metadata in this repository is distributed under the Apache
Software License, version 2.0. See [LICENSE](LICENSE) for details, and the
`licenses/` directory within each artifact for the Valkey upstream licence.
