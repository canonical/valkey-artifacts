#!/usr/bin/env bash
set -euo pipefail

# Stops the job if any sbomber request did not work.
#
# We cannot trust sbomber to do this. When an upload fails, `submit` writes the
# error to its state file but still passes. Then `poll` only looks at files
# that are still waiting, so it skips the failed ones and also passes. The job
# turns green even when we got no SBOM at all (see run 33515106392).
#
# Optional environment:
#   STATEFILE  Where sbomber keeps its state. Default: .statefile.yaml

STATEFILE="${STATEFILE:-.statefile.yaml}"

if [[ ! -f "${STATEFILE}" ]]; then
  echo "No sbomber statefile at ${STATEFILE}: did 'prepare' run?" >&2
  exit 1
fi

# Each row is "<name>\t<service>\t<status>". A file is checked against the
# services it picked, or against all of them if it picked none.
rows=$(yq -o=json '.' "${STATEFILE}" | jq -r '
  (.clients | keys) as $all
  | .artifacts[] as $a
  | (($a.clients // $all)[]) as $c
  | [$a.name, $c, ($a.processing[$c].status // "Not started")]
  | @tsv
')

total=0
failed=0
report=""

while IFS=$'\t' read -r name client status; do
  [[ -z "${name}" ]] && continue
  total=$((total + 1))

  if [[ "${status}" == "Succeeded" ]]; then
    mark="ok"
  else
    mark="FAILED"
    failed=$((failed + 1))
  fi

  line=$(printf '%-34s %-8s %-12s %s' "${name}" "${client}" "${status}" "${mark}")
  echo "${line}"
  report="${report}"$'\n'"| \`${name}\` | ${client} | ${status} |"
done <<<"${rows}"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### sbomber results"
    echo
    echo "| Artifact | Client | Status |"
    echo "|---|---|---|"
    echo "${report}" | sed '/^$/d'
  } >>"${GITHUB_STEP_SUMMARY}"
fi

if [[ "${total}" -eq 0 ]]; then
  echo "No artifact/client pairs found in ${STATEFILE}; nothing was scanned." >&2
  exit 1
fi

if [[ "${failed}" -gt 0 ]]; then
  echo >&2
  echo "${failed} of ${total} sbomber request(s) did not succeed." >&2
  echo "Scroll up for the sbomber submit/poll output with the server response." >&2
  exit 1
fi

echo
echo "All ${total} sbomber request(s) succeeded."
