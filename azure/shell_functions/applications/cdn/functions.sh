#!/usr/bin/env bash

# Functions
function refresh_cached_cdn_files {
  local resource_group=$1
  local cdn_endpoint=$2
  local cdn_profile_name=$3

  az cdn endpoint purge \
  -g "${resource_group}" \
  -n "${cdn_endpoint}" \
  --profile-name "${cdn_profile_name}" \
  --content-paths '/*'
}