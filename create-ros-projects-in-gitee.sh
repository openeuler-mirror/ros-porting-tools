#!/bin/bash

. base.sh

GITEE_ACCESS_TOKEN=$1
GITEE_HEADER_PREFIX="'Content-Type: application/json;charset=UTF-8'"
HAS_CREATED_LIST=${OUTPUT}/has_created.list

prepare()
{
	if [ "${GITEE_ACCESS_TOKEN}" = "" ]
	then
		error_log "Please give the access token of gitee.com"
		exit 1
	fi

	if [ ! -f ${ROS_PROJECTS_NAME} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	if [ ! -f ${HAS_CREATED_LIST} ]
	then
		touch ${HAS_CREATED_LIST}
	fi
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read project
	do
		grep -q $project $HAS_CREATED_LIST
		if [ $? -eq 0 ]
		then
			info_log "project $project has created, ignore"
			continue
		fi

		info_log "start create project $project"
		echo curl -s -X POST --header ${GITEE_HEADER_PREFIX} \'https://gitee.com/api/v5/user/repos\' -d \
			\''{"access_token":"'${GITEE_ACCESS_TOKEN}'","name":"'${project}'","description":"'${project}'","has_issues":"true","has_wiki":"true","can_comment":"true","auto_init":"true","private":"true"}'\' >${OUTPUT}/.post
		bash ${OUTPUT}/.post 1>/dev/null 2>&1
		if [ $? -ne 0 ]
		then
			error_log "fail to create project $project"
			exit 1
		fi

		echo curl -s -X PATCH --header ${GITEE_HEADER_PREFIX} \'https://gitee.com/api/v5/repos/${GITEE_ORG}/${project}\' -d \
		       	\''{"access_token":"'${GITEE_ACCESS_TOKEN}'","name":"'${project}'","has_issues":"true","has_wiki":"true","can_comment":"true","private":"false"}'\' >${OUTPUT}/.post
		bash ${OUTPUT}/.post 1>/dev/null 2>&1
		if [ $? -ne 0 ]
		then
			error_log "fail to setting project $project"
			exit 1
		fi
		echo $project >>${HAS_CREATED_LIST}
	done < ${ROS_PROJECTS_NAME}

	info_log "create project ok"
}

main $*
