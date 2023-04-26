#!/bin/bash

. base.sh

ROS_SIG_BASE=${OUTPUT}/sig/sig-ROS/src-openeuler

prepare()
{
	if [ ! -f ${ROS_PROJECTS_NAME} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	mkdir -p ${ROS_SIG_BASE}
	rm -rf ${ROS_SIG_BASE}/*
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	cd ${ROS_SIG_BASE}

	while read project
	do
		class=${project:0:1}
		mkdir -p $class

		echo "name: $project" >${ROS_SIG_BASE}/$class/$project.yaml
		echo "description:" >>${ROS_SIG_BASE}/$class/$project.yaml
		for i in `cd ${ROS_REPO_BASE}/$project && ls *.spec`
		do
			sum=`grep "Summary: " ${ROS_REPO_BASE}/$project/$i | awk -F"Summary: " '{print $2}'`
			summary=`echo $(echo $sum)`
			echo "  $i : $summary" >>${ROS_SIG_BASE}/$class/$project.yaml
		done
		echo "upstream: ${SRC_TAR_BASE_URL}" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "branches:" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "- name: master" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "  type: protected" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "- name: ${ROS_DISTRO}" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "  type: protected" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "  create_from: master" >>${ROS_SIG_BASE}/$class/$project.yaml
		echo "type: public" >>${ROS_SIG_BASE}/$class/$project.yaml

	done < ${ROS_PROJECTS_NAME}

	info_log "create project ok"
}

main $*
