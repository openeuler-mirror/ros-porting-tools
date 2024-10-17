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
	mkdir -p ${OUTPUT}/obs_project
	cd ${OUTPUT}/obs_project
	osc checkout ${OBS_PROJECT}
	osc update
	echo "success clone obs prjector: ${OBS_PROJE}"
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read project
	do
		info_log "start push to $project to obs"
		
		if [ -d "${OUTPUT}/obs_project/${OBS_PROJECT}/$project" ]
		then
			continue
		fi

		#1. create project
                cd ${OUTPUT}/obs_project/${OBS_PROJECT}
                osc mkpac $project

	        #2. copy obs project
		cp ${OUTPUT}/obs/${project}/_service ${OUTPUT}/obs_project/${OBS_PROJECT}/${project}/_service

		#3. push _service 
		cd ${OUTPUT}/obs_project/${OBS_PROJECT}/${project}
		osc add _service
		osc commit -m "fix"

	done < ${ROS_PUSH_LIST}

	while read project
	do
		info_log "start push to $project to obs"
		
		if [ -d "${OUTPUT}/obs_project/${OBS_PROJECT}/$project" ]
		then
			continue
		fi

		#1. create project
                cd ${OUTPUT}/obs_project/${OBS_PROJECT}
                osc mkpac $project

	        #2. copy obs project
		cp ${OUTPUT}/obs/${project}/_service ${OUTPUT}/obs_project/${OBS_PROJECT}/${project}/_service

		#3. push _service 
		cd ${OUTPUT}/obs_project/${OBS_PROJECT}/${project}
		osc add _service
		osc commit -m "fix"

	done < ${ROS_3RDPARTY_NAME}

	info_log "Done push projects to obs"
}

main $*
