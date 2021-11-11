#!/usr/bin/env bash

# shellcheck disable=SC1090
source "${AUTOMATION_HELPER_DIR}/bash/aws/application/functions/global/functions.sh" || exit 1

build_codebuild_static_site_cd_job
