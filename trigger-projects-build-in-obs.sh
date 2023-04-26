#!/bin/bash

. base.sh

ROS_PUSH_LIST=${OUTPUT}/ros-push.list

prepare()
{
	if [ ! -f ${ROS_PUSH_LIST} ]
	then
		error_log "Please give the ${ROS_CHECK_LIST}"
		exit 1
	fi
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read project
	do
		info_log "start rerun $project"
		osc service remoterun ${OBS_PROJECT} $project
	done < ${ROS_PUSH_LIST}

	info_log "get status of projects ok"
}

main $*
