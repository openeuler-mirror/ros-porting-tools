#!/bin/bash
  
. base.sh

ROS_REPOS=${OUTPUT}/ros.repos

prepare()
{
        if [ ! -f ${ROS_REPOS} ]
        then
                error_log "Can not find ${ROS_REPOS}, you can use get-repo-list.sh to create it"
                exit 1
        fi

        mkdir -p ${ROS_SRC_BASE}
}

main()
{
        prepare

        info_log "Start to download ros-pkg."

	vcs import ${ROS_SRC_BASE} <${ROS_REPOS}

        info_log "Download ok, you can find source packages in ${ROS_SRC_BASE}"
}

main $*
