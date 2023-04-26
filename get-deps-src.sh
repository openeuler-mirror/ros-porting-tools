#!/bin/bash

. base.sh

ROS_DEPS=${OUTPUT}/ros-deps.list
ROS_DEPS_SRC=${OUTPUT}/ros-deps-src.list

prepare()
{
	if [ ! -d ${ROS_DEPS_BASE} ]
	then
		error_log "Can not find ${ROS_DEPS_BASE}, you can use get-pkg-deps.sh to create it"
		exit 1
	fi

	cat /etc/os-release | grep -q Ubuntu
	if [ $? -ne 0 ]
	then
		error_log "Please run me in Ubuntu system"
		exit 1
	fi

	>${ROS_DEPS}
	>${ROS_DEPS_SRC}
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	for i in `cat ${ROS_DEPS_BASE}/*ExtDeps | sort | uniq`
	do
		info_log "Analyse $i"

		echo -e "$i" >> ${ROS_DEPS}

		apt show $i 2>/dev/null >${OUTPUT}/.apt_result
		if [ $? -ne 0 ]
		then
			error_log "Can not find pkg $i"
			echo $i >>${ROS_DEPS_SRC}
			continue
		fi

		src_pkg=`cat ${OUTPUT}/.apt_result | grep "Source: " | awk -F "Source: " '{print $2}'`
		if [ "$src_pkg" = "" ]
		then

			src_pkg=$i
		fi

		echo -e "$i\t$src_pkg" >> ${ROS_DEPS_SRC}
	done


	info_log "Gen ros-pkg-src.list done, you can find it in ${ROS_DEPS_SRC}"
}

main $*
