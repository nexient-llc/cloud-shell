#!/usr/bin/env bash

# Functions
function enable_https_on_custom_domain {
  local resource_group=$1
  local frontDoor_name=$2
  local frontendEndpoint_name=$3
  local certificate_source=$4
  local minTls_version=$5
  local secret_name=$6
  local vault_id=$7

  #set this to install front door extension
  az config set extension.use_dynamic_install=yes_without_prompt

  az network front-door frontend-endpoint enable-https \
    --front-door-name "${frontDoor_name}" \
    --name "${frontendEndpoint_name}" \
    --resource-group "${resource_group}" \
    --certificate-source "${certificate_source}" \
    --minimum-tls-version "${minTls_version}" \
    --secret-name "${secret_name}" \
    --vault-id "${vault_id}" 
}
