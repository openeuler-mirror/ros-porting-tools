#!/bin/bash

. base.sh

USER_INFO="$1"
ROS_CHECK_LIST=${ROOT}/ros-check.list
ROS_BUILD_STATUS=${OUTPUT}/ros-build-status.list

prepare()
{
	if [ ! -f ${ROS_PKG_LIST} ]
	then
		error_log "Can not find ${ROS_PKG_LIST}, you can use get-repo-list.sh to create it"
		exit 1
	fi

	if [ ! -f ${ROS_CHECK_LIST} ]
	then
		error_log "Please give the ${ROS_CHECK_LIST}"
		exit 1
	fi

	if [ "$USER_INFO" == "" ]
	then
		error_log "please give user info, like:"
		error_log "$0 user:pass"
		exit 1
	fi

	>${ROS_BUILD_STATUS}
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."
	cd ${ROS_OUTPUT_TMP}
	rm -f src
	wget http://119.3.219.20:82/openEuler:/ROS:/humble/standard_x86_64/src
	grep "\.src.rpm" src | awk -F"href=\"" '{print $2}' | cut -d'"' -f1 | sed -e "s/\-[[:digit:]]\+\..*//g" >.build_succeeded

	while read project
	do
		info_log "start check project $project"
		p=`grep -P "^$project\t" ${ROS_PKG_LIST}`
		if [ $? -ne 0 ]
		then
			error_log "project $project not found."
			echo -e "$project\tnot_found" >>${ROS_BUILD_STATUS}
			continue
		fi

		pkg=`echo "$p" | awk '{print $2}'`
		rm -f ${OUTPUT}/_status
		wget --no-check-certificate -q -c -P ${OUTPUT} https://${USER_INFO}@${OBS_DOMAIN}/build/$OBS_PROJECT/standard_x86_64/x86_64/$pkg:$project/_status
		if [ $? -ne 0 ]
		then
			error_log "get status of package $project fail"
			echo -e "$project\tunkown" >>${ROS_BUILD_STATUS}
			continue
		fi

		status=`grep "code" ${OUTPUT}/_status | cut -d'"' -f4`
		echo -e "$project\t$status" >>${ROS_BUILD_STATUS}
	done < ${ROS_CHECK_LIST}

	info_log "get status of projects ok"
}

main $*
