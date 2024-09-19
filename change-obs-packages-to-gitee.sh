#!/bin/bash

. base.sh

USER_INFO="$1"
OBS_PACKAGES_LIST=${OUTPUT}/obs-packages.list
OBS_BASE=${OUTPUT}/obs
SERVICE_FILE=_service


prepare()
{
	if [ ! -d "${OBS_BASE}" -o ! -f "${OBS_PACKAGES_LIST}" ]
	then
		log_error "please run download-obs-projects.sh first"
		exit 1
	fi
}

main()
{
	prepare

	info_log "Start to change obs packages."
	cd ${OBS_BASE}/${OBS_PROJECT}

	while read pkg
	do
		info_log "start change package $pkg"

		grep -q "^${pkg}$" ${ROS_PROJECTS_NAME}
		if [ $? -eq 0 ]
		then
			branch=${OPENEULER_SP_BRANCH}
		else
			branch=${OPENEULER_ROS_DEP_PKG_BRANCH}
		fi

		cd ${OBS_BASE}/${OBS_PROJECT}/${pkg}
		echo "<services>" > ${SERVICE_FILE}
		echo "  <service name=\"tar_scm\">" >> ${SERVICE_FILE}
		echo "    <param name=\"scm\">git</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"url\">https://${GITEE_DOMAIN}/${GITEE_ORG}/${pkg}.git</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"exclude\">*</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"extract\">*</param>" >> ${SERVICE_FILE}
		echo "    <param name=\"revision\">${branch}</param>" >> ${SERVICE_FILE}
		echo "  </service>" >> ${SERVICE_FILE}
		echo "</services>" >> ${SERVICE_FILE}

		osc ci -m "change remote to ${GITEE_DOMAIN}/${GITEE_ORG}"
		[ $? -ne 0 ] && log_error "change package $pkg error"
	done < ${OBS_PACKAGES_LIST}

	info_log "get status of projects ok"
}

main $*
