#!/usr/bin/env bash

# Source the functions
FUNCTIONS="${CLOUD_SHELL_DIR}/aws/functions/functions.sh"
if [ -f "${FUNCTIONS}" ]; then
  source "${FUNCTIONS}"
else
  exit 1
fi

source /root/.asdf/asdf.sh

# Verify the system dependencies
verify_dep 'aws' || exit 1
verify_dep 'gawk' || exit 1
verify_dep 'jq' || exit 1
verify_dep 'mktemp' || exit 1
verify_dep 'unzip' || exit 1
verify_dep 'asdf' || exit 1

# Currently not required for this job
[ ! -f ".tool-versions" ] && exit 1 || echo "asdf config file present in the repo"
asdf install
asdf current
verify_dep 'node' || exit 1
verify_dep 'npm' || exit 1
npm install -g --allow-root --unsafe-perm=true npm
asdf reshim
npm -v
node -v

# Set the S3 Buckets as per environment
[ "${ENVIRONMENT}" == "qa" ] && {
  export ENV_S3_BUCKET=${QA_S3_BUCKET}
  export DISTRIBUTION_ID=${QA_DISTRIBUTION_ID}
  export SITE_URL=${QA_SITE_URL}
}
[ "${ENVIRONMENT}" == "uat" ] && {
  export ENV_S3_BUCKET=${UAT_S3_BUCKET}
  export DISTRIBUTION_ID=${UAT_DISTRIBUTION_ID}
  export SITE_URL=${UAT_SITE_URL}
  export E2E_TEST="false"
}

[ "${ARTIFACT_TYPE}" == "rc" ] && {
  export ARTIFACT_S3_BUCKET=${ARTIFACT_S3_RC_BUCKET}
}
[ "${ARTIFACT_TYPE}" == "or" ] && {
  export ARTIFACT_S3_BUCKET=${ARTIFACT_S3_OR_BUCKET}
}

# Always get the latest versions of firefox and chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
yes | dpkg -i google-chrome-stable_current_amd64.deb
apt update && apt --fix-broken install -y
apt install -y firefox
echo "Deploying Artifact - ${VERSION} built from Git Tag - ${VERSION}"
cd ../
# Second source for properties repo
cd ${CODEBUILD_SRC_DIR_CONFIG_JSON} || exit 1
echo "CONFIG_JSON_REPO_COMMIT = ${CONFIG_JSON_REPO_COMMIT}"
# Checkout the commit version if provided in env vars
if [ "${CONFIG_JSON_REPO_COMMIT}" != "latest" ]; then git checkout ${CONFIG_JSON_REPO_COMMIT}; fi
cd ${CODEBUILD_SRC_DIR} || exit 1
git config --global hub.protocol https
git config --global user.email $GITHUB_USER_EMAIL
git config --global user.name $GITHUB_USERNAME
export DEPLOY_ENVIRONMENT="${CLOUD_SHELL_DIR}/aws/codebuild/scripts/deploy_environment.sh"
# Support JS file
[ -f "${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.json" ] && export CONFIG_JSON_FILE="${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.json"
[ -f "${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.js" ] && export CONFIG_JSON_FILE="${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.js"
echo -e "CONFIG_JSON_FILE=${CONFIG_JSON_FILE}"
# Deploy the static site and conditionally trigger the next Create Artifact job
bash -x "${DEPLOY_ENVIRONMENT}" "${CODEBUILD_SRC_DIR}" "${E2E_TEST}" "${ENVIRONMENT}"
