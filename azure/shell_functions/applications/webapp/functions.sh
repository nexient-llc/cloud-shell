#!/usr/bin/env bash

function set_webapp_runtime_environment_vars {
  local webapp_rg=$1
  local deployment_slot=$2
  local webapp_name=$3
  local settings_object=$4

  ### settings is received as a json object. here we reformat it into key value pairs
  local settings=$(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' <(echo ${settings_object}))

  echo "setttings object: ${settings}"

  if [ ${deployment_slot} = "production" ]; then 
    az webapp config appsettings set \
      --name ${webapp_name} \
      --resource-group ${webapp_rg} \
      --settings ${settings}
  else
    az webapp config appsettings set \
      --name ${webapp_name} \
      --slot ${deployment_slot} \
      --resource-group ${webapp_rg} \
      --settings ${settings}
  fi
}

function change_webapp_container_settings {
  local webapp_rg=$1
  local deployment_slot=$2
  local webapp_name=$3
  local custom_docker_image=$4
  local docker_registry_server_url=$5
  local docker_registry_server_user=$6
  local docker_registry_server_password=$7

  if [ ${deployment_slot} = "production" ]; then 
    az webapp config container set \
      --name ${webapp_name} \
      --resource-group ${webapp_rg} \
      --docker-custom-image-name ${custom_docker_image} \
      --docker-registry-server-url ${docker_registry_server_url} \
      --docker-registry-server-user ${docker_registry_server_user} \
      --docker-registry-server-password ${docker_registry_server_password}
  else
    az webapp config container set \
      --name ${webapp_name} \
      --resource-group ${webapp_rg} \
      --slot ${deployment_slot} \
      --docker-custom-image-name ${custom_docker_image} \
      --docker-registry-server-url ${docker_registry_server_url} \
      --docker-registry-server-user ${docker_registry_server_user} \
      --docker-registry-server-password ${docker_registry_server_password}
  fi
}