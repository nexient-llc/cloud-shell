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
verify_dep 'git' || exit 1
verify_dep 'asdf' || exit 1

[ ! -f ".tool-versions" ] && exit 1 || echo "asdf config file present in the repo"
asdf install
asdf current
verify_dep 'node' || exit 1
verify_dep 'npm' || exit 1
npm install -g --allow-root --unsafe-perm=true npm
asdf reshim
npm -v
node -v
echo ${CODEBUILD_WEBHOOK_HEAD_REF}
echo ${CODEBUILD_WEBHOOK_HEAD_REF} | sed -r 's@^(refs/heads/)(.+)@\2@'
PR_BRANCH=$(echo ${CODEBUILD_WEBHOOK_HEAD_REF} | sed -r 's@^(refs/heads/)(.+)@\2@')
[ -z "${PR_BRANCH}" ] && {
  echo "Unable to get PR branch from Webhook"
} || {
  echo "Pull Request branch is - ${PR_BRANCH}"
}

echo "Main branch is - ${MAIN_BRANCH}"
git config --global hub.protocol https
git config --global user.email $GITHUB_USER_EMAIL
git config --global user.name $GITHUB_USERNAME
echo "git checkout \"origin/${MAIN_BRANCH}\""
git checkout "origin/${MAIN_BRANCH}"
echo "git merge --no-commit --no-ff \"origin/${PR_BRANCH}\""
git merge --no-commit --no-ff "origin/${PR_BRANCH}"
[ $? -ne 0 ] && echo -e "Unable to merge: ${PR_BRANCH} with ${MAIN_BRANCH}. Merge simulation failed!"
npm install
HUSKY_SKIP_INSTALL=1 npm run build && npm run test
