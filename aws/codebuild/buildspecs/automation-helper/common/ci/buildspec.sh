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
# download python
verify_dep 'python' || exit 1
asdf reshim
python --version
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

echo "Installing Module"
python setup.py install
asdf reshim 
echo "Pylint: "
pylint * 
echo "Pytest: "
python -m pytest --junitxml="${TEST_COVERAGE_PATH}"

echo "Coverage: "
python -m coverage run "${CODE_COVERAGE_FUNCTION}"
python -m coverage xml  -o "${CODE_COVERAGE_PATH}"