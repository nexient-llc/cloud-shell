#!/usr/bin/env bash

LOCAL_FUNCTIONS="${AUTOMATION_HELPER_DIR}/bash/aws/application/functions/common/local/functions.sh"

# shellcheck disable=SC1090
if [ -f "$LOCAL_FUNCTIONS" ]; then
  source "${LOCAL_FUNCTIONS}"
else
  exit 1
fi

SYSTEM_DEPS=""
# Required to source the asdf in asdf-ubuntu-focal:1.2.0 image
enable_asdf_in_container

# Verify the system dependencies
verify_environment_dependency_exist 'git' || exit 1
verify_environment_dependency_exist 'asdf' || exit 1
# Checks for the .tool-versions file and installs asdf dependencies
validate_install_asdf_dependencies
# Verify node and npm
verify_environment_dependency_exist 'node' || exit 1
verify_environment_dependency_exist 'npm' || exit 1
echo -e "Node Version: $(node -v)\tNPM Version: $(npm -v)"
# Check and install serverless
type 'serverless'  || npm install -g serverless --unsafe-perm
echo -e "Serverless  version: \n$(sls -v)"

[ "${ARTIFACT_TYPE}" == "rc" ] && {
  export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_RC_BUCKET_NAME}
}
[ "${ARTIFACT_TYPE}" == "or" ] && {
  export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_OR_BUCKET_NAME}
}

#TODO: Create a loop here to exports all environment variables from the applications property file that are keyed as to be environment vars

[ "${VERSION}" == "notset" ] && exit 1
echo "Deploying Artifact - ${VERSION} built from Git Tag - ${VERSION}"

git config --global hub.protocol https
git config --global user.email $GITHUB_USER_EMAIL
git config --global user.name $GITHUB_USER_NAME
git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}"
git fetch --tags
git checkout refs/tags/${VERSION} || exit 1

# Second source for properties repo
cd ${CODEBUILD_SRC_DIR_CONFIG_JSON} || exit 1
echo "CONFIG_JSON_REPO_COMMIT = ${CONFIG_JSON_REPO_COMMIT}"
# Checkout the commit version if provided in env vars
[ "${CONFIG_JSON_REPO_COMMIT}" != "latest" ] && git checkout ${CONFIG_JSON_REPO_COMMIT}
cd "${CODEBUILD_SRC_DIR}" || exit 1
cp "${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.json" "${CODEBUILD_SRC_DIR}/${ENVIRONMENT}-config.json" || exit 1

ARTIFACT_DIR="${CODEBUILD_SRC_DIR}/output"
# Downloads the zip to ${CODEBUILD_SRC_DIR}/${APPLICATION_NAME}.zip
download_artifact_from_s3 "${CODEBUILD_SRC_DIR}" ${ARTIFACT_S3_BUCKET_NAME} ${APPLICATION_NAME} ${VERSION}
unzip "${CODEBUILD_SRC_DIR}/${APPLICATION_NAME}.zip" -d ${ARTIFACT_DIR} || exit 1
# this step is only required to run the sls command. The plugins defined in the serverless.yml should be installed else it complains
npm install --quiet --no-progress
# Deploys the lambda service in AWS
sls deploy -v -s ${ENVIRONMENT} -p ${ARTIFACT_DIR}
