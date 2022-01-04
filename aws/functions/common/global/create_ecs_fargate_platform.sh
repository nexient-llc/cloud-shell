#!/usr/bin/env bash

# source all the local functions
source "${CLOUD_SHELL_ROOT_DIR}/aws/functions/common/ec2/functions.sh"
source "${CLOUD_SHELL_ROOT_DIR}/aws/functions/common/ecs/functions.sh"
source "${CLOUD_SHELL_ROOT_DIR}/aws/functions/common/elbv2/functions.sh"
source "${CLOUD_SHELL_ROOT_DIR}/aws/functions/common/route53/functions.sh"

# Function to create the fargate infrastructure
function create_ecs_fargate_platform {
  echo -e "Installing Fargate Frontend Infrastructure Pipeline"
  VPC_ID=$(create_vpc "${VALUES_FILE}" ${ENVIRONMENT} "${EC2_TEMPLATES_DIR}/vpc.yaml.jinja2")
  [ $? -eq 0 ] && echo -e "VPC with id: ${VPC_ID} created successfully" || exit 1
  SUBNET_IDS=$(create_subnets "${VALUES_FILE}" ${ENVIRONMENT} "${EC2_TEMPLATES_DIR}/subnets.yaml.jinja2" ${VPC_ID})
  [ $? -eq 0 ] && echo -e "Subnet with id: ${SUBNET_IDS} created successfully" || exit 1
  configure_vpc ${ENVIRONMENT}  ${VPC_ID} ${SUBNET_IDS}
  [ $? -eq 0 ] && echo -e "VPC configured successfully" || exit 1
  SECURITY_GROUP_ID=$(create_security_group "${VALUES_FILE}" ${ENVIRONMENT} "${EC2_TEMPLATES_DIR}/security_group.yaml.jinja2" ${VPC_ID})
  [ $? -eq 0 ] && echo -e "Security Group: ${SECURITY_GROUP_ID} created successfully" || exit 1
  create_security_group_ingress "${VALUES_FILE}" ${ENVIRONMENT} "${EC2_TEMPLATES_DIR}/security_group_ingress.yaml.jinja2" ${SECURITY_GROUP_ID}
  [ $? -eq 0 ] && echo -e "Security Group Ingress configured successfully" || exit 1
  ELBV2_ARN=$(create_elbv2 "${VALUES_FILE}" ${ENVIRONMENT} "${ELBV2_TEMPLATES_DIR}/elbv2.yaml.jinja2"  ${SECURITY_GROUP_ID} ${SUBNET_IDS})
  [ $? -eq 0 ] && echo -e "ALB with ARN: ${ELBV2_ARN} created successfully" || exit 1
  ELBV2_TG_ARN=$(create_elbv2_target_group "${VALUES_FILE}" ${ENVIRONMENT} "${ELBV2_TEMPLATES_DIR}/elbv2_target_group.yaml.jinja2" ${VPC_ID})
  [ $? -eq 0 ] && echo -e "ELB target group with ARN: ${ELBV2_TG_ARN} created successfully" || exit 1
  ELBV2_LISTENER_ARNS=$(create_elbv2_listeners "${VALUES_FILE}" ${ENVIRONMENT} "${ELBV2_TEMPLATES_DIR}/elbv2_listeners.yaml.jinja2" ${ELBV2_ARN} ${ELBV2_TG_ARN})
  [ $? -eq 0 ] && echo -e "ELB Listeners group with ARNs: ${ELBV2_TG_ARN} created successfully" || exit 1
  FARGATE_CLUSTER_ARN=$(create_fargate_cluster "${VALUES_FILE}" ${ENVIRONMENT} "${ECS_TEMPLATES_DIR}/ecs_fargate_cluster.yaml.jinja2")
  [ $? -eq 0 ] && echo -e "Fargate Cluster with ARN: ${FARGATE_CLUSTER_ARN} created successfully" || exit 1
  map_dns_to_elbv2 "${VALUES_FILE}" ${ENVIRONMENT} "${ROUTE53_TEMPLATES_DIR}/route53_elbv2_mapping.yaml.jinja2" ${ELBV2_ARN}
  [ $? -eq 0 ] && echo -e "ELB mapped to the domain name successfully" || exit 1

  echo -e "Installation of Fargate Frontend Infrastructure Pipeline successful."
}
