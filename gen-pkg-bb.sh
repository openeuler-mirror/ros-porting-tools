#!/bin/bash

. base.sh

GEN_ONE=$1

ROS_PKG_SRC=${OUTPUT}/ros-pkg-src.list
ROS_PACKAGE_FIX=${ROOT}/package_fix
ROS_PKG_REMAP=${ROOT}/spec_fix/pkg.remap

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

        if [ ! -f ${ROS_PKG_SRC} -o ! -f ${ROS_PKG_LIST} ]
        then
                error_log "Can not find ${ROS_PKG_SRC}, you can use get-repo-src.sh to create it"
                exit 1
        fi

	if [ "$GEN_ONE" == "" ]
	then
	        rm -rf ${ROS_BB_BASE}
	fi
        mkdir -p ${ROS_BB_BASE}
}

gen_description()
{
	pkg=$1
	bbfile=$2
        
	desc_wc=`cat ${ROS_DEPS_BASE}/$pkg-PackageXml-description | wc -l`
        if [ "$desc_wc" = "1" ]
        then
                desc=`cat ${ROS_DEPS_BASE}/$pkg-PackageXml-description`
        else
                desc="ROS $pkg package"
        fi

	echo "DESCRIPTION = \"$desc\"" >> $bbfile
}

gen_license()
{
	pkg=$1
	pkg_dir=$2
	bbfile=$3

	lics=""
	grep license: ${ROS_DEPS_BASE}/$pkg-PackageXml | awk -F"license:" '{print $2}' >${OUTPUT}/.tempLicense
	while read lic
	do
		yocto_lic=`python3 ${ROOT}/get-license.py "$lic"`
		[ "$yocto_lic" == "" ] && error_log "can not get license for package $pkg, origin license is \"$lic\"" && exit 1

		if [ "$lics" == "" ]
		then
			lics="$yocto_lic"
		else
			lics="$lics & $yocto_lic"
		fi
	done < ${OUTPUT}/.tempLicense

	lic_org=`grep "license" ${pkg_dir}/package.xml`
	lic_beginline=`grep -n "license" ${pkg_dir}/package.xml | head -1 | cut -d':' -f1`
	lic_endline=`grep -n "license" ${pkg_dir}/package.xml | tail -1 | cut -d':' -f1`
	lic_md5=`echo "$lic_org" | md5sum | cut -d' ' -f1`

	echo "LICENSE = \"$lics\"" >> $bbfile
	echo "LIC_FILES_CHKSUM = \"file://package.xml;beginline=${lic_beginline};endline=${lic_endline};md5=${lic_md5}\"" >> $bbfile
	echo "" >> $bbfile
}

gen_src_url()
{
	pkg=$1
	bbfile=$2

	echo "SRC_URI = \" \\" >> $bbfile
	echo "    file://\${OPENEULER_LOCAL_NAME}/ros-\${ROS_DISTRO}-\${ROS_SPN}_\${PV}.orig.tar.gz \\" >> $bbfile
	if [ ! -d ${ROS_PACKAGE_FIX}/${pkg} ]
	then
		echo "\"" >> $bbfile
		echo "" >> $bbfile
		return
	fi

	for tarball in `cd ${ROS_PACKAGE_FIX}/${pkg} && ls | grep -v "\.fix" | grep -v "\.patch"`
	do
		echo "    file://${tarball} \\" >> $bbfile
	done

	if [ -f ${ROS_PACKAGE_FIX}/${pkg}/source.fix ]
	then
		for patch in `grep "^Patch.*: " ${ROS_PACKAGE_FIX}/${pkg}/source.fix | cut -d':' -f2`
		do
			echo "    file://${patch} \\" >> $bbfile
		done
	fi

	echo "\"" >> $bbfile
	echo "" >> $bbfile
}

rename_requires()
{
	require_file=$1

	while read deb_pkg rpm_pkg
	do
		sed -i "s#^${deb_pkg}\$#${rpm_pkg}#g" $require_file
	done <${ROS_PKG_REMAP}
}

spec_fix()
{
	pkg=$1
	spec_fix_type=$2
	require_file=$3

	spec_fix_file=${ROOT}/spec_fix/$pkg.${spec_fix_type}

	[ ! -f ${spec_fix_file} ] && return

	if [ -f ${require_file} ]
	then
		for dep in `grep "^\-" ${spec_fix_file} | sed -e "s#^\-##g"`
		do
			sed -i "/^$dep\$/d" $require_file
		done
	fi

	grep -q "^\+" $spec_fix_file
	[ $? -ne 0 ] && return 
	
	grep "^\+" $spec_fix_file | sed -e "s#^\+##g" >> ${require_file}
}


gen_each_depend()
{
	pkg=$1
	depend_name=$2
	deps_suffix=$3
	spec_fix_type=$4
	bbfile=$5

        debug_log "gen ${depend_name}"

	package_xml_deps=${ROS_DEPS_BASE}/$pkg-${deps_suffix}
	require_file=${OUTPUT}/.tempDepends

	rm -f ${require_file}

	[ -f ${package_xml_deps} ] && cp ${package_xml_deps} ${require_file}
	spec_fix $pkg $spec_fix_type $require_file

        if [ ! -f ${require_file} ]
        then
		echo "$depend_name = \" \\" >> $bbfile
		echo "\"" >> $bbfile
		echo "" >> $bbfile
		return
	fi
	
	rename_requires $require_file

	echo "$depend_name = \" \\" >> $bbfile

	if [ "$pkg" != "ament-cmake-core" -a "$pkg" != "ament-package" -a "$pkg" != "ros-workspace" ]
	then
		if [ "$depend_name" == "ROS_BUILD_DEPENDS" -o "$depend_name" == "ROS_EXEC_DEPENDS" ]
		then
			echo "ros-workspace" >> $require_file
		fi
	fi

	if [ "$depend_name" == "ROS_BUILDTOOL_DEPENDS" -o "$depend_name" == "ROS_BUILDTOOL_EXPORT_DEPENDS" ]
	then
		cat $require_file | sed -e 's#$#-native \\#g' -e 's#^#    #g' >> $bbfile
	else
		cat $require_file | sed -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
	fi

	echo "\"" >> $bbfile
	echo "" >> $bbfile
}

