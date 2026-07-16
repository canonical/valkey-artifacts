# Valkey rock
[![Publish artifacts](https://github.com/canonical/valkey-artifacts/actions/workflows/publish.yaml/badge.svg)](https://github.com/canonical/valkey-artifacts/actions/workflows/publish.yaml)

This repository contains the packaging metadata for creating a rock image of Valkey. For more information on rocks, 
visit the [rockcraft Github](https://github.com/canonical/rockcraft).

## Building the rock
The steps outlined below are based on the assumption that you are building the rock with the latest LTS of Ubuntu.  
If you are using another version of Ubuntu or another operating system, the process may be different.

### Clone Repository
```bash
git clone git@github.com:canonical/valkey-artifacts.git
cd valkey-artifacts/valkey/rocks/standard
```
### Installing Prerequisites
```bash
sudo snap install rockcraft --edge --classic
sudo snap install docker
sudo snap install lxd
```
### Configuring Prerequisites
```bash
sudo usermod -aG docker $USER 
sudo lxd init --auto
```
*_NOTE:_* You will need to open a new shell for the group change to take effect (i.e. `su - $USER`)
### Packing and Running the rock
```bash
rockcraft pack
rockcraft.skopeo --insecure-policy copy oci-archive:valkey*.rock docker-daemon:valkey:<tag>
docker run --rm -it valkey:<tag>
```

## License:
The Valkey rock is free software, distributed under the Apache Software License, version 2.0. See licenses for 
more information.