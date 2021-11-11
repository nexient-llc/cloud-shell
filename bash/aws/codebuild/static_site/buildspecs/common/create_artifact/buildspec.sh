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
SYSTEM_DEPS+=" gawk"
SYSTEM_DEPS+=" git"
SYSTEM_DEPS+=" gnupg2"
SYSTEM_DEPS+=" groff"
SYSTEM_DEPS+=" jq"
SYSTEM_DEPS+=" python3"
SYSTEM_DEPS+=" python3-pip"
SYSTEM_DEPS+=" python3-setuptools"
SYSTEM_DEPS+=" wget"
SYSTEM_DEPS+=" unzip"
SYSTEM_DEPS+=" zip"

ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
DEBIAN_FRONTEND=noninteractive apt-get -y update && apt-get install -y --no-install-recommends ${SYSTEM_DEPS}
PYTHON_DEPS="awscli"
pip3 install ${PYTHON_DEPS}
verify_dependencies
# Assign the version for RC job
[ "${ARTIFACT_TYPE}" == "rc" ] && VERSION="$(date +%Y-%m-%d-%s)"
[ "${VERSION}" == "notset" ] && exit 1
[ "${ARTIFACT_TYPE}" == "notset" ] && exit 1 || echo "Version is set to - ${VERSION}"
echo "Building ${ARTIFACT_TYPE} Artifact from git tag version - ${VERSION}"
git config --global hub.protocol https
git config --global user.email ${GITHUB_USER_EMAIL}
git config --global user.name ${GITHUB_USER_NAME}
git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}"
BASE_BRANCH=$(echo ${CODEBUILD_WEBHOOK_BASE_REF} | sed -r 's@^(refs/heads/)(.+)@\2@')
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "git checkout ${BASE_BRANCH}"
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "git tag ${VERSION}"
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "git push origin ${VERSION}"
run_command_if "false" "${ARTIFACT_TYPE}" "or" "git fetch --tags"
run_command_if "false" "${ARTIFACT_TYPE}" "or" "git checkout refs/tags/${VERSION}"
npm install

if ! [ -z "${NPM_BUILD_ARG}" ]; then
  HUSKY_SKIP_INSTALL=1 npm run "${NPM_BUILD_ARG}" || exit 1
else
  HUSKY_SKIP_INSTALL=1 npm run build:static || exit 1
fi

# Extract the artifact zip
cd ${ARTIFACT_DIRECTORY} || exit 1
zip -r ../artifact.zip *
cd ..
# Set the bucket name
[ "${ARTIFACT_TYPE}" == "rc" ] && export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_RC_BUCKET_NAME}
[ "${ARTIFACT_TYPE}" == "or" ] && export ARTIFACT_S3_BUCKET_NAME=${ARTIFACT_S3_OR_BUCKET_NAME}
# Copy the artifacts to S3
aws s3api put-object --bucket ${ARTIFACT_S3_BUCKET_NAME} --key ${APPLICATION_NAME}-${ARTIFACT_TYPE}-${VERSION}/
aws s3 cp ./artifact.zip s3://${ARTIFACT_S3_BUCKET_NAME}/${APPLICATION_NAME}-${ARTIFACT_TYPE}-${VERSION}/
# Need to set the environment=uat to trigger the uat CD job
run_command_if "false" "${ARTIFACT_TYPE}" "or" "export ENVIRONMENT=uat"
# Trigger the CD Job
run_command_if "false" "${ARTIFACT_TYPE}" "rc" "bash -x ${AUTOMATION_HELPER_DIR}/bash/aws/codebuild/static_site/scripts/trigger_environment_deploy.sh"
run_command_if "false" "${ARTIFACT_TYPE}" "or" "bash -x ${AUTOMATION_HELPER_DIR}/bash/aws/codebuild/static_site/scripts/trigger_environment_deploy.sh"
