#!/usr/bin/env bash

SRC_DIR=$1
E2E_TEST=$2
ENVIRONMENT=$3

# shellcheck disable=SC1090
source "${AUTOMATION_HELPER_DIR}/bash/aws/application/functions/global/functions.sh" || exit 1

deploy_static_site_content "$SRC_DIR" "$E2E_TEST" "${ENVIRONMENT}"
