#!/bin/bash

. base.sh

GEN_ONE=$1

ROS_CAN_INSTALLED_LIST=${OUTPUT}/ros-can-installed.list
ROS_PKG_LIST=${OUTPUT}/ros-pkg.list
ROS_EPOL_LIST=${OUTPUT}/epol.list
ROS_PACKAGES_LIST=${OUTPUT}/packages.list

prepare()
{
        if [ ! -f ${ROS_CAN_INSTALLED_LIST} -o ! -f ${ROS_PKG_LIST} ]
        then
                error_log "Can not find ${ROS_PKG_SRC}, you can use get-repo-src.sh to create it"
                exit 1
        fi

	rm -f ${ROS_EPOL_LIST} ${ROS_PACKAGES_LIST} ${OUTPUT}/.epol.list
}

main()
{
        prepare

        info_log "Start to analyse ros-pkg."

        while read pkg repo version
        do
		grep -qP "ros-${ROS_DISTRO}-${pkg}$" ${ROS_CAN_INSTALLED_LIST} && echo $repo >> ${OUTPUT}/.epol.list
        done < ${ROS_PKG_LIST}

	cat ${OUTPUT}/.epol.list | sort | uniq >${ROS_EPOL_LIST}
	cat ${ROS_CAN_INSTALLED_LIST} | sort >${ROS_PACKAGES_LIST}

        info_log "Gen ros-pkg-src.list done, you can find it in ${ROS_PKG_SRC}"
}

main $*
