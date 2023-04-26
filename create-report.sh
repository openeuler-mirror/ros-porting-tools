#!/bin/bash

. base.sh

ROS_REPORT=${OUTPUT}/ros-report.list
ROS_CHECK_LIST=${ROOT}/ros-check.list
ROS_BUILD_STATUS=${OUTPUT}/ros-build-status.list

prepare()
{
        if [ ! -f ${ROS_PROJECTS_NAME} -o ! -f ${ROS_PKG_LIST} -o ! -f ${ROS_CHECK_LIST} -o ! -f ${ROS_BUILD_STATUS} ]
        then
                error_log "Can not find ${ROS_PROJECTS_NAME} and ${ROS_PKG_LIST}"
                exit 1
        fi

        >${ROS_REPORT}
}

main()
{
        prepare

        info_log "Start to analyse ros-pkg."
	
	echo -e "Repository\tPackage\tIs in work list\tBuild status" >> ${ROS_REPORT}

	while read repo
        do

                #if [ "$repo" != "control_box_rst" ]
                #then
                #       continue
                #fi

                grep -P "\t$repo\t" ${ROS_PKG_LIST} >${OUTPUT}/.repo_pkgs

		echo "$repo" >> ${ROS_REPORT}

                while read pkg _repo version
                do
                        if [ "$pkg" = "" -o "$_repo" = "" ]
                        then
                                error_log "Wrong package $pkg"
                                exit 1
                        fi

			is_in_ros_check=""
			build_status=""

			grep -qP "^$pkg\$" ${ROS_CHECK_LIST}

			[ $? -eq 0 ] && is_in_ros_check=yes
			[ "$is_in_ros_check" == "yes" ] && build_status=`grep -P "^$pkg\t" ${ROS_BUILD_STATUS} | awk '{print $2}'`

			echo -e "\t$pkg\t${is_in_ros_check}\t${build_status}" >> ${ROS_REPORT}
                done < ${OUTPUT}/.repo_pkgs
        done <${ROS_PROJECTS_NAME}

	echo "-----------package not in ros-----------" >> ${ROS_REPORT}

	while read pkg
	do
		grep -qP "^$pkg\t" ${ROS_PKG_LIST}
		[ $? -eq 0 ] && continue

		echo "$pkg" >> ${ROS_REPORT}
		build_status=`grep -P "^$pkg\t" ${ROS_BUILD_STATUS} | awk '{print $2}'`
		echo -e "\t$pkg\tyes\t${build_status}" >> ${ROS_REPORT}
	done < ${ROS_CHECK_LIST}

        info_log "Gen ${ROS_REPORT} done"
}

main $*
