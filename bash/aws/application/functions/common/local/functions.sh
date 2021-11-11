#!/usr/bin/env bash

### local functions to be called by global functions

function clean_s3_bucket_name_content {
  local s3_bucket_name=${1}

  aws s3 rm s3://"${s3_bucket_name}"/ --recursive || exit 1
}

function convert_delimited_string_to_shell_args {
  local command_flag=${1}
  local delimited_string=${2}
  local number_of_fields
  number_of_fields=$(echo "${delimited_string}" | gawk --field-separator=" " '{ print NF }')
  printf -- "${command_flag} "
  for ((i = 1 ; i <= number_of_fields ; i++)); do
    printf -- "$(echo "${delimited_string}" | tr -s " " | cut -d " " -f ${i}) "
  done
}

function download_artifact_from_s3 {
  local temp_download_folder=${1}
  local artifact_s3_bucket_name=${2}
  local application_name=${3}
  local version=${4}

  if [ "${version}" == "latest" ]; then
    local artifact
    artifact=$(get_latest_artifact "${artifact_s3_bucket_name}")
  else
    local artifact
    artifact=$(get_latest_artifact "${artifact_s3_bucket_name}" "${version}")
  fi

  echo "Found and downloading the Artifact - s3://${artifact_s3_bucket_name}/${artifact}"
  aws s3 cp "s3://${artifact_s3_bucket_name}/${artifact}" "${temp_download_folder}"/"${application_name}".zip 1> /dev/null || exit 1
}

# Determine which GIT tag component (minor or patch) to bump
# based on the feature branch name
function determine_git_tag_component {
  local head_branch=$1
  if [[ ${head_branch} =~ ^[Ff]eature/.*$ ]];
  then
    echo "minor"
  elif [[ ${head_branch} =~ ^(bug|Bug|Patch|patch)/.*$ ]]
  then
    echo "patch"
  else
    echo ""
  fi
}

function enable_asdf_in_container {
  source /root/.asdf/asdf.sh
}

function get_latest_artifact {
  local artifact_s3_bucket_name=${1}
  local version=${2}

  if [ -z "${version}" ]; then
    # Get latest
    local latest
    latest=$(                                            \
      aws s3 ls --recursive "${artifact_s3_bucket_name}" \
        | grep zip                                       \
        | awk '{print $4}'                               \
        | gawk --field-separator="/" '{print $1}'        \
        | sort -rV                                       \
        | head -n 1 || exit 1                            \
    )
    aws s3 ls --recursive "${artifact_s3_bucket_name}"   \
      | grep zip                                         \
      | awk '{print $4}'                                 \
      | grep "${latest}"  || exit 1
  else
    # Get version
    aws s3 ls --recursive ${artifact_s3_bucket_name}   \
      | awk '{print $4}'                               \
      | grep zip                                       \
      | grep "${version}" || exit 1
  fi
}

function invalidate_cloudfront_cache {
  local distribution_id=${1}
  local path_to_clear=${2}
  local timeout_duration=${3}
  local invalidation_id
  invalidation_id=$(                                                                                    \
    aws cloudfront create-invalidation --distribution-id "${distribution_id}" --path "${path_to_clear}" \
      | jq .Invalidation.Id                                                                             \
      | sed 's/"//g' || exit 1                                                                          \
  )

  echo "Invalidation ID is - ${invalidation_id}"

  local watch_time=0
  while true; do
    local invalidation_status
    invalidation_status=$(                                                                             \
      aws cloudfront get-invalidation --distribution-id "${distribution_id}" --id "${invalidation_id}" \
        | jq .Invalidation.Status                                                                      \
        | sed 's/"//g'                                                                                 \
        || exit 1                                                                                      \
    )
    sleep 2 && (( watch_time++ ))
    echo "Watch Time = ${watch_time} of ${timeout_duration} and current invalidation status is - ${invalidation_status}"
    [ "${invalidation_status}" == "Completed" ] && break
    if [ "${watch_time}" -gt "${timeout_duration}" ]; then
      echo "Timeout waiting for cache clear exceeded"
      break
    fi
  done
}

