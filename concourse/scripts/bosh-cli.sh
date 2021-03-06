#!/bin/bash

set -eu
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

export TARGET_CONCOURSE=deployer
# shellcheck disable=SC2091
$("${SCRIPT_DIR}/environment.sh")
"${SCRIPT_DIR}/fly_sync_and_login.sh"

OUTPUT_FILE=$(mktemp -t bosh-cli.XXXXXX)
trap 'rm -f "${OUTPUT_FILE}"' EXIT

$FLY_CMD -t "${FLY_TARGET}" trigger-job -j create-bosh-cloudfoundry/bosh-cli -w | tee "${OUTPUT_FILE}"

BUILD_NUMBER=$(awk '/started create-bosh-cloudfoundry\/bosh-cli/ { print $3 }' "${OUTPUT_FILE}" | tr -d '#')

$FLY_CMD -t "${FLY_TARGET}" intercept -j create-bosh-cloudfoundry/bosh-cli -b "${BUILD_NUMBER}" \
   -s run-bosh-cli "${@:-ash}"
