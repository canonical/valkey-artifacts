#!/usr/bin/env bash
set -euo pipefail

# Writes the manifest file that tells sbomber what to scan. It handles both
# runs we do, and SOURCE picks which one:
#
#   built      The rocks or snaps we just built, before we publish. Each entry
#              points at a file on disk, the same files the Trivy job reads, so
#              we never download anything.
#   published  What is live on the Snap Store or GHCR. sbomber fetches each one
#              itself, so we always scan the latest published revision.
#
# Required environment:
#   ARTIFACTS        List of {name, path} as JSON, from *-discover.yaml.
#   ARTIFACT_KIND    "rock" or "snap".
#
# Required when SOURCE is "built":
#   PKG_DIR          Folder that holds the built files.
#
# Required when REQUEST_SBOM is "true":
#   SBOM_DEPARTMENT  Department that owns the request.
#   SBOM_TEAM        Team that owns the request.
#   SBOM_EMAIL       Who to email when a report is ready.
#
# Optional environment:
#   SOURCE           "built" or "published". Default: built.
#   REQUEST_SBOM     "true" to ask for an official SBOM. Default: false.
#                    The SBOM service requires the store revision
#                    Only request after the artifact has been published.
#   PLATFORMS        CPU types, split by a space. Default: "amd64 arm64".
#                    Only used when SOURCE is "built".
#   CHANNEL          Store channel, such as 9/edge. The part after the slash
#                    is the channel name SSDLC wants. Default: 9/edge.
#   OUTPUT           Where to write the manifest. Default: sbom_manifest.yaml.
#   REPORT_SSDLC     "true" to send results to the SSDLC registry. Default:
#                    false, because we never release a PR build.
#   GHCR_NAMESPACE   Where published rocks live. Default: ghcr.io/canonical.

: "${ARTIFACTS:?ARTIFACTS must be set to a JSON list of {name, path}}"
: "${ARTIFACT_KIND:?ARTIFACT_KIND must be set to rock or snap}"

SOURCE="${SOURCE:-built}"
REQUEST_SBOM="${REQUEST_SBOM:-false}"

case "${SOURCE}" in
  built) : "${PKG_DIR:?PKG_DIR must be set when SOURCE is built}" ;;
  published) ;;
  *)
    echo "SOURCE must be 'built' or 'published', got '${SOURCE}'" >&2
    exit 1
    ;;
esac

if [[ "${REQUEST_SBOM}" == "true" ]]; then
  : "${SBOM_DEPARTMENT:?SBOM_DEPARTMENT must be set}"
  : "${SBOM_TEAM:?SBOM_TEAM must be set}"
  : "${SBOM_EMAIL:?SBOM_EMAIL must be set}"
fi

PLATFORMS="${PLATFORMS:-amd64 arm64}"
CHANNEL="${CHANNEL:-9/edge}"
OUTPUT="${OUTPUT:-sbom_manifest.yaml}"
REPORT_SSDLC="${REPORT_SSDLC:-false}"
GHCR_NAMESPACE="${GHCR_NAMESPACE:-ghcr.io/canonical}"

# "9/edge" -> "edge". SSDLC wants this, and rock tags end with it.
risk="${CHANNEL##*/}"

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

# Writes the ssdlc_params block, or nothing when we are not reporting.
# $1 name, $2 version, $3 cycle. An empty version means sbomber fills it in
# with the revision it downloaded.
write_ssdlc() {
  [[ "${REPORT_SSDLC}" == "true" ]] || return 0

  echo "    ssdlc_params:"
  echo "      name: $1"
  echo "      version: \"$2\""
  echo "      channel: ${risk}"
  echo "      cycle: \"$3\""
}

{
  echo "# Made by .github/scripts/generate-sbom-manifest.sh. Do not edit."
  echo "clients:"
  if [[ "${REQUEST_SBOM}" == "true" ]]; then
    echo "  sbom:"
    echo "    department: ${SBOM_DEPARTMENT}"
    echo "    team: ${SBOM_TEAM}"
    echo "    email: ${SBOM_EMAIL}"
  fi
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

  if [[ "${SOURCE}" == "published" ]]; then
    # One entry per artifact. sbomber pulls the host CPU type, so there is no
    # platform loop here.
    {
      echo "  - name: ${name}"
      echo "    type: ${ARTIFACT_KIND}"

      if [[ "${ARTIFACT_KIND}" == "snap" ]]; then
        # No version: sbomber reads the revision off the file it downloads.
        echo "    snap: ${name}"
        echo "    channel: ${CHANNEL}"
        write_ssdlc "${name}" "" "${cycle}"
      else
        # release_rock_edge.yaml tags rocks <version>-<base version>_<risk>.
        base=$(yq -r '.base' "${craft_file}")
        echo "    image: ${GHCR_NAMESPACE}/${name}"
        echo "    version: \"${version}-${base##*@}_${risk}\""
        write_ssdlc "${name}" "${version}" "${cycle}"
      fi
    } >>"${OUTPUT}"

    found=$((found + 1))
    continue
  fi

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
      write_ssdlc "${name}" "${version}" "${cycle}"
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
