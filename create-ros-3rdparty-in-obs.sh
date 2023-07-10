#!/bin/bash

. base.sh

SERVICE_FILE=_service

prepare()
{
	if [ ! -f ${ROS_3RDPARTY_NAME} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	#mkdir -p ${ROS_OBS_BASE}
	#rm -rf ${ROS_OBS_BASE}/*
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read project
	do
		info_log "start create project $project"

		mkdir -p ${ROS_OBS_BASE}/${project}
		cd ${ROS_OBS_BASE}/${project}

		echo "<services>" > ${SERVICE_FILE}
		echo "  <service name=\"tar_scm\">" >> ${SERVICE_FILE}
		echo "    <param name=\"scm\">git</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"url\">https://${GITEE_DOMAIN}/${GITEE_ORG}/${project}.git</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"exclude\">*</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"extract\">*</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"revision\">${ROS_DISTRO}</param>" >> ${SERVICE_FILE}
		echo "  </service>" >> ${SERVICE_FILE}
		echo "</services>" >> ${SERVICE_FILE}
	done < ${ROS_3RDPARTY_NAME}

	info_log "create 3rdparty project ok"
}

main $*
