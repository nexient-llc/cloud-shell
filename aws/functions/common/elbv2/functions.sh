#!/usr/bin/env bash

function create_elbv2 {
  local values_file=$1
  local env=$2
  local template=$3
  local sg_id=$4
  local subnet_ids=$5

  local subnet_array=($(echo "${subnet_ids}" | tr ',' "\n"))
  local counter=1
  # exports the environment vars for subnets
  for subnet_id in "${subnet_array[@]}";
  do
    export "AWS_ENV_VARS_SUBNET_ID_${counter}"=${subnet_id}
    counter=$((counter+1))
  done
  export AWS_ENV_VARS_SG_ID="${sg_id}"
  local elbv2_yaml
  elbv2_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  local elbv2_arn
  elbv2_arn=$(aws elbv2 create-load-balancer --cli-input-yaml "${elbv2_yaml}" --output json)
  [ $? -ne 0 ] && exit 1
  elbv2_arn=$(echo "${elbv2_arn}" | jq -r '.LoadBalancers[0].LoadBalancerArn')
  echo ${elbv2_arn}
}

function create_elbv2_target_group {
  local values_file=$1
  local env=$2
  local template=$3
  local vpc_id=$4

  export AWS_ENV_VARS_VPC_ID=${vpc_id}
  local target_group_yaml
  target_group_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  local target_group_arn
  target_group_arn=$(aws elbv2 create-target-group --cli-input-yaml "${target_group_yaml}" --output json)
  [ $? -ne 0 ] && exit 1
  target_group_arn=$(echo "${target_group_arn}" | jq -r '.TargetGroups[0].TargetGroupArn')
  echo "${target_group_arn}"
}

function create_elbv2_listeners {
  local values_file=$1
  local env=$2
  local template=$3
  local elb_arn=$4
  local tg_arn=$5

  export AWS_ENV_VARS_TARGET_GROUP_ARN=${tg_arn}
  export AWS_ENV_VARS_ELBV2_ARN=${elb_arn}
  local listeners_yaml
  listeners_yaml=($(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}" | yq -c '.[]'))
  [ $? -ne 0 ] && exit 1
  local listener_arns
  local listener_yaml
  for listener_yaml in "${listeners_yaml[@]}";
  do
    local listener_arn
    listener_arn=$(aws elbv2 create-listener --cli-input-yaml "${listener_yaml}" --output json)
    [ $? -ne 0 ] && exit 1
    listener_arn=$(echo "${listener_arn}" | jq -r '.Listeners[0].ListenerArn')
    [ -z ${listener_arns} ] && listener_arns=${listener_arn} || listener_arns="${listener_arns},${listener_arn}"
  done
  echo ${listener_arns}
}
