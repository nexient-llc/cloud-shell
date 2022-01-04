#!/usr/bin/env bash

# Functions
function get_apim_resource_id {
  local azure_rest_domain_name=$1
  local azure_subscription_id=$2
  local apim_instance_rg=$3
  local apim_instance_name=$4

  ### Builds the resource identifier of the APIM
  local apim_resource_id="https://${azure_rest_domain_name}/"
  apim_resource_id+="subscriptions/${azure_subscription_id}/"
  apim_resource_id+="resourceGroups/${apim_instance_rg}/"
  apim_resource_id+="providers/Microsoft.ApiManagement/"
  apim_resource_id+="service/${apim_instance_name}"

  echo ${apim_resource_id}
}

function create_apim_product {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_product_name=$3

  ### Create a product, a logical grouping of APIs
  az apim product create \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --product-name "${apim_product_name}" \
    --state "published"
}

function list_apim_products {
  local apim_instance_rg=$1
  local apim_instance_name=$2

  ### Lists products within an APIM instance
  az apim product list \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}"
}

function get_apim_product_id {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_product_name=$3

  local product_list=$(list_apim_products ${apim_instance_rg} ${apim_instance_name})

  ### Gets the cryptic ID of the APIM product from the display name of the APIM product
  echo ${product_list} | jq -r --arg name ${apim_product_name} '.[] | select(.displayName == $name).name | first(.)'
}

function add_api_to_apim_product {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_product_name=$3
  local apim_api_name=$4

  local apim_product_id=$(get_apim_product_id ${apim_instance_rg} ${apim_instance_name} ${apim_product_name})

  ## Associates the API with the Product
  az apim product api add \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --product-id "${apim_product_id}" \
    --api-id "${apim_api_name}"
}

function update_apim_api_policy {
  local azure_rest_domain_name=$1
  local azure_rest_version=$2
  local azure_subscription_id=$3
  local apim_instance_rg=$4
  local apim_instance_name=$5
  local apim_api_name=$6
  local apim_api_policy=$7
  local apim_api_version=$8
  local apim_api_operation=$9


  ### Retrieve the resource identifier of the APIM
  local apim_resource_id=$( \
    get_apim_resource_id \
      "${azure_rest_domain_name}" \
      "${azure_subscription_id}" \
      "${apim_instance_rg}" \
      "${apim_instance_name}" \
  )

  ### Builds the endpoint of the API policy
  local apim_api_policy_endpoint=${apim_resource_id}
  apim_api_policy_endpoint+="/apis/${apim_api_name}"
  if [ ! -z "${apim_api_version}" ]; then
    apim_api_policy_endpoint+=";rev=${apim_api_version}"
  fi
  if [ ! -z "${apim_api_operation}" ]; then
    apim_api_policy_endpoint+="/operations/${apim_api_operation}"
  fi
  apim_api_policy_endpoint+="/policies/policy"
  apim_api_policy_endpoint+="?api-version=${azure_rest_version}"

  ### Puts the XML policy into a JSON request body, escaping quotations
  local request_body="{\"properties\":{\"format\":\"rawxml\","
  request_body+="\"value\":\"$(cat "${apim_api_policy}" | sed 's:\\:\\\\:g' | sed 's:":\\\":g')\"}}"

  echo "Attempting to update resource at: ${apim_api_policy_endpoint}"

  ### `az` has no specific command for updating an APIM policy,
  ### so here we use an Azure REST API call to do the update.
  ### `curl` could have also been used to make this call,
  ### but `az rest` automatically adds an auth header for us.
  az rest --method put --url ${apim_api_policy_endpoint} --body "$(echo "${request_body}")" && {
    echo "Resource updated successfully!"
  }
}

function update_apim_api_description {
    local apim_instance_rg=$1
    local apim_instance_name=$2
    local apim_api_name=$3
    local openapi_definition=$4

    local description
    if [[ "${openapi_definition}" == *".yaml"* ]] || [[ "${openapi_definition}" == *".yml"* ]]; then
      description=$(yq eval -j "${openapi_definition}" | jq -r '.info.description')
    else
      description=$(cat "${openapi_definition}" | jq -r '.info.description')
    fi

    az apim api update \
      --resource-group "${apim_instance_rg}" \
      --service-name "${apim_instance_name}" \
      --api-id "${apim_api_name}" \
      --description "${description}"
}

