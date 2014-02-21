#!/bin/bash
#
# Usage:
#   . describe_instances.sh
#
##################################################

##################################################
# FUNCTION
##################################################
instances_json() {
	aws ec2 describe-instances \
		| jq -c -M '.Reservations[].Instances[] | {State:.State.Name, TagName:.Tags[] | select(.Key == "Name") | .Value, InstanceId:.InstanceId, PublicDnsName:.PublicDnsName}'
}
