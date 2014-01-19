#!/bin/bash
#
# Usage:
#   set_sts_credential.sh
#
# Description:
#   利用している環境変数
#     ROLE_ARN : IAM Role for Cross-Account Access
#
##################################################
set -e 
set -o pipefail
##################################################
# PARAMETER
##################################################
DURATION_SECONDS=900

##################################################
# MAIN
##################################################
# stsを使って、一時tokenを取得
date_time=`date '+%Y%m%d%H%M%S'`
pid=$$
credentials=`aws sts assume-role \
	--output json \
	--role-arn "${ROLE_ARN}" \
	--role-session-name "${date_time}_pid" \
	--duration-seconds ${DURATION_SECONDS}`

# stsの取得結果を環境変数にセット
export AWS_ACCESS_KEY_ID=`echo "${credentials}" | jq -r '.Credentials.AccessKeyId'`
export AWS_SECRET_ACCESS_KEY=`echo "${credentials}" | jq -r '.Credentials.SecretAccessKey'`
export AWS_SECURITY_TOKEN=`echo "${credentials}" | jq -r '.Credentials.SessionToken'`

