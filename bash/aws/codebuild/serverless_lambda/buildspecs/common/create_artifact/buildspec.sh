#!/usr/bin/env bash

LOCAL_FUNCTIONS="${AUTOMATION_HELPER_DIR}/bash/aws/application/functions/common/local/functions.sh"

# shellcheck disable=SC1090
if [ -f "$LOCAL_FUNCTIONS" ]; then
  source "${LOCAL_FUNCTIONS}"
else
  exit 1
fi
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
# Print node and npm versions
echo -e "Node Version: $(node -v)\tNPM Version: $(npm -v)"
# Check and install serverless
type 'serverless'  || npm install -g serverless --unsafe-perm
echo -e "Serverless  version: \n$(sls -v)"

# Initialize the git
git config --global hub.protocol https
git config --global user.email ${GITHUB_USER_EMAIL}
git config --global user.name ${GITHUB_USER_NAME}
git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}"

PR_BRANCH=$(echo ${CODEBUILD_WEBHOOK_HEAD_REF} | sed -r 's@^(refs/heads/)(.+)@\2@')
BASE_BRANCH=$(echo ${CODEBUILD_WEBHOOK_BASE_REF} | sed -r 's@^(refs/heads/)(.+)@\2@')
if [ "${ARTIFACT_TYPE}" == "or" ] && [ "${ENVIRONMENT}" != "uat" ]
then
  echo "Environment: qa is not valid for Artifact Type: or"
  exit 1
fi

#TODO: Create a loop here to exports all environment variables from the applications property file that are keyed as to be environment vars

# For RC job, read the feature branch to determine which version component to bump
# Bump the version, checkout base branch (main), create tag, push modified package.json and tag to base branch
[ "${ARTIFACT_TYPE}" == "rc" ] && {
  PREVIOUS_VERSION=$(cat package.json | jq -r ".version")
  GIT_TAG_COMPONENT_TO_BUMP=$(determine_git_tag_component "${PR_BRANCH}")
  [ -z ${GIT_TAG_COMPONENT_TO_BUMP} ] && {
    exit 1
  } || {
    git checkout ${BASE_BRANCH} || exit 1
    git branch -vv
    # Bumps the version
    npm version ${GIT_TAG_COMPONENT_TO_BUMP}
    VERSION=$(cat package.json | jq -r ".version")
    # Git tag created in form of v1.0.0
    VERSION="v${VERSION}"
    # Push the commit and the tag to base branch
    git push -u origin ${BASE_BRANCH} --follow-tags || exit 1
  }
}
[ "${VERSION}" == "notset" ] && exit 1
[ "${ARTIFACT_TYPE}" == "notset" ] && exit 1 || echo "Version is set to - ${VERSION}"

# Repo for environment properties
cd ${CODEBUILD_SRC_DIR_CONFIG_JSON} || exit 1
echo "CONFIG_JSON_REPO_COMMIT = ${CONFIG_JSON_REPO_COMMIT}"
# Checkout the commit version if provided in env vars
[ "${CONFIG_JSON_REPO_COMMIT}" != "latest" ] && git checkout ${CONFIG_JSON_REPO_COMMIT}
cd "${CODEBUILD_SRC_DIR}" || exit 1
cp "${CODEBUILD_SRC_DIR_CONFIG_JSON}/deploy_properties/${ENVIRONMENT}-config.json" "${CODEBUILD_SRC_DIR}/${ENVIRONMENT}-config.json" || exit 1
echo "Building ${ARTIFACT_TYPE} Artifact from git tag version - ${VERSION}"

# Checkout the git tag for OR job
run_command_if "false" "${ARTIFACT_TYPE}" "or" "git fetch --tags"
run_command_if "false" "${ARTIFACT_TYPE}" "or" "git checkout refs/tags/${VERSION}"
npm install --quiet --no-progress
# Create artifact package using serverless package command
sls package -s ${ENVIRONMENT} -p ${ARTIFACT_DIR}
# Zip the artifacts into artifact.zip
cd ${ARTIFACT_DIR} || exit 1
zip -r ../artifact.zip *
cd ..
# Set the bucket name
[ "${ARTIFACT_TYPE}" == "rc" ] && export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_RC_BUCKET_NAME}
[ "${ARTIFACT_TYPE}" == "or" ] && export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_OR_BUCKET_NAME}
# Copy the artifacts to S3
aws s3api put-object --bucket ${ARTIFACT_S3_BUCKET_NAME} --key ${APPLICATION_NAME}-${ARTIFACT_TYPE}-${VERSION}/ || exit 1
aws s3 cp ./artifact.zip s3://${ARTIFACT_S3_BUCKET_NAME}/${APPLICATION_NAME}-${ARTIFACT_TYPE}-${VERSION}/ || exit 1
# Need to set the environment=uat to trigger the uat CD job
run_command_if "false" "${ARTIFACT_TYPE}" "or" "export ENVIRONMENT=uat"
# Trigger the CD Job
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "bash -x ${AUTOMATION_HELPER_DIR}/bash/aws/codebuild/serverless_lambda/scripts/trigger_lambda_service_deploy.sh"
run_command_if "false" "${ARTIFACT_TYPE}" "or" "bash -x ${AUTOMATION_HELPER_DIR}/bash/aws/codebuild/serverless_lambda/scripts/trigger_lambda_service_deploy.sh"
