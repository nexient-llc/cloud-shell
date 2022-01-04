#!/usr/bin/env bash
#
# Source these bash functions for aws codebuild or codepipeline build needs.

### Ensure dependencies exist on system
function verify_dep {
  local dependency_name=${1}
  if ! type "${dependency_name}"; then
    echo "${dependency_name} does not exist in the environment."
    exit 1
  fi
}

### Local Functions used by scripts called by AWS Codebuild, don't require global vars set by AWS environment
# Not environment specific
function complete_invalidation_cloudfront_cache {
  local dist_id=${1}
  local path_to_clear=${2}
  local timeout_duration=${3}

  local invalidation_id=$(\
    aws cloudfront create-invalidation --distribution-id ${dist_id} --path "${path_to_clear}" | jq .Invalidation.Id \
      | sed 's/"//g' \
      || exit 1 \
  )

  echo "Invalidation ID is - ${invalidation_id}"

  local watch_time=0
  while true; do
    local invalidation_status=$(\
      aws cloudfront get-invalidation --distribution-id ${dist_id} --id ${invalidation_id} | jq .Invalidation.Status \
        | sed 's/"//g' \
        || exit 1 \
    )
    sleep 1 && (( watch_time++ ))
    echo "Watch Time = ${watch_time} of ${timeout_duration} and current invalidation status is - ${invalidation_status}"
    [ "${invalidation_status}" == "Completed" ] && break
    if [ "${watch_time}" -gt "${timeout_duration}" ]; then
      echo "Timeout waiting for cache clear exceeded"
      break
    fi
  done
}

function del_string_to_shell_args {
  local flag=${1}
  local del_string=${2}
  local number_of_fields=$(echo "${del_string}" | gawk --field-separator=" " '{ print NF }')
  printf -- "${flag} "
  for ((i = 1 ; i <= ${number_of_fields} ; i++)); do
    printf -- "$(echo "${del_string}" | tr -s " " | cut -d " " -f ${i}) "
  done
}

function download_artifact_to_local {
  local s3_bucket=${1}
  local tmp_download_folder=${2}
  local artifact_s3_bucket=${3}
  local app_name=${4}
  local version=${5}

  if [ "${version}" == "latest" ]; then
    local artifact=$(get_latest_artifact ${artifact_s3_bucket})
  else
     local artifact=$(get_latest_artifact ${artifact_s3_bucket} ${version})
  fi

  echo "Found and downloading the Artifact - s3://${artifact_s3_bucket}/${artifact}"
  aws s3 cp "s3://${artifact_s3_bucket}/${artifact}" ${tmp_download_folder}/${app_name}.zip 1> /dev/null || exit 1
}

function get_latest_artifact {
  local artifact_s3_bucket=${1}
  local version=${2}

  if [ -z ${version} ]; then
    # Find latest
    local latest=$(aws s3 ls --recursive ${artifact_s3_bucket} | grep zip | awk '{print $4}' | gawk --field-separator="/" '{print $1}' | sort -rV | head -n 1 || exit 1)
    aws s3 ls --recursive ${artifact_s3_bucket} | grep zip | awk '{print $4}' | grep "${latest}"  || exit 1
  else
    # Find version
    aws s3 ls --recursive ${artifact_s3_bucket} | awk '{print $4}' | grep zip | grep ${version} || exit 1
  fi

}

function run_command_if {
  local reverse_boolean=$1
  local comparator_1=$2
  local comparator_2=$3
  local command
  command=$4

  if ! [ "$reverse_boolean" == true ]; then
    if [ "${comparator_1}" == "${comparator_2}" ]; then
      if ! $command; then exit 1; fi
    else
      echo "skipped"
    fi
  else
    if [ "${comparator_1}" == "${comparator_2}" ]; then
      echo "skipped"
    else
      if ! $command; then exit 1; fi
    fi
  fi
}

function run_functional_test {
  local src_dir=$1
  local env_flag=$2

  echo "Running end to end test"
  echo "CWD is $(pwd)"
  cd $src_dir

  npm install || exit 1
  HUSKY_SKIP_INSTALL=1 npm run build || exit 1
  HUSKY_SKIP_INSTALL=1 npm run e2e:headless -- --${env_flag} || exit 1
}

function upload_artifact_to_s3 {
  local env_s3_bucket=${1}
  local artifact_s3_bucket=${2}
  local app_name=${3}

  # Can be "existing git tag from master" or "latest" to fetch latest
  local version=${4}
  local js_property_file=${5}

  cd "$(\
    unpack_local_artifact ${env_s3_bucket} ${artifact_s3_bucket} ${app_name} ${version} ${js_property_file}\
  )" || exit 1 \
    && aws s3 sync . s3://${env_s3_bucket} || exit 1 \
    && cd .. || exit 1
}

