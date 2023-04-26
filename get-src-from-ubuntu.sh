#!/bin/bash
  
. base.sh

ROS_UBUNTU_PATH=${OUTPUT}/ubuntu

prepare()
{
        if [ ! -f ${ROS_PKG_LIST} ]
        then
                error_log "Can not find ${ROS_PKG_LIST}, you can use get-repo-list.sh to create it"
                exit 1
        fi

        mkdir -p ${ROS_SRC_BASE}
        rm -rf ${ROS_SRC_BASE}/*
        mkdir -p ${ROS_UBUNTU_PATH}
}

main()
{
        prepare

        info_log "Start to download ros-pkg."

        while read pkg path version
        do
                if [ "$pkg" = "" -o "$path" = "" ]
                then
                        continue
                fi

                info_log "download source package of $pkg"

                mkdir -p ${ROS_SRC_BASE}/$path
                pkg_full_name=ros-${ROS_DISTRO}-$pkg
		if [ ! -f ${ROS_UBUNTU_PATH}/${pkg_full_name} ]
		then
			debug_log "wget ${pkg_full_name}"
                	wget --no-check-certificate -q --show-progress --progress=bar:force 2>&1 -c -P ${ROS_UBUNTU_PATH} ${SRC_TAR_BASE_URL}/${pkg_full_name}
		fi

                src_name=`grep orig.tar.gz ${ROS_UBUNTU_PATH}/${pkg_full_name}  | cut -d'"' -f8`
                if [ "$src_name" == "" ]
                then
                        error_log "Can not find source package of $pkg"
                        continue
                fi

		tar -xf ${ROS_UBUNTU_PATH}/$src_name -C ${ROS_SRC_BASE}/$path/ 2>/dev/null
		if [ $? -ne 0 ]
		then
			debug_log "wget ${src_name}"
	                wget --no-check-certificate -q --show-progress --progress=bar:force 2>&1 -c -P ${ROS_UBUNTU_PATH} ${SRC_TAR_BASE_URL}/${pkg_full_name}/$src_name
                	if [ ! -f ${ROS_UBUNTU_PATH}/$src_name ]
                	then
                	        error_log "Fail to download source package of $pkg"
                	        continue
                	fi
			tar -xf ${ROS_UBUNTU_PATH}/$src_name -C ${ROS_SRC_BASE}/$path/
		else
			info_log "source package $src_name has exist"
		fi

                dir_name=`echo $src_name | sed -e "s#.orig.tar.gz##g" | sed -e "s#_#-#g"`

                cp ${ROS_UBUNTU_PATH}/$src_name ${ROS_SRC_BASE}/$path/

        done < ${ROS_PKG_LIST}

        info_log "Download ok, you can find source packages in ${ROS_SRC_BASE}"
}

main $*
