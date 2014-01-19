#!/bin/bash
#
# Usage:
#   stop_instances.sh -s
#
# Description:
#   -s stsを利用して、AWSの環境変数を設定する
#
#   利用している環境変数
#     AWS_DEFAULT_REGION : aws-cli
#     AWS_ACCESS_KEY_ID : aws-cli
#     AWS_SECRET_ACCESS_KEY : aws-cli
#
#     DRY_RUN : dryrunモードで実行する
#     STAGE_LIST : 対象のTagNameパターンを指定、改行で複数指定可能
#     EXCLUDE_STAGE : 除外したいTagNameパターンを指定
#
##################################################
set -e 
set -o pipefail
. include/describe_instances.sh
##################################################
# PARAMETER
##################################################
FLG_S='FALSE'
while getopts 's' OPT
do
	case $OPT in
		's' )
		FLG_S='TRUE'
		;;
	esac
done
shift $(($OPTIND - 1))

### dry-run
FLG_D='FALSE'
if [ "${DRY_RUN}" == 'true' ];then
	FLG_D='TRUE'
fi

### sts
if [ "${FLG_S}" == 'TRUE' ];then
	. set_sts_credential.sh
fi

INSTANCES_JSON=`instances_json`

##################################################
# MAIN
##################################################
for stage in ${STAGE_LIST}
do
	instance_ids=''
	for instance_json in ${INSTANCES_JSON}
	do
		### 実行対象instance_idの判別
		tag_name_exists=`echo -n "${instance_json}" | jq -r --arg stage "_${stage}" 'select(contains({TagName:$stage}))' | wc -l`
		exclude_tag_name_exists=`echo -n "${instance_json}" | jq -r --arg stage "_${EXCLUDE_STAGE}" 'select(contains({TagName:$stage}))' | wc -l`
		state_running_exists=`echo -n "${instance_json}" | jq -r 'select(.State == "running")' | wc -l`
		if [ ${tag_name_exists} -eq 0 -o ${exclude_tag_name_exists} -ne 0 -o ${state_running_exists} -eq 0 ];then
			continue
		fi

		echo "add: ${instance_json}"
		instance_id=`echo "${instance_json}" | jq -r '.InstanceId'`
		instance_ids=`echo "${instance_ids} ${instance_id}"`
	done

	### TagNameにマッチなしの場合は警告出力
	if [ "${instance_ids}" == '' ];then
		echo "${stage} not matched!!"
		continue
	fi

	echo "aws ec2 stop-instances --instance-ids ${instance_ids}"
	### dry-run
	if [ "${FLG_D}" == 'TRUE' ];then
		continue
	fi
	aws ec2 stop-instances --instance-ids ${instance_ids}
done

