#!/usr/bin/env bash

# valkey-check-aof opens files with "r+", even without --fix. Run it as
# snap_daemon, like the server, so it owns the AOF files and needs no
# CAP_DAC_OVERRIDE.
exec "${SNAP}"/usr/bin/setpriv \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}"/usr/bin/valkey-check-aof \
    "$@"