function replace_config_file {
  local s3_bucket_name=${1}
  local javascript_property_file=${2}
  local config_json="s3://${s3_bucket_name}/config.json"

  aws s3 cp "$javascript_property_file" "$config_json" || exit 1
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

function run_e2e_test {
  local source_directory=$1
  local environment_flag=$2

  echo "Running end to end test"
  echo "CWD is $(pwd)"
  cd "$source_directory" || exit 1

  npm install || exit 1
  HUSKY_SKIP_INSTALL=1 npm run build || exit 1
  HUSKY_SKIP_INSTALL=1 npm run e2e:headless -- --"${environment_flag}" || exit 1
}

function trigger_aws_codebuild {
  local project_name=${1}
  local command_flag=${2}
  local delimited_string="${3}"

  # shellcheck disable=SC2046
  # shellcheck disable=SC2086
 aws codebuild start-build --project-name "${project_name}" \
  $(convert_delimited_string_to_shell_args ${command_flag} "${delimited_string}") || exit 1
}

function unzip_local_artifact {
  local artifact_s3_bucket_name=${1}
  local application_name=${2}
  local version=${3}
  local javascript_property_file=${4}
  local temp_download_directory
  temp_download_directory=$(mktemp -d)
  local temp_unpack_directory
  temp_unpack_directory=$(mktemp -d)

  download_artifact_from_s3      \
    "${temp_download_directory}" \
    "${artifact_s3_bucket_name}" \
    "${application_name}"        \
    "${version}" 1> /dev/null || exit 1
  unzip "${temp_download_directory}/${application_name}.zip" -d "${temp_unpack_directory}" 1> /dev/null || exit 1
  if [ -f "${javascript_property_file}" ]; then
    chmod 0664 "${javascript_property_file}" 1> /dev/null || exit 1
    cp "${javascript_property_file}" "${temp_unpack_directory}/config.json" 1> /dev/null || exit 1
  fi
    echo "${temp_unpack_directory}"
}

function upload_static_site_content_to_s3 {
  local environment_s3_bucket_name=${1}
  local artifact_s3_bucket_name=${2}
  local application_name=${3}
  # Can be "existing git tag from master" or "latest" to fetch latest
  local version=${4}
  local javascript_property_file=${5}

  cd "$(                                                            \
    unzip_local_artifact                                            \
     "${artifact_s3_bucket_name}"                                   \
     "${application_name}"                                          \
     "${version}"                                                   \
     "${javascript_property_file}"                                  \
  )" || exit 1                                                      \
    && aws s3 sync . s3://"${environment_s3_bucket_name}" || exit 1 \
    && cd .. || exit 1
}

function validate_install_asdf_dependencies {
  [ ! -f ".tool-versions" ] && exit 1 || echo "asdf config file present in the repo"
  # asdf install all dependencies in .tool-versions file
  asdf install
  asdf current
}

function validate_head_branch {
  local head_branch=$1
  if [[ ${head_branch} =~ ^[Ff]eature/.*$ ]];
  then
    echo -e "The branch: ${head_branch} is a minor version change"
  elif [[ ${head_branch} =~ ^(bug|Bug|Patch|patch)/.*$ ]]
  then
    echo -e "The branch: ${head_branch} is a patch version change"
  else
    echo -e "The branch: ${head_branch} does not conform to the branch naming standard"
    exit 1
  fi
}

function verify_dependencies {
  verify_environment_dependency_exist 'aws'
  verify_environment_dependency_exist 'gawk'
  verify_environment_dependency_exist 'jq'
  verify_environment_dependency_exist 'mktemp'
  verify_environment_dependency_exist 'unzip'
}

function verify_environment_dependency_exist {
  local dependency_name=${1}
  if ! type "${dependency_name}"; then
    echo "${dependency_name} does not exist in the environment."
    exit 1
  fi
}

function verify_static_site {
  local site_url=${1}
  local expected_http_status_code=${2}

  if [[ "$(curl -I --silent https://${site_url})" =~ .*"${expected_http_status_code}".* ]]; then
    echo "The site - https://${site_url}) - has been validated."
  else
    echo "Validation of site url - https://${site_url} - failed!"
    exit 1
  fi
}
