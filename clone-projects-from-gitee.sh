#!/bin/bash

. base.sh

GITEE_URL=git@${GITEE_DOAMIN}
GITEE_BASE=${OUTPUT}/gitee
CLONE_BRANCH=humble

prepare()
{
	if [ ! -f ${ROS_PROJECTS_NAME} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	mkdir -p ${GITEE_BASE}
}

main()
{
	prepare

	info_log "Start to clone projects from $GITEE_URL"

	while read project
	do
		info_log "start clone project ${project}"
		
		if [ -d ${GITEE_BASE}/${project}/.git ]
		then
			cd ${GITEE_BASE}/${project}
			git pull origin ${CLONE_BRANCH}
			continue
		fi

		cd ${GITEE_BASE}
		git clone https://${GITEE_DOMAIN}/${GITEE_ORG}/${project}.git
		if [ $? -ne 0 ]
		then
			error_log "fail to clone project ${project}"
			continue
		fi
		cd ${project}
		git branch -a | grep ${CLONE_BRANCH}
		if [ $? -eq 0 ]
		then
			git checkout ${CLONE_BRANCH}
		else
			git checkout -b ${CLONE_BRANCH}
		fi

	done < ${ROS_PROJECTS_NAME}

	info_log "clone project ok"
}

main $*
