#!/usr/bin/env bash

# Functions
function delete_files_from_blob_container {
  local storage_account_name=$1
  local container_name=$2

  az storage blob delete-batch \
    --source "${container_name}" \
    --account-name "${storage_account_name}" 
}

function copy_files_to_blob_container {
  local container_name=$1
  local storage_account_name=$2
  local source_file_directory=$3

  az storage blob upload-batch \
    --account-name "${storage_account_name}" \
    --source "${source_file_directory}" \
    -d "${container_name}"
}

function enable_storageaccount_staticsite_feature {
  local storage_account_name=$1

  az storage blob service-properties update \
    --404-document index.html \
    --account-name "${storage_account_name}" \
    --index-document index.html \
    --static-website true
}