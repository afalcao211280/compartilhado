#!/usr/bin/env bash

AWS_PROFILE="${AWS_PROFILE:-default}"

alias al='aws --output table --profile $AWS_PROFILE'
alias ai='aws ec2 describe-instances --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,IP:PrivateIpAddress}" --output table --profile $AWS_PROFILE'
alias av='aws ec2 describe-volumes --query "Volumes[].{ID:VolumeId,Size:Size,State:State,Type:VolumeType}" --output table --profile $AWS_PROFILE'
alias as3l='aws s3 ls --profile $AWS_PROFILE'
alias alog='aws logs tail --profile $AWS_PROFILE'
alias acfnl='aws cloudformation list-stacks --query "StackSummaries[].{Name:StackName,Status:StackStatus}" --output table --profile $AWS_PROFILE'
alias aeip='aws ec2 describe-addresses --query "Addresses[].{IP:PublicIp,Instance:InstanceId,Allocation:AllocationId}" --output table --profile $AWS_PROFILE'

as3up() {
  aws s3 sync "${1:-.}" "s3://${2}" --profile "$AWS_PROFILE"
}

assh() {
  local instance_id="$1"
  aws ssm start-session --target "$instance_id" --profile "$AWS_PROFILE"
}