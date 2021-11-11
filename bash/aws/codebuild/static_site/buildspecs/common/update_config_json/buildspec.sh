#!/usr/bin/env bash

SYSTEM_DEPS=""
SYSTEM_DEPS+=" curl"
SYSTEM_DEPS+=" gawk"
SYSTEM_DEPS+=" git"
SYSTEM_DEPS+=" gnupg2"
SYSTEM_DEPS+=" groff"
SYSTEM_DEPS+=" jq"
SYSTEM_DEPS+=" python3"
SYSTEM_DEPS+=" python3-pip"
SYSTEM_DEPS+=" wget"
SYSTEM_DEPS+=" unzip"
SYSTEM_DEPS+=" zip"

[ "${ENVIRONMENT}" == "notset" ] && exit 1
[ "${ENVIRONMENT}" == "qa" ] && {
  export ENVIRONMENT_S3_BUCKET_NAME=${QA_S3_BUCKET_NAME}
  export DISTRIBUTION_ID=${QA_DISTRIBUTION_ID}
}
[ "${ENVIRONMENT}" == "uat" ] && {
  export ENVIRONMENT_S3_BUCKET_NAME=${UAT_S3_BUCKET_NAME}
  export DISTRIBUTION_ID=${UAT_DISTRIBUTION_ID}
}
# Exit if environment not in qa, uat or prod
[ "${ENVIRONMENT_S3_BUCKET_NAME}" == "notset" ] && exit 1

ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get install -y --no-install-recommends ${SYSTEM_DEPS}
PYTHON_DEPS="awscli"
pip3 install ${PYTHON_DEPS}

cd ${CODEBUILD_SRC_DIR_CONFIG_JSON} || exit 1
[ "${CONFIG_JSON_REPO_COMMIT}" != "latest" ] && {
  git config --global hub.protocol https
  git config --global user.email $GITHUB_USER_EMAIL
  git config --global user.name $GITHUB_USER_NAME
  git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}-properties"
  git checkout ${CONFIG_JSON_REPO_COMMIT}
}
cd ${CODEBUILD_SRC_DIR} || exit 1
export CONFIG_JSON_FILE="${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.json"
bash -x ${AUTOMATION_HELPER_DIR}/bash/aws/codebuild/static_site/scripts/update_config_json.sh
