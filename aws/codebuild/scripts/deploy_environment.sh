#!/usr/bin/env bash

SRC_DIR=$1
E2E_TEST=$2
ENVIRONMENT=$3

source ${CLOUD_SHELL_DIR}/aws/functions/functions.sh || exit 1

deploy_environment $SRC_DIR $E2E_TEST $ENVIRONMENT

