#!/usr/bin/env bash

# Function to create a new VPC
function create_vpc {
  local values_file=$1
  local env=$2
  local template=$3

  local vpc_yaml
  vpc_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  aws ec2 create-vpc --cli-input-yaml "${vpc_yaml}"  --output json | jq -r '.Vpc.VpcId' || exit 1

}
# Function to create subnets for a given VPC
function create_subnets {
  local values_file=$1
  local env=$2
  local template=$3
  local vpc_id=$4

  export AWS_ENV_VARS_VPC_ID=$vpc_id
  local subnets_yaml
  subnets_yaml=($(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}" | yq -c '.[]'))
  [ $? -ne 0 ] && exit 1
  local subnet_ids
  local subnet_yaml
  for subnet_yaml in "${subnets_yaml[@]}";
  do
    subnet_id=$(aws ec2 create-subnet --cli-input-yaml "${subnet_yaml}" --output json)
    [ $? -ne 0 ] && exit 1
    subnet_id=$(echo ${subnet_id} | jq -r '.Subnet.SubnetId')
    [ -z ${subnet_ids} ] && subnet_ids=${subnet_id} || subnet_ids="${subnet_ids},${subnet_id}"
  done
  echo ${subnet_ids}
}

# This function configures the VPC
# - Creates Internet Gateway
# - Attaches Internet Gateway to VPC
# - Creates a new route from the internet to the Internet Gateway
# - Attaches the subnets to the route table
# - Modify the subnets to map public IP addresses on Instance launch
function configure_vpc {
  local env=$1
  local vpc_id=$2
  local subnet_ids=$3

  local igw_id
  local route_table_id
  # Create an internet gateway
  igw_id=$(aws ec2 create-internet-gateway --output json)
  [ $? -ne 0 ] && exit 1
  igw_id=$(echo ${igw_id} | jq -r '.InternetGateway.InternetGatewayId')
  # Attach the internet gateway with VPC
  aws ec2 attach-internet-gateway --vpc-id ${vpc_id} --internet-gateway-id ${igw_id} > /dev/null || exit 1
  # Get the route_table_id of the default route-table attached to the VPC
  route_table_id=$(aws ec2 describe-route-tables --output json)
  [ $? -ne 0 ] && exit 1
  route_table_id=$(echo ${route_table_id} | jq -r ".RouteTables[] | select(.VpcId == \"${vpc_id}\") | .RouteTableId")
  # Create a new route to allow traffic from everywhere to the internet-gateway
  aws ec2 create-route --destination-cidr-block '0.0.0.0/0' --gateway-id ${igw_id} --route-table-id ${route_table_id} > /dev/null || exit 1
  # Attach subnets to the route table
  local subnet_array=($(echo "${subnet_ids}" | tr ',' "\n"))
  for subnet_id in "${subnet_array[@]}";
  do
    aws ec2 associate-route-table --subnet-id ${subnet_id} --route-table-id ${route_table_id} > /dev/null || exit 1
  done
  # Modify subnets to allow automatic public ip assignment
  for subnet_id in "${subnet_array[@]}";
  do
    aws ec2 modify-subnet-attribute --subnet-id ${subnet_id} --map-public-ip-on-launch > /dev/null
  done
}

# Function to create a new Security Group and attach routing rules
function create_security_group {
  local values_file=$1
  local env=$2
  local template=$3
  local vpc_id=$4

  local security_group_yaml
  local sg_id
  export AWS_ENV_VARS_VPC_ID=${vpc_id}
  security_group_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  sg_id=$(aws ec2 create-security-group --cli-input-yaml "${security_group_yaml}" --output json | jq -r ".GroupId")
  [ $? -ne 0 ] && exit 1
  echo ${sg_id}
}

# Function to call new ingress rules for Security Group. This function is invoked from create_security_group function
function create_security_group_ingress {
  local values_file=$1
  local env=$2
  local template=$3
  local sg_id=$4

  local security_group_ingress_yaml
  export AWS_ENV_VARS_SG_ID="${sg_id}"
  security_group_ingress_yaml=$(ah jinja render -f "${values_file}" --environment-type ${env} -t "${template}")
  [ $? -ne 0 ] && exit 1
  aws ec2 authorize-security-group-ingress --cli-input-yaml "${security_group_ingress_yaml}" --output text > /dev/null || exit 1
}
