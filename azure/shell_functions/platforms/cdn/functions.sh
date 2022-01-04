#!/usr/bin/env bash

# Functions
function enable_https_on_custom_domain {
  local resource_group=$1
  local cdn_endpoint=$2
  local cdn_profile_name=$3
  local custom_domain_name=$4
  local user_cert_secret_name=$5
  local user_cert_vault_name=$6
  local user_cert_protocol_type=$7
  local min_tls_version=$8

  az cdn custom-domain enable-https \
  -g "${resource_group}" \
  --profile-name "${cdn_profile_name}" \
  --endpoint-name "${cdn_endpoint}" \
  -n "${custom_domain_name}" \
  --user-cert-group-name "${resource_group}" \
  --user-cert-secret-name "${user_cert_secret_name}" \
  --user-cert-vault-name "${user_cert_vault_name}" \
  --user-cert-protocol-type "${user_cert_protocol_type}" \
  --min-tls-version "${min_tls_version}"
}
