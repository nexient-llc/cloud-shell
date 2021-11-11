#!/usr/bin/env bash

LOCAL_FUNCTIONS="${AUTOMATION_HELPER_DIR}/bash/aws/application/functions/common/local/functions.sh"

# shellcheck disable=SC1090
if [ -f "$LOCAL_FUNCTIONS" ]; then
  source "${LOCAL_FUNCTIONS}"
else
  exit 1
fi

verify_dependencies

# Global Function to be called by scripts
# These functions require Global Environment variable provided by aws codebuild
function build_codebuild_static_site_cd_job {
  [ -n "${VERSION}" ] || exit 1 && echo "The Git Tag to be deployed is ${VERSION}"

  trigger_aws_codebuild "${ENV_CD_PROJECT_NAME}" "${FLAG}" \
  "name=ARTIFACT_TYPE,value=${ARTIFACT_TYPE},type=PLAINTEXT \
   name=ENVIRONMENT,value=${ENVIRONMENT},type=PLAINTEXT \
   name=VERSION,value=${VERSION},type=PLAINTEXT" || exit 1
}

function trigger_codebuild_serverless_lambda_cd_job {
  [ -n "${VERSION}" ] || exit 1 && echo "The Git Tag to be deployed is ${VERSION}"

  trigger_aws_codebuild "${ENV_CD_PROJECT_NAME}" "${FLAG}" \
  "name=ARTIFACT_TYPE,value=${ARTIFACT_TYPE},type=PLAINTEXT \
   name=ENVIRONMENT,value=${ENVIRONMENT},type=PLAINTEXT \
   name=VERSION,value=${VERSION},type=PLAINTEXT" || exit 1
}

function deploy_static_site_content {
  local src_dir="$1"
  local e2e_test=$2
  local env=$3
  clean_s3_bucket_name_content "$ENVIRONMENT_S3_BUCKET_NAME" || exit 1
  upload_static_site_content_to_s3 \
    "$ENVIRONMENT_S3_BUCKET_NAME" \
    "$ARTIFACT_S3_BUCKET_NAME" \
    "$APPLICATION_NAME" "${VERSION}" \
    "${CONFIG_JSON_FILE}" || exit 1
  invalidate_cloudfront_cache \
    "$DISTRIBUTION_ID" \
    "${PATH_TO_CLEAR}" \
    "$TIMEOUT_DURATION" || exit 1
  verify_static_site "${SITE_URL}" "200" || exit 1
  [ "${env}" == "qa" ] && {
    [ "$e2e_test" == "true" ] && {
      run_e2e_test "$src_dir" "${env}" || exit 1
      start_aws_codebuild "${ENV_CREATE_ARTIFACT_PROJECT_NAME}" \
        '--environment-variables-override' \
        "name=VERSION,value=${VERSION},type=PLAINTEXT \
        name=ARTIFACT_TYPE,value=or,type=PLAINTEXT" || exit 1
    } || echo "Flag e2e_test is : ${e2e_test}"
  } || echo "Skipped"
}

function update_static_site_properties {
  if [ -z "${CONFIG_JSON_FILE}" ]; then
    echo "fatal: ${CONFIG_JSON_FILE} not declared in AWS pipeline"
    exit 1
  fi

  replace_config_file "${ENVIRONMENT_S3_BUCKET_NAME}" "${CONFIG_JSON_FILE}" || exit 1
  invalidate_cloudfront_cache \
    "$DISTRIBUTION_ID" \
    "${PATH_TO_CLEAR}" \
    "$TIMEOUT_DURATION" || exit 1
}
