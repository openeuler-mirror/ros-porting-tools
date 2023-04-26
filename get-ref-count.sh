#!/bin/bash

. base.sh

ROS_PKG_REF_COUNT=${OUTPUT}/pkg-ref-count

prepare()
{
	if [ ! -d ${ROS_DEPS_BASE} ]
	then
		error_log "Can not find ${ROS_DEPS_BASE}, you can use get-pkg-deps.sh to create it"
		exit 1
	fi

	>${ROS_PKG_REF_COUNT}
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	ls ${ROS_DEPS_BASE}/*Requires | grep -v "\-test\-" | xargs grep -F "ros-\${ros_distro}" | awk -F":" '{print $NF}' | awk -F'ros-\\${ros_distro}-' '{print $2}' >${OUTPUT}/.requires

	while pkg prj version
	do
		count=`grep -P "^$pkg$" ${OUTPUT}.requires | wc -l`
		echo -e "$pkg\t$count" >>${ROS_PKG_REF_COUNT}
	done < ${ROS_PKG_LIST}


	info_log "Gen pkg-ref-count done, you can find it in ${ROS_PKG_REF_COUNT}"
}

main $*
