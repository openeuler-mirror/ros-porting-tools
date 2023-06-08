#!/bin/bash

. base.sh

EBS_CONFIG_TPLT=${ROOT}/template/project.json
EBS_CONFIG=${OUTPUT}/project.json
EBS_PROJECTS=${OUTPUT}/ebs-projects.list

prepare()
{
	if [ ! -f ${ROS_PROJECTS_NAME} -o ! -f ${EBS_PROJECTS} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	cp ${EBS_CONFIG_TPLT} ${EBS_CONFIG}

	while read pkg
	do
		info_log "start create project $pkg"
		grep -q "^${pkg}$" ${ROS_PROJECTS_NAME}
		if [ $? -eq 0 ]
		then
			branch=${OPENEULER_SP_BRANCH}
		else
			branch=${OPENEULER_ROS_DEP_PKG_BRANCH}
		fi

		echo '    {' >> ${EBS_CONFIG}
		echo '      "spec_name": "'${pkg}'",' >> ${EBS_CONFIG}
		echo '      "spec_url": "'https://${GITEE_DOMAIN}/${GITEE_ORG}/${pkg}.git'",' >> ${EBS_CONFIG}
		echo '      "spec_branch": "'${branch}'",' >> ${EBS_CONFIG}
		echo '      "spec_description": "sig-ROS package '${pkg}'"' >> ${EBS_CONFIG}
		echo '    },' >> ${EBS_CONFIG}
	done < ${EBS_PROJECTS}

	echo '  ]' >> ${EBS_CONFIG}
	echo '}' >> ${EBS_CONFIG}

	info_log "create project ok"
}

main $*

