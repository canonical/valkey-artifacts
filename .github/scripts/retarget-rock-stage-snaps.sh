#!/usr/bin/env bash
set -euo pipefail

: "${ROCK_NAME:?ROCK_NAME must be set}"
: "${SNAP_CHANNEL:?SNAP_CHANNEL must be set}"

TRACK="7"

# Check that rockcraft.yaml has stage snaps for this rock pointing at the
# expected channel, 
if ! yq \
    '.parts[] | select(has("stage-snaps")) | .["stage-snaps"][] | select(test("^" + strenv(ROCK_NAME) + "/'"${TRACK}"'/edge$"))' \
    "${ROCKCRAFT_FILE}" | grep -q .; then
  echo "No ${ROCK_NAME}/${TRACK}/edge stage snap channel found in ${ROCKCRAFT_FILE}"
  exit 1
fi

# Rewrite rockcraft.yaml to point stage snaps at the PR snap channel. For
# example, "mongodb-server-sharded/9.0/edge" becomes
# "mongodb-server-sharded/9.0/edge/pr-123".
yq -i \
  '(.parts[] | select(has("stage-snaps")) | .["stage-snaps"][]) |= sub("/'"${TRACK}"'/edge$"; "/" + strenv(SNAP_CHANNEL))' \
  "${ROCKCRAFT_FILE}"

git diff -- "${ROCKCRAFT_FILE}"