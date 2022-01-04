#!/usr/bin/env bash

# Functions
function list_function_keys {
  local func_rg=$1
  local func_name=$2

  ### requests to function apps must have a valid `x-functions-key` header
  ### this command lists the valid keys associated with a function app
  az functionapp keys list \
    --resource-group "${func_rg}" \
    --name "${func_name}"
}

function get_default_func_key {
  local func_rg=$1
  local func_name=$2

  ### by default function apps have two keys: `_master` and `default`
  ### `default` is sufficient for sending requests to the function app
  list_function_keys ${func_rg} ${func_name} |
    jq -r ".functionKeys.default"
}

function get_default_func_url {
  local func_rg=$1
  local func_name=$2

  ### this displays the default URL associated with the function app
  az functionapp show --name ${func_name} --resource-group ${func_rg} |
    jq -r ".defaultHostName"
}

function get_func_resource_id {
  local func_rg=$1
  local func_name=$2

  ### this displays the default URL associated with the function app
  az functionapp show --name ${func_name} --resource-group ${func_rg} |
    jq -r ".id"
}

function set_function_runtime_environment_vars {
  local func_rg=$1
  local func_name=$2
  local deployment_slot=$3
  local settings_object=$4

  ### settings is received as a json object. here we reformat it into key value pairs
  local settings=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' <(echo ${settings_object}))

  echo "Target slot: ${deployment_slot}"

  if [ ${deployment_slot} = "production" ]; then 
    az functionapp config appsettings set \
      --name ${func_name} \
      --resource-group ${func_rg} \
      --settings ${settings}
  else
    az functionapp config appsettings set \
      --name ${func_name} \
      --slot ${deployment_slot} \
      --resource-group ${func_rg} \
      --settings ${settings}
  fi
}
