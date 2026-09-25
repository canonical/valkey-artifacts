# Valkey Chiseled rock
[![Publish artifacts](https://github.com/canonical/valkey-artifacts/actions/workflows/publish.yaml/badge.svg)](https://github.com/canonical/valkey-artifacts/actions/workflows/publish.yaml)

This repository contains the packaging metadata for creating an OCI rock of
the Valkey Chiseled variant. This variant provides a streamlined footprint
focused on the core Valkey server and tools (`valkey-cli`, `valkey-benchmark`,
`valkey-check-aof`, `valkey-check-rdb`), excluding `valkey-sentinel`.

For more information on rocks, visit the
[Rockcraft documentation](https://documentation.ubuntu.com/rockcraft/).

## How to use this rock

### Building and loading the rock

Install prerequisites:

```bash
sudo snap install rockcraft --classic
sudo snap install docker
sudo snap install lxd
sudo usermod -aG docker,lxd $USER
sudo lxd init --auto
```

Build the rock:

```bash
cd valkey/rocks/chiseled
rockcraft pack
```

Load the rock into Docker:

```bash
rockcraft.skopeo --insecure-policy copy \
  oci-archive:valkey-chiseled_*.rock \
  docker-daemon:valkey-chiseled:<tag>
```

### Start a Valkey instance

```bash
docker run --name some-valkey -d -p 6379:6379 valkey-chiseled:<tag>
```

### Passing arguments

The entrypoint is Pebble (`pebble enter`), which runs Valkey as the `valkey`
service. Arguments after the image name go to Pebble, not to Valkey:

* `--args valkey <command> [args...]` replaces the service command, for
  example `--args valkey valkey-server --port 6380`.
* `exec <command> [args...]` runs a one-off command instead of the service.
  It keeps stdin, the TTY and the exit code, for example `-it ... exec sh`.

Unlike the upstream image, `docker run valkey-chiseled:<tag> --port 6380` or
`docker run valkey-chiseled:<tag> valkey-server ...` do not reach Valkey.

### Start with persistent storage

Data is stored in `/data`. You can attach a persistent volume to this directory:

```bash
docker run --name some-valkey -d -p 6379:6379 \
  -v /my/own/datadir:/data \
  valkey-chiseled:<tag> --args valkey valkey-server --save 60 1 --loglevel warning
```

Valkey will save snapshots (`dump.rdb`) to `/data`. The container sets a `0077`
umask by default so database files are only readable by the `valkey` user.

### Connecting via `valkey-cli`

Connect from inside a running Valkey container:

```bash
docker exec -it some-valkey valkey-cli
```

Or from a new container over Docker networking:

```bash
docker run -it --network some-network --rm valkey-chiseled:<tag> \
  exec valkey-cli -h some-valkey
```

### Using a custom `valkey.conf`

You can mount your own configuration file into the container:

```bash
docker run -d --name some-valkey -p 6379:6379 \
  -v /my/valkey.conf:/usr/local/etc/valkey/valkey.conf:ro \
  valkey-chiseled:<tag> --args valkey valkey-server /usr/local/etc/valkey/valkey.conf
```

### Using `VALKEY_EXTRA_FLAGS`

You can pass additional command-line options via the `VALKEY_EXTRA_FLAGS`
environment variable:

```bash
docker run -d --name some-valkey \
  -e VALKEY_EXTRA_FLAGS="--loglevel notice" \
  valkey-chiseled:<tag>
```

### Security and process user

* **Protected mode**: As in the upstream image, `protected-mode` is `no` by
  default. A configuration file that sets `protected-mode` keeps its value.
  It is strongly recommended to set a password when exposing ports
  externally.
* **Process user**: The container starts as `root` to ensure correct ownership
  of `/data`, then drops privileges to the `valkey` user (UID/GID `999`).
* **Running as non-root**: You can run directly as a specific user with
  `--user valkey` or `--user <uid>:<gid>`. Ensure the mounted `/data` volume
  is writable by that UID.

## License

The Valkey Chiseled rock is free software, distributed under the Apache
Software License, version 2.0. See `licenses` for more information.
