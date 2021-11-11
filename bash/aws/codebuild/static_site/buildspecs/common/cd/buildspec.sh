#!/usr/bin/env bash

LOCAL_FUNCTIONS="${AUTOMATION_HELPER_DIR}/bash/aws/application/functions/common/local/functions.sh"

# shellcheck disable=SC1090
if [ -f "$LOCAL_FUNCTIONS" ]; then
  source "${LOCAL_FUNCTIONS}"
else
  exit 1
fi

SYSTEM_DEPS=""
SYSTEM_DEPS+=" curl"
SYSTEM_DEPS+=" firefox"
SYSTEM_DEPS+=" gawk"
SYSTEM_DEPS+=" git"
SYSTEM_DEPS+=" gnupg2"
SYSTEM_DEPS+=" groff"
SYSTEM_DEPS+=" jq"
SYSTEM_DEPS+=" openjdk-11-jdk"
SYSTEM_DEPS+=" python3"
SYSTEM_DEPS+=" python3-pip"
SYSTEM_DEPS+=" wget"
SYSTEM_DEPS+=" unzip"
SYSTEM_DEPS+=" zip"

# Set the environment variables based on the ENVIRONMENT
[ "${ENVIRONMENT}" == "qa" ] && {
  export ENVIRONMENT_S3_BUCKET_NAME=${QA_S3_BUCKET_NAME}
  export DISTRIBUTION_ID=${QA_DISTRIBUTION_ID}
  export SITE_URL=${QA_SITE_URL}
}
[ "${ENVIRONMENT}" == "uat" ] && {
  export ENVIRONMENT_S3_BUCKET_NAME=${UAT_S3_BUCKET_NAME}
  export DISTRIBUTION_ID=${UAT_DISTRIBUTION_ID}
  export SITE_URL=${UAT_SITE_URL}
}
[ "${ARTIFACT_TYPE}" == "rc" ] && {
  export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_RC_BUCKET_NAME}
}
[ "${ARTIFACT_TYPE}" == "or" ] && {
  export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_OR_BUCKET_NAME}
}

ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get install -y --no-install-recommends ${SYSTEM_DEPS}
PYTHON_DEPS="awscli"
pip3 install ${PYTHON_DEPS}
verify_dependencies
export CHROME_URL='https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
wget "${CHROME_URL}"
apt install -y ./google-chrome-stable_current_amd64.deb
[ "${VERSION}" == "notset" ] && exit 1
echo "Deploying Artifact - ${VERSION} built from Git Tag - ${VERSION}"
cd ../ || exit 1
# Second source for properties repo
cd ${CODEBUILD_SRC_DIR_CONFIG_JSON} || exit 1
echo "CONFIG_JSON_REPO_COMMIT = ${CONFIG_JSON_REPO_COMMIT}"
# Checkout the commit version if provided in env vars
[ "${CONFIG_JSON_REPO_COMMIT}" != "latest" ] && {
  git config --global hub.protocol https
  git config --global user.email $GITHUB_USER_EMAIL
  git config --global user.name $GITHUB_USER_NAME
  git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}-properties"
  git checkout ${CONFIG_JSON_REPO_COMMIT}
}
cd "${CODEBUILD_SRC_DIR}" || exit 1

export CONFIG_JSON_FILE="${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.json"
export DEPLOY_CONTENT="${AUTOMATION_HELPER_DIR}/bash/aws/codebuild/static_site/scripts/deploy_content.sh"
# Deploy the environment
run_command_if "false" "${ENVIRONMENT}" "qa" "bash -x ${DEPLOY_CONTENT} ${CODEBUILD_SRC_DIR} ${E2E_TEST} ${ENVIRONMENT}"
run_command_if "false" "${ENVIRONMENT}" "uat" "bash -x ${DEPLOY_CONTENT} ${CODEBUILD_SRC_DIR} ${E2E_TEST} ${ENVIRONMENT}"
