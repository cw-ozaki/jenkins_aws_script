#!/bin/bash
#
# Usage:
#   send_server_list_to_chatwork.sh
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
#   Jenkinsの環境変数
#     JOB_NAME : Jenkinsの環境変数
#
#   Jenkinsの管理 - システムの設定 - グローバルプロパティ - 環境変数 で追加したもの
#     CHATWORK_API_TOKEN : ChatWork通知用のTOKEN
#     CHATWORK_API_SEND_ROOM_ID : ChatWork通知先のroom_id
#
##################################################
set -e 
set -o pipefail
. include/describe_instances.sh
##################################################
# PARAMETER
##################################################
TMP_SERVER_LIST="/tmp/${JOB_NAME}_server_list.txt"
TMP_CHATWORK_MESSAGE="/tmp/${JOB_NAME}_chatwork_message.txt"

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
rm -rf ${TMP_SERVER_LIST}
rm -rf ${TMP_CHATWORK_MESSAGE}

is_first='true'
for stage in ${STAGE_LIST}
do
	count=0
	for instance_json in ${INSTANCES_JSON}
	do
		### 取得対象の判別
		tag_name_exists=`echo -n "${instance_json}" | jq -r --arg stage "_${stage}" 'select(contains({TagName:$stage}))' | wc -l`
		exclude_tag_name_exists=`echo -n "${instance_json}" | jq -r --arg stage "_${EXCLUDE_STAGE}" 'select(contains({TagName:$stage}))' | wc -l`
		state_running_exists=`echo -n "${instance_json}" | jq -r 'select(.State == "running")' | wc -l`
		if [ ${tag_name_exists} -eq 0 -o ${exclude_tag_name_exists} -ne 0 -o ${state_running_exists} -eq 0 ];then
			continue
		fi

		tag_name=`echo ${instance_json} | jq -r '.TagName'`
		public_dns_name=`echo ${instance_json} | jq -r '.PublicDnsName'`
		hr='[hr]'
		if [ "${is_first}" == 'true' ];then
			hr=''
			is_first='false'
		fi
		echo -e "${hr}${tag_name}:\n ${public_dns_name}" >> ${TMP_SERVER_LIST}
		count=`expr ${count} + 1`
	done

	### TagNameにマッチなしの場合は警告出力
	if [ ${count} -eq 0 ];then
		echo "${stage} not matched!!"
		continue
	fi
done

if [ ! -e ${TMP_SERVER_LIST} ];then
	echo "Development Server not exist!"
	exit 0
fi
result_server_list=`cat ${TMP_SERVER_LIST}`

# ChatWork API経由で通知
cat << EOS >> ${TMP_CHATWORK_MESSAGE}
body=[info][title]Development Server list running[/title]${result_server_list}[/info]
EOS
cat ${TMP_CHATWORK_MESSAGE}

### dry-run
if [ "${FLG_D}" == 'TRUE' ];then
	exit 0
fi

curl -X POST \
	-H "X-ChatWorkToken: ${CHATWORK_API_TOKEN}" \
	--data-binary @${TMP_CHATWORK_MESSAGE} \
	"https://api.chatwork.com/v1/rooms/${CHATWORK_API_SEND_ROOM_ID}/messages"

