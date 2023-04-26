#!/bin/bash

. base.sh

ROS_PKG_SRC=${OUTPUT}/ros-pkg-src.list

prepare()
{
	if [ "${ROS_SRC_BASE}" = "" ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	if [ ! -d ${ROS_SRC_BASE} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	if [ ! -f ${ROS_PKG_LIST} ]
	then
		error_log "Can not find ${ROS_PKG_LIST}, you can use get-repo-list.sh to create it"
		exit 1
	fi

	>${ROS_PKG_SRC}
}


find_pkg_src_path_by_package_xml()
{
	pkg_org_name=$1
	base_path=$2

	package_xml=`find ${ROS_SRC_BASE}/${base_path} -name package.xml`

	for i in $package_xml
	do
		grep -Fq "<name>$pkg_org_name</name>" $i
		if [ $? -eq 0 ]
		then
			pkg_src_path=`echo $i | sed "s#${ROS_SRC_BASE}/##g" | sed "s#/package.xml##g"`
			echo $pkg_src_path
			return 0
		fi
	done

	return 0
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	while read pkg base_path version
	do
		if [ "$pkg" = "" -o "$base_path" = "" ]
		then
			continue
		fi

		if [ "$SRC_TAR_FROM" == "ubuntu" ]
		then
			pkg_src_path=""
                	pkg_org_name=`cd ${ROS_SRC_BASE}/${base_path} && ls ros-${ROS_DISTRO}-${pkg}_*.orig.tar.gz | sed -e "s#.orig.tar.gz##g" | sed -e "s#_#-#g"`
                	version=`cd ${ROS_SRC_BASE}/${base_path} && ls ros-${ROS_DISTRO}-${pkg}_*.orig.tar.gz | cut -d'_' -f2 | sed -e "s#.orig.tar.gz##g"`

			if [ -f ${ROS_SRC_BASE}/${base_path}/${pkg_org_name}/package.xml ]
			then
				pkg_src_path=${base_path}/${pkg_org_name}
			fi

			if [ "$pkg_src_path" = "" ]
			then
				error_log "Can not find src path for package $pkg"
			fi
			echo -e "$pkg\t$pkg_src_path\t$version-1" >> ${ROS_PKG_SRC}
		else
			pkg_org_name=`echo $pkg | sed "s/-/_/g"`
			pkg_src_path=""

			if [ -f ${ROS_SRC_BASE}/${base_path}/${pkg_org_name}/package.xml ]
			then
				pkg_src_path=${base_path}/${pkg_org_name}
			fi

			if [ -f ${ROS_SRC_BASE}/${base_path}/package.xml ]
			then
				pkg_src_path=${base_path}
			fi

			if [ "$pkg_src_path" = "" ]
			then
				pkg_src_path=`find_pkg_src_path_by_package_xml $pkg_org_name ${base_path}`
			fi

			if [ "$pkg_src_path" = "" ]
			then
				error_log "Can not find src path for package $pkg"
			fi
			echo -e "$pkg\t$pkg_src_path\t$version" >> ${ROS_PKG_SRC}
		fi
	done < ${ROS_PKG_LIST}

	info_log "Gen ros-pkg-src.list done, you can find it in ${ROS_PKG_SRC}"
}

main $*
