#!/usr/bin/env bash

conf="${SNAP_DATA}/etc/valkey/logrotate.conf"
[ -f "${conf}" ] || exit 0 # charm hasn't written it yet

state_dir="${SNAP_COMMON}/var/lib/logrotate"
mkdir -p "${state_dir}"
chown snap_daemon:root "${state_dir}"

# Run as snap_daemon, which owns the log dir, so renames inside it need no
# extra capabilities.
exec "${SNAP}"/usr/bin/setpriv \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}"/usr/sbin/logrotate -s "${state_dir}/status" "${conf}"
