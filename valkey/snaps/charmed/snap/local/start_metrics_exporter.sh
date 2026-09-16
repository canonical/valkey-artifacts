#!/usr/bin/env bash

# Source optional charm configuration if present
ENV_FILE="${SNAP_DATA}/etc/valkey/metrics-exporter.env"
if [ -f "${ENV_FILE}" ]; then
    set -a
    # shellcheck disable=SC1090
    . "${ENV_FILE}"
    set +a
fi

# For security measures, daemons should not be run as sudo. Execute the
# exporter as the non-sudo user: snap-daemon.
exec "${SNAP}"/usr/bin/setpriv \
    --clear-groups \
    --reuid snap_daemon \
    --regid snap_daemon \
    -- \
    "${SNAP}"/usr/bin/prometheus-redis-exporter
