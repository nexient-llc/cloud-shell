#!/usr/bin/env bash

function map_dns_to_elbv2 {
  local values_file=$1
  local env=$2
  local template=$3
  local elbv2_arn=$4

  local elbv2_dns
  elbv2_dns=$(aws elbv2 describe-load-balancers --output json)
  [ $? -ne 0 ] && exit 1
  elbv2_dns=$(echo "${elbv2_dns}" | jq -r ".LoadBalancers[] | select(.LoadBalancerArn == \"${elbv2_arn}\") | .DNSName")
  export AWS_ENV_VARS_LOAD_BALANCER_DNS=${elbv2_dns}
  local route53_mapping_yaml
  route53_mapping_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  aws route53 change-resource-record-sets --cli-input-yaml "${route53_mapping_yaml}" > /dev/null || exit 1
}
