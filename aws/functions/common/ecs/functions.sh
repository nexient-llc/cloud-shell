#!/usr/bin/env bash

function create_fargate_cluster {
  local values_file=$1
  local env=$2
  local template=$3

  local fargate_cluster_yaml
  local fargate_cluster_arn
  fargate_cluster_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  fargate_cluster_arn=$(aws ecs create-cluster --cli-input-yaml "${fargate_cluster_yaml}" --output json)
  [ $? -ne 0 ] && exit 1
  fargate_cluster_arn=$(echo "${fargate_cluster_arn}" | jq -r '.cluster.clusterArn')
  echo ${fargate_cluster_arn}
}
