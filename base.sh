#!/bin/bash

ROOT=`pwd`
ROS_DISTRO=`grep ROS_DISTRO config | cut -d'=' -f2`
SRC_TAR_FROM=`grep SRC_TAR_FROM config | cut -d'=' -f2`
DEBUG=`grep DEBUG config | cut -d'=' -f2`
SRC_TAR_BASE_URL=`grep SRC_TAR_BASE_URL config | cut -d'=' -f2`
GITEE_ORG=`grep GITEE_ORG config | cut -d'=' -f2`
GITEE_DOMAIN=`grep GITEE_DOMAIN config | cut -d'=' -f2`
OBS_DOMAIN=`grep OBS_DOMAIN config | cut -d'=' -f2`
OBS_PROJECT=`grep OBS_PROJECT config | cut -d'=' -f2`

OUTPUT=${ROOT}/output
ROS_OUTPUT_TMP=${OUTPUT}/.tmp
ROS_SRC_BASE=${OUTPUT}/src
ROS_DEPS_BASE=${OUTPUT}/deps
ROS_REPO_BASE=${OUTPUT}/repo
ROS_BB_BASE=${OUTPUT}/bb
ROS_OBS_BASE=${OUTPUT}/obs
ROS_GITEE_BASE=${OUTPUT}/gitee
LOG=${OUTPUT}/ros-tools.log

ROS_PROJECTS_NAME=${OUTPUT}/ros-projects-name.list
ROS_PKG_LIST=${OUTPUT}/ros-pkg.list

mkdir -p ${OUTPUT}
mkdir -p ${ROS_OUTPUT_TMP}

error_log()
{
        echo "`date` [Error] $*"
        echo "`date` [Error] $*" >>${LOG}
}

info_log()
{
        echo "`date` [Info ] $*"
        echo "`date` [Info ] $*" >> ${LOG}
}

debug_log()
{
	if [ "$DEBUG" != "yes" ]
	then
	        return
	fi
        echo "`date` [Debug] $*"
        echo "`date` [Debug] $*" >> ${LOG}
}

if [ "${ROS_DISTRO}" = "" ]
then
        error_log "ROS_DISTRO not defined"
        exit 1
fi