function unpack_local_artifact {
  local s3_bucket=${1}
  local artifact_s3_bucket=${2}
  local app_name=${3}
  local version=${4}
  local js_property_file=${5}

  local tmp_download_folder=$(mktemp -d)
  local tmp_unpack_folder=$(mktemp -d)

  download_artifact_to_local ${s3_bucket} ${tmp_download_folder} ${artifact_s3_bucket} ${app_name} ${version} 1> /dev/null || exit 1
  unzip "${tmp_download_folder}/${app_name}.zip" -d ${tmp_unpack_folder} 1> /dev/null || exit 1
  if [ -f "${js_property_file}" ]; then
    chmod 0664 "${js_property_file}" 1> /dev/null || exit 1
    local config_file_extension
    config_file_extension="${js_property_file##*.}"
    cp "${js_property_file}" "${tmp_unpack_folder}/config.${config_file_extension}" 1> /dev/null || exit 1
  fi
  echo ${tmp_unpack_folder}
}

function swap_config_file {
  local s3_bucket=${1}
  local js_property_file=${2}
  local config_file_extension
  config_file_extension="${js_property_file##*.}"
  aws s3 cp ${js_property_file} "s3://${s3_bucket}/config.${config_file_extension}" || exit 1
}

function start_aws_codebuild {
  local project_name=${1}
  local flag=${2}
  local del_string="${3}"

  aws codebuild start-build --project-name ${project_name} $(del_string_to_shell_args ${flag} "${del_string}") \
    || exit 1
}

function validate_static_site {
  local site_url=${1}
  local expected_http_status_code=${2}

  if [[ "$(curl -I --silent https://${site_url})" =~ .*"${expected_http_status_code}".* ]]; then
    echo "The site - https://${site_url}) - has been validated."
  else
    echo "Validation of site url - https://${site_url} - failed!"
    exit 1
  fi
}

function wipe_s3_bucket {
  local s3_bucket=${1}

  aws s3 rm s3://${s3_bucket}/ --recursive || exit 1
}

### Global Functions used by scripts called by AWS Codebuild, require global vars set by AWS environment
# Environment specific
function call_deploy_environment {
  [ ! -z ${VERSION} ] || exit 1 && echo "The Git Tag to be deployed is ${VERSION}"

  start_aws_codebuild "${ENV_CD_PROJECT_NAME}" "${FLAG}" \
  "name=ENVIRONMENT,value=${ENVIRONMENT},type=PLAINTEXT \
   name=ARTIFACT_TYPE,value=${ARTIFACT_TYPE},type=PLAINTEXT \
   name=VERSION,value=${VERSION},type=PLAINTEXT" || exit 1
}

function deploy_environment {
  wipe_s3_bucket $ENV_S3_BUCKET	|| exit 1
  upload_artifact_to_s3 $ENV_S3_BUCKET $ARTIFACT_S3_BUCKET $APP_NAME ${VERSION} ${CONFIG_JSON_FILE} || exit 1
  complete_invalidation_cloudfront_cache $DISTRIBUTION_ID "${PATH_TO_CLEAR}" $TIMEOUT_DURATION || exit 1
  validate_static_site "${SITE_URL}" "200" || exit 1
  local env=$3
  [ "${env}" == "qa" ] && {
    local e2e_test=$2
    if [ "$e2e_test" == "true" ]; then
      local src_dir="$1"

      run_functional_test $src_dir ${ENVIRONMENT} || exit 1
      # Trigger the OR create_artifact job
      start_aws_codebuild ${ENV_CREATE_ARTIFACT_PROJECT_NAME} \
        '--environment-variables-override' \
        "name=VERSION,value=${VERSION},type=PLAINTEXT \
        name=ARTIFACT_TYPE,value=or,type=PLAINTEXT" || exit 1
    fi

  } || echo "Skipped for UAT environment as e2e_test flag is ${e2e_test}"
}

function update_environment {
  if [ -z "${CONFIG_JSON_FILE}" ]; then echo "fatal: CONFIG_JSON_FILE not declared in AWS pipeline" && exit 1; fi

  swap_config_file ${ENV_S3_BUCKET} ${CONFIG_JSON_FILE} || exit 1
  complete_invalidation_cloudfront_cache $DISTRIBUTION_ID "${PATH_TO_CLEAR}" $TIMEOUT_DURATION || exit 1
}
