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
# Get the PR Branch from the webhook
PR_BRANCH=$(echo ${CODEBUILD_WEBHOOK_HEAD_REF} | sed -r 's@^(refs/heads/)(.+)@\2@')
MAIN_BRANCH=$(echo ${CODEBUILD_WEBHOOK_BASE_REF} | sed -r 's@^(refs/heads/)(.+)@\2@')
echo "Base branch is - ${MAIN_BRANCH}"
[ -z "${PR_BRANCH}" ] && {
  echo "Unable to get PR branch from Webhook"
  exit 1
} || {
  echo "Pull Request branch is - ${PR_BRANCH}"
}
# Feature branch should conform to Naming convention: feature/<name> or patch/<name>
validate_head_branch "${PR_BRANCH}"
# Configure the GIT
git config --global hub.protocol https
git config --global user.email $GITHUB_USER_EMAIL
git config --global user.name $GITHUB_USER_NAME
git remote set-url origin "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${APP_REPO}"
# Simulate merge with Base branch
echo -e "Performing merge simulation with Base Branch"
git checkout "origin/${MAIN_BRANCH}"
git merge --no-commit --no-ff "origin/${PR_BRANCH}" && echo -e "Merge simulation successful" || exit 1
# Run lint and tests
npm install --quiet --no-progress
HUSKY_SKIP_INSTALL=1 npm run lint && npm run test || exit 1
