#!/usr/bin/env bash
set -euo pipefail

: "${ROCK_NAME:?ROCK_NAME must be set}"
: "${SNAP_SUFFIX:?SNAP_SUFFIX must be set}"

# Check that rockcraft.yaml has a stage snap for this rock in the expected
# "name/track/risk" shape (any track/risk). This guards the rewrite below: an
# already-suffixed channel has four segments and will not match, so re-runs
# cannot double-append.
if ! yq \
    '.parts[] | select(has("stage-snaps")) | .["stage-snaps"][] | select(test("^" + strenv(ROCK_NAME) + "/[^/]+/[^/]+$"))' \
    "${ROCKCRAFT_FILE}" | grep -q .; then
  echo "No ${ROCK_NAME}/<track>/<risk> stage snap channel found in ${ROCKCRAFT_FILE}"
  exit 1
fi

# Rewrite rockcraft.yaml to append the PR suffix to the existing stage snap
# channel, preserving whatever track/risk is already there. For example,
# "valkey/9/edge" becomes "valkey/9/edge/pr-123".
yq -i \
  '(.parts[] | select(has("stage-snaps")) | .["stage-snaps"][] | select(test("^" + strenv(ROCK_NAME) + "/[^/]+/[^/]+$"))) |= . + "/" + strenv(SNAP_SUFFIX)' \
  "${ROCKCRAFT_FILE}"

git diff -- "${ROCKCRAFT_FILE}"