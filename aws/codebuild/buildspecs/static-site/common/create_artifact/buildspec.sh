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

# Create the VERSION for RC build. For OR build, VERSION is passed as env var
[ "${ARTIFACT_TYPE}" == "rc" ] && VERSION="$(date +%Y-%m-%d-%s)"
[ "${VERSION}" == "notset" ] && exit 1
[ "${ARTIFACT_TYPE}" == "notset" ] && exit 1 || echo "Version is set to - ${VERSION}"
echo "Building ${ARTIFACT_TYPE} Artifact from git tag version - ${VERSION}"

[ ! -f ".tool-versions" ] && exit 1 || echo "asdf config file present in the repo"
asdf install
asdf current
verify_dep 'node' || exit 1
verify_dep 'npm' || exit 1
npm install -g --allow-root --unsafe-perm=true npm
asdf reshim
npm -v
node -v

git config --global hub.protocol https
git config --global user.email ${GITHUB_USER_EMAIL}
git config --global user.name ${GITHUB_USER_NAME}
git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}"
# Create and push the tag in case of RC build
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "git tag ${VERSION}"
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "git push origin ${VERSION}"
#- Fetch and checkout the tag in case of OR build
run_command_if "false" "${ARTIFACT_TYPE}" "or" "git fetch --tags"
run_command_if "false" "${ARTIFACT_TYPE}" "or" "git checkout refs/tags/${VERSION}"
# Run npm task to generate artifacts at the path ARTIFACT_FILE
npm install
# Creates the artifacts
HUSKY_SKIP_INSTALL=1 npm run build || exit 1
# Set the s3 bucket name based on ARTIFACT_TYPE
[ "${ARTIFACT_TYPE}" == "rc" ] && export ARTIFACT_S3_BUCKET=${ARTIFACT_S3_RC_BUCKET}
[ "${ARTIFACT_TYPE}" == "or" ] && export ARTIFACT_S3_BUCKET=${ARTIFACT_S3_OR_BUCKET}
aws s3api put-object --bucket ${ARTIFACT_S3_BUCKET} --key ${APP_NAME}-${ARTIFACT_TYPE}-${VERSION}/ || exit 1
aws s3 cp ${ARTIFACT_FILE} s3://${ARTIFACT_S3_BUCKET}/${APP_NAME}-${ARTIFACT_TYPE}-${VERSION}/ || exit 1

# Trigger the next CD job in case of RC job
run_command_if "false" "${ARTIFACT_TYPE}" "rc"  "bash -x ${CLOUD_SHELL_DIR}/aws/codebuild/scripts/trigger_environment_deploy.sh"
# Uncomment the below lines if we want to trigger UAT CD job after successful OR job

if [ "${ARTIFACT_TYPE}" == "or" ] && [ "${AUTO_DEPLOY_UAT}" == "true" ]; then
  export ENVIRONMENT=uat
  bash -x ${CLOUD_SHELL_DIR}/aws/codebuild/scripts/trigger_environment_deploy.sh
fi