function update_apim_api_spec {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_api_path=$3
  local apim_api_name=$4
  local openapi_definition=$5
  local apim_api_version=$6

  ### modifies the display name of the API to be the same as the unique, environment-specific name
  ### this allows for multiple environments with similar/identical API definitions to run in the same APIM
  ### otherwise, Azure will throw an error due to identical display names for the two environments
  local openapi_definition_modified
  if [[ "${openapi_definition}" == *".yaml"* ]] || [[ "${openapi_definition}" == *".yml"* ]]; then
    echo "Converting definition from YAML to JSON..."
    openapi_definition_modified=$(yq eval -j "${openapi_definition}" | jq --arg name "${apim_api_name}" '.info.title = $name')
  else
    openapi_definition_modified=$(cat "${openapi_definition}" | jq --arg name "${apim_api_name}" '.info.title = $name')
  fi

  ### the APIM API is updated from the OpenAPI spec
  ### this is how APIM is notified about changes to paths/routes
  echo "Importing definition..."
  az apim api import \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --path "${apim_api_path}" \
    --specification-path <(echo "$openapi_definition_modified") \
    --specification-format OpenApi \
    --api-revision "${apim_api_version}" \
    --api-id "${apim_api_name}" \
    --verbose
}

function create_apim_api {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_api_path=$3
  local apim_api_name=$4
  local is_subscription_required=$5

  ### creates an API in the specified APIM
  az apim api create \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --path "${apim_api_path}" \
    --api-id "${apim_api_name}" \
    --display-name "${apim_api_name}" \
    --subscription-required "${is_subscription_required}"
}

function create_apim_api_revision {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_api_name=$3
  local apim_api_version=$4

  az apim api revision create \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --api-id "${apim_api_name}" \
    --api-revision "${apim_api_version}"
}

function create_apim_api_release {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_api_name=$3
  local apim_api_version=$4

  az apim api release create \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --api-id "${apim_api_name}" \
    --api-revision "${apim_api_version}"
}

function create_apim_nv {
  local apim_instance_rg=$1
  local apim_instance_name=$2
  local apim_nv_name=$3
  local apim_nv_value=$4
  local is_secret=$5

  ### creates a named value globally accessible within the APIM
  ### useful for storing values needed by the APIM policy
  az apim nv create \
    --resource-group "${apim_instance_rg}" \
    --service-name "${apim_instance_name}" \
    --display-name "${apim_nv_name}" \
    --named-value-id "${apim_nv_name} " \
    --value "${apim_nv_value}" \
    --secret "${is_secret}"
}

function update_apim_api_default_backend {
  local apim_rg=$1
  local apim_name=$2
  local apim_api_name=$3
  local backend_url=$4
  local apim_api_version=$5

  local apim_api_name_with_rev="${apim_api_name}"

  if [ ! -z "${apim_api_version}" ]; then
    apim_api_name_with_rev+=";rev=${apim_api_version}"
  fi

  az apim api update \
    --resource-group "${apim_rg}" \
    --service-name "${apim_name}" \
    --api-id "${apim_api_name_with_rev}" \
    --service-url "${backend_url}"
}

function update_apim_backend {
  local azure_rest_domain_name=$1
  local azure_rest_version=$2
  local azure_subscription_id=$3
  local apim_instance_rg=$4
  local apim_instance_name=$5
  local backend_id=$6
  local backend_protocol=$7
  local backend_url=$8
  local func_resource_id=$9

  ### Retrieve the resource identifier of the APIM
  local apim_resource_id=$( \
    get_apim_resource_id \
      "${azure_rest_domain_name}" \
      "${azure_subscription_id}" \
      "${apim_instance_rg}" \
      "${apim_instance_name}" \
  )
  ### Builds the endpoint of the backend
  local apim_backend_endpoint=${apim_resource_id}
  apim_backend_endpoint+="/backends/${backend_id}"
  apim_backend_endpoint+="?api-version=${azure_rest_version}"

  ### Builds the endpoint of the function app
  local funcapp_endpoint="https://${azure_rest_domain_name}${func_resource_id}"

  local request_body="{\"properties\":{\"url\":\"${backend_url}\",\"protocol\":\"${backend_protocol}\",\"resourceId\":\"${funcapp_endpoint}\"}}"

  echo "Attempting to update resource at: ${apim_backend_endpoint}"

  ### `az` has no specific command for updating an APIM policy,
  ### so here we use an Azure REST API call to do the update.
  ### `curl` could have also been used to make this call,
  ### but `az rest` automatically adds an auth header for us.
  az rest --method put --url ${apim_backend_endpoint} --body "${request_body}" && {
    echo "Resource updated successfully!"
  }
}
