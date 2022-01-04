#!/usr/bin/env bash

# Functions
function deploy_arm_template {
  local resource_group=$1
  local name=$2
  local template=$3
  local template_params=$4

  ### this initiates a deployment called <app name>-<current date>
  az deployment group create \
    --resource-group "${resource_group}" \
    --name "${name}-$(date +%Y-%m-%d-%s)" \
    --template-file "${template}" \
    --parameters "${template_params}"
}
