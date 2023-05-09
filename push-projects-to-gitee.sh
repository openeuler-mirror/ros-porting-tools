#!/bin/bash

. base.sh

PUSH=$1
ROS_PUSH_LIST=${OUTPUT}/ros-push.list

prepare()
{
	if [ ! -f ${ROS_PROJECTS_NAME} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	mkdir -p ${ROS_GITEE_BASE}

	rm -f ${ROS_PUSH_LIST}
}

main()
{
	prepare

	info_log "Start to push projects to $GITEE_DOMAIN/$GITEE_ORG"

	while read project
	do
		#info_log "start push project ${project}"
		
		if [ ! -d ${ROS_GITEE_BASE}/${project}/.git ]
		then
			error_log "project ${project} not exist, ignore"
			continue
		fi

		cd ${ROS_GITEE_BASE}/${project}
		rm -f *
		git checkout -- README.md README.en.md
		cp ${ROS_REPO_BASE}/${project}/* ${ROS_GITEE_BASE}/${project}
		git status | grep -qE "modified:|Untracked|deleted:"
		if [ $? -ne 0 ]
		then
			#info_log "nothing changed of project $project, continue"
			continue
		fi

		echo $project >>${ROS_PUSH_LIST}

		info_log "start push project ${project}"
		git add -A 
		if [ "$PUSH" != "yes" ]
		then
			git diff HEAD --exit-code
			continue
		fi

		git commit -m "upload on `date`"
		#git push git@${GITEE_DOMAIN}:${GITEE_ORG}/${project}.git
		git push origin ${ROS_DISTRO}:${ROS_DISTRO}
		if [ $? -ne 0 ]
		then
			error_log "fail to push project ${project}"
			continue
		fi
	done < ${ROS_PROJECTS_NAME}

	info_log "push project ok"
}

main $*
