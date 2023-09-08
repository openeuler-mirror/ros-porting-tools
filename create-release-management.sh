#!/bin/bash

. base.sh

PCKG_MGMT=${OUTPUT}/pckg-mgmt.yaml
EPOL_LIST=${OUTPUT}/epol.list
ROS_OBS_FROM=openEuler:22.03:LTS:Next:Epol:Multi-Version:ROS:humble
ROS_OBS_TO=openEuler:22.03:LTS:SP2:Epol:Multi-Version:ROS:humble
ROS_DEP_OBS_FROM=openEuler:22.03:LTS:Next:Epol
ROS_DEP_OBS_TO=openEuler:22.03:LTS:SP2:Epol

prepare()
{
	if [ ! -f ${EPOL_LIST} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	>${PCKG_MGMT}
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read repo
	do
		info_log "start create project $repo"

		grep -q "^${repo}$" ${ROS_PROJECTS_NAME}
		if [ $? -eq 0 ]
		then
			obs_from=${ROS_OBS_FROM}
			obs_to=${ROS_OBS_TO}
			source_dir=${OPENEULER_NEXT_BRANCH}
			destination_dir=${OPENEULER_SP_BRANCH}
		else
			obs_from=${ROS_DEP_OBS_FROM}
			obs_to=${ROS_DEP_OBS_TO}
			source_dir=${OPENEULER_ROS_DEP_NEXT_BRANCH}
			destination_dir=${OPENEULER_ROS_DEP_PKG_BRANCH}
		fi
		echo '- name: '$repo >> ${PCKG_MGMT}
		echo '  source_dir: '${source_dir} >> ${PCKG_MGMT}
		echo '  destination_dir: '${destination_dir} >> ${PCKG_MGMT}
		echo '  obs_from: '${obs_from} >> ${PCKG_MGMT}
		echo '  obs_to: '${obs_to} >> ${PCKG_MGMT}
		echo '  date: '\'`date +%Y-%m-%d`\' >> ${PCKG_MGMT}
	done < ${EPOL_LIST}

	info_log "create project ok"
}

main $*
