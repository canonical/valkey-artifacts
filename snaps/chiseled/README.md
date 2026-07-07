# Chiseled Valkey Snap
[![Build and test snaps](https://github.com/canonical/valkey-artifacts/actions/workflows/ci_snaps.yaml/badge.svg)](https://github.com/canonical/valkey-artifacts/actions/workflows/ci_snaps.yaml)

This directory contains the packaging metadata for creating a chiseled snap of Valkey. The chiseled variant is a minimal snap built from Ubuntu packages, exposing only the server and CLI commands.
For more information on snaps, visit [snapcraft.io](https://snapcraft.io/).

## Installing the Snap
The snap can be installed directly from the Snap Store. Follow the link below for more information.
<br>

[![Get it from the Snap Store](https://snapcraft.io/static/images/badges/en/snap-store-black.svg)](https://snapcraft.io/valkey-chiseled)

```bash
sudo snap install valkey-chiseled --edge
```

## Interaction with the snap
By default, the snap will install and run the valkey-server. You can connect to the server via cli:

```bash
valkey-chiseled.cli
127.0.0.1:6379> ping
PONG
```

This is the minimal variant: only `server` and `cli` apps are provided.
Other available commands can be found here: `snap info valkey-chiseled`

## Building the Snap
### Clone Repository
```bash
git clone git@github.com:canonical/valkey-artifacts.git
cd valkey-artifacts/snaps/chiseled
```
### Installing and Configuring Prerequisites
```bash
sudo snap install snapcraft --classic
sudo snap install lxd
sudo lxd init --auto
```
### Packing and Installing the Snap
```bash
snapcraft pack
sudo snap install ./valkey-chiseled*.snap --dangerous
```

Use `--dangerous` to skip signature verification for a locally built snap.
`--devmode` is also acceptable while iterating, and additionally relaxes
confinement so you don't need to connect interfaces manually — but it
disables confinement checks entirely, so don't use it to validate the final
`strict` confinement behaviour.

## Testing the Snap
This variant ships a [spread](https://github.com/canonical/spread) smoke
test, run against a real `craft` (LXD) backend on `ubuntu-26.04`:

```bash
snapcraft test
```

## License
The Chiseled Valkey Snap is free software, distributed under the Apache
Software License, version 2.0. See
[LICENSE](https://github.com/canonical/valkey-artifacts/blob/main/LICENSE)
for more information.