gen_depends()
{
	pkg=$1
	bbfile=$2

	gen_each_depend $pkg ROS_BUILD_DEPENDS BuildDepends BuildRequires $bbfile
	gen_each_depend $pkg ROS_BUILD_EXPORT_DEPENDS BuildExportDepends BuildRequires $bbfile
	gen_each_depend $pkg ROS_BUILDTOOL_DEPENDS BuildToolDepends BuildRequires $bbfile
	gen_each_depend $pkg ROS_BUILDTOOL_EXPORT_DEPENDS BuildToolExportDepends BuildRequires $bbfile
	gen_each_depend $pkg ROS_EXEC_DEPENDS ExecDepends Requires $bbfile
	gen_each_depend $pkg ROS_TEST_DEPENDS TestDepends test-BuildRequires $bbfile

	echo 'DEPENDS  = "${ROS_BUILD_DEPENDS} ${ROS_BUILD_EXPORT_DEPENDS}"' >> $bbfile
	echo 'DEPENDS += "${ROS_BUILDTOOL_DEPENDS} ${ROS_BUILDTOOL_EXPORT_DEPENDS}"' >> $bbfile
	echo 'RDEPENDS:${PN} += "${ROS_EXEC_DEPENDS}"' >> $bbfile
	echo "" >> $bbfile
}

gen_build_type()
{
	pkg_dir=$1
	bbfile=$2

        if [ -f ${pkg_dir}/CMakeLists.txt ]
        then
                build_type="ament_cmake"
        else
                build_type="ament_python"
        fi

	echo "ROS_BUILD_TYPE = \"${build_type}\"" >> $bbfile
	echo 'inherit ros_${ROS_BUILD_TYPE}' >> $bbfile
}

main()
{
        prepare

        info_log "Start to analyse ros-pkg."

        for repo in `cat ${ROS_PKG_LIST} | awk '{print $2}' | sort | uniq`
        do
		[ "$GEN_ONE" == "" ] && info_log "start to generate bbfile for repository $repo"

                mkdir -p ${ROS_BB_BASE}/${repo}/
                cd ${ROS_BB_BASE}/${repo}/

                grep -P "\t$repo\t" ${ROS_PKG_SRC} >${OUTPUT}/.repo_pkgs
                grep -P "\t$repo/" ${ROS_PKG_SRC} >>${OUTPUT}/.repo_pkgs

                while read pkg path version
                do
			if [ "$GEN_ONE" != "" -a "$pkg" != "$GEN_ONE" ]
			then
				continue
			fi

                        if [ "$pkg" = "" -o "$path" = "" -o "$version" = "" ]
                        then
                                error_log "Wrong package $pkg"
                                exit 1
                        fi

			info_log "generate bbfile for package $pkg"

                        base_version=`echo $version | awk -F"-" '{print $1}'`
                        release_version=`echo $version | awk -F"-" '{print $2}'`

                	pkg_dir_name=`cd ${ROS_SRC_BASE}/${repo} && ls ros-${ROS_DISTRO}-${pkg}_*.orig.tar.gz | sed -e "s#.orig.tar.gz##g" | sed -e "s#_#-#g"`

			#bbfile=${pkg}_${base_version}-${release_version}.bb
			bbfile=${pkg}.bb

			echo "# Generated by ros-porting-tools -- DO NOT EDIT" > $bbfile
			echo "# Copyright Huawei Technologies Co., Ltd." >> $bbfile
			echo "" >> $bbfile

			echo "# repository name" >> $bbfile
			echo "ROS_CN  = \"${repo}\"" >> $bbfile

			bpn=`grep "name:" ${ROS_DEPS_BASE}/$pkg-PackageXml | cut -d':' -f2`
			echo "# package name in package.xml" >> $bbfile
			echo "ROS_BPN = \"${bpn}\"" >> $bbfile

			echo "# software tarball name" >> $bbfile
			echo "ROS_SPN = \"${pkg}\"" >> $bbfile

			echo "PV      = \"${base_version}\"" >> $bbfile
			echo "" >> $bbfile

			echo "inherit ros-distro-${ROS_DISTRO}" >> $bbfile
			echo "" >> $bbfile

			gen_description $pkg $bbfile
        		
			maintainer=`grep maintainer: ${ROS_DEPS_BASE}/$pkg-PackageXml | awk -F"maintainer:" '{print $2}'`
			echo "AUTHOR = \"${maintainer}\"" >> $bbfile

        		url=`grep url: ${ROS_DEPS_BASE}/$pkg-PackageXml | awk -F"url:" '{print $2}' | sed -n '1p'`
			[ "$url" == "" ] && url="https://wiki.ros.org"
			echo "HOMEPAGE = \"${url}\"" >> $bbfile
			echo "" >> $bbfile

			gen_license $pkg ${ROS_SRC_BASE}/${repo}/${pkg_dir_name} $bbfile
			gen_src_url $pkg $bbfile
			gen_depends $pkg $bbfile
			gen_build_type ${ROS_SRC_BASE}/${repo}/${pkg_dir_name} $bbfile
                done < ${OUTPUT}/.repo_pkgs
        done

        info_log "Gen bb files done, you can find it in ${ROS_BB_BASE}"
}

main $*
