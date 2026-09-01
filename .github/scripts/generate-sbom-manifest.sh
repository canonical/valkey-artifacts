#!/usr/bin/env bash
set -euo pipefail

# Writes the manifest file that tells sbomber what to scan. It lists the rocks
# or snaps we built in this run, so we can scan them before we publish.
#
# It uses the same built files as the Trivy job. Each entry points at a file on
# disk, so we never download anything from the Snap Store or GHCR.
#
# Required environment:
#   ARTIFACTS        List of {name, path} as JSON, from *-discover.yaml.
#   ARTIFACT_KIND    "rock" or "snap".
#   PKG_DIR          Folder that holds the built files.
#   SBOM_DEPARTMENT  Department that owns the request.
#   SBOM_TEAM        Team that owns the request.
#   SBOM_EMAIL       Who to email when a report is ready.
#
# Optional environment:
#   PLATFORMS        CPU types, split by a space. Default: "amd64 arm64".
#   OUTPUT           Where to write the manifest. Default: sbom_manifest.yaml.
#   RELEASE_CHANNEL  Channel name for SSDLC. Default: edge.
#   REPORT_SSDLC     "true" to send results to the SSDLC registry. Default:
#                    false, because we never release a PR build.

: "${ARTIFACTS:?ARTIFACTS must be set to a JSON list of {name, path}}"
: "${ARTIFACT_KIND:?ARTIFACT_KIND must be set to rock or snap}"
: "${PKG_DIR:?PKG_DIR must be set}"
: "${SBOM_DEPARTMENT:?SBOM_DEPARTMENT must be set}"
: "${SBOM_TEAM:?SBOM_TEAM must be set}"
: "${SBOM_EMAIL:?SBOM_EMAIL must be set}"

PLATFORMS="${PLATFORMS:-amd64 arm64}"
OUTPUT="${OUTPUT:-sbom_manifest.yaml}"
RELEASE_CHANNEL="${RELEASE_CHANNEL:-edge}"
REPORT_SSDLC="${REPORT_SSDLC:-false}"

case "${ARTIFACT_KIND}" in
  rock) craft_relpath="rockcraft.yaml" ;;
  snap) craft_relpath="snap/snapcraft.yaml" ;;
  *)
    echo "ARTIFACT_KIND must be 'rock' or 'snap', got '${ARTIFACT_KIND}'" >&2
    exit 1
    ;;
esac

# SSDLC needs the Ubuntu version we build on. Rocks say "ubuntu@26.04", or
# "bare" and then we read build-base. Snaps say "core26".
resolve_cycle() {
  local craft_file="$1" base

  base=$(yq -r '.base' "${craft_file}")

  case "${base}" in
    bare)
      base=$(yq -r '.build-base' "${craft_file}")
      echo "${base##*@}"
      ;;
    core*)
      echo "${base#core}.04" # "core26" -> "26.04"
      ;;
    *)
      echo "${base##*@}" # "ubuntu@26.04" -> "26.04"
      ;;
  esac
}

{
  echo "# Made by .github/scripts/generate-sbom-manifest.sh. Do not edit."
  echo "clients:"
  echo "  sbom:"
  echo "    department: ${SBOM_DEPARTMENT}"
  echo "    team: ${SBOM_TEAM}"
  echo "    email: ${SBOM_EMAIL}"
  echo "  secscan: {}"
  echo
  echo "artifacts:"
} >"${OUTPUT}"

found=0
while read -r name path; do
  craft_file="${path}/${craft_relpath}"
  if [[ ! -f "${craft_file}" ]]; then
    echo "No ${craft_relpath} found at ${path}" >&2
    exit 1
  fi

  version=$(yq -r '.version' "${craft_file}")
  cycle=$(resolve_cycle "${craft_file}")

  for platform in ${PLATFORMS}; do
    # rockcraft and snapcraft both name files <name>_<version>_<cpu>.<ext>.
    file=$(find "${PKG_DIR}" -type f \
      -name "${name}_*_${platform}.${ARTIFACT_KIND}" | sort | head -n1)

    if [[ -z "${file}" ]]; then
      echo "No ${name}_*_${platform}.${ARTIFACT_KIND} found in ${PKG_DIR}" >&2
      echo "Available files:" >&2
      find "${PKG_DIR}" -type f >&2
      exit 1
    fi

    {
      # We always write the version. sbomber cannot work it out for a rock,
      # and for a snap we built here it would read the version as "amd64".
      echo "  - name: ${name}-${platform}"
      echo "    type: ${ARTIFACT_KIND}"
      echo "    source: $(realpath "${file}")"
      echo "    version: \"${version}\""

      if [[ "${REPORT_SSDLC}" == "true" ]]; then
        echo "    ssdlc_params:"
        echo "      name: ${name}"
        echo "      version: \"${version}\""
        echo "      channel: ${RELEASE_CHANNEL}"
        echo "      cycle: \"${cycle}\""
      fi
    } >>"${OUTPUT}"

    found=$((found + 1))
  done
done < <(jq -r '.[] | "\(.name) \(.path)"' <<<"${ARTIFACTS}")

if [[ "${found}" -eq 0 ]]; then
  echo "No artifacts matched; refusing to submit an empty manifest" >&2
  exit 1
fi

echo "Wrote ${OUTPUT} with ${found} artifact(s):"
cat "${OUTPUT}"
