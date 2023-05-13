#!/bin/bash

. base.sh

GEN_ONE=$1

BB_FIX=${ROOT}/bb_fix
BB_FIX_PKG_REMAP=${BB_FIX}/pkg.remap
ROS_PKG_SRC=${OUTPUT}/ros-pkg-src.list
ROS_PACKAGE_FIX=${ROOT}/package_fix
ROS_PKG_REMAP=${ROOT}/spec_fix/pkg.remap
ROS_GENERAGTED_BB_BASE=${ROS_BB_BASE}/recipes-generated
ROS_NATIVE_PKGS=${ROS_GENERAGTED_BB_BASE}/ros-native-pkgs.inc
ROS_NATIVE_PKGS_TMP1=${ROS_BB_BASE}/.ros-native-pkgs.tmp1
ROS_NATIVE_PKGS_TMP2=${ROS_BB_BASE}/.ros-native-pkgs.tmp2

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
	        rm -rf ${ROS_GENERAGTED_BB_BASE}
		rm -f ${ROS_NATIVE_PKGS}
		rm -f ${ROS_NATIVE_PKGS_TMP2}
	fi

	rm -f ${ROS_NATIVE_PKGS_TMP1}
        mkdir -p ${ROS_GENERAGTED_BB_BASE}
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
	if [ -d ${ROS_PACKAGE_FIX}/${pkg} ]
	then
		for tarball in `cd ${ROS_PACKAGE_FIX}/${pkg} && ls | grep -v "\.fix" | grep -v "\.patch"`
		do
			echo "    file://\${OPENEULER_LOCAL_NAME}/${tarball} \\" >> $bbfile
		done

		if [ -f ${ROS_PACKAGE_FIX}/${pkg}/source.fix ]
		then
			for patch in `grep "^Patch.*: " ${ROS_PACKAGE_FIX}/${pkg}/source.fix | awk '{print $2}'`
			do
				echo "    file://\${OPENEULER_LOCAL_NAME}/${patch} \\" >> $bbfile
			done
		fi
	fi

	other_cfg=`ls ${BB_FIX}/$pkg 2>/dev/null | grep -v fix`
	if [ "$other_cfg" == "" ]
	then
		echo "\"" >> $bbfile
		echo "" >> $bbfile
		return
	fi

	pkg_bb_dir=`dirname "$bbfile"`
	`cd ${BB_FIX}/$pkg && ls | grep -v fix | xargs -i cp -r {} ${pkg_bb_dir}`

	for patch in `cd ${BB_FIX}/$pkg/files 2>/dev/null && ls *.patch`
	do
		echo "    file://${patch} \\" >> $bbfile
	done

	echo "\"" >> $bbfile
	echo "" >> $bbfile
}

# rename the ros origin dependence package name(same this ubuntu) to openEuler,
# such as in ubuntu system, the develop package name of assimp is assimp-dev,
# but in openEuler system, the name is assimp-devel.
# use spec_fix/pkg.remap
rename_requires()
{
	require_file=$1

	while read deb_pkg rpm_pkg
	do
		sed -i "s#^${deb_pkg}\$#${rpm_pkg}#g" $require_file
	done <${ROS_PKG_REMAP}
}

# rename the openEuler rpm package name to openEuler embedded package name,
# such as in openEuler Server system, the name of python package setuptools_scm is 
# python3-setuptools_scm, but in openEuler embedded system, the name is 
# python3-setuptools-scm(bcauses the bbfile name use _ to split package name and version).
# use bb_fix/pkg.remap
rename_depend()
{
	require_file=$1

	while read rpm_pkg bb_pkg
	do
		sed -i "s#^${rpm_pkg}\$#${bb_pkg}#g" $require_file
	done <${BB_FIX_PKG_REMAP}
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

# fix DEPENDS and RDEPENDS
bb_fix()
{
	pkg=$1
	require_file=$2
	fix_bb_deps=$3

	if [ -f ${BB_FIX}/${pkg}/fix/${fix_bb_deps} ]
	then
		for dep in `grep "^\-" ${BB_FIX}/${pkg}/fix/${fix_bb_deps} | sed -e 's#^\-##g'`
		do
			sed -i "/^${dep}\$/d" $require_file
		done

		for dep in `grep "^\+" ${BB_FIX}/${pkg}/fix/${fix_bb_deps} | sed -e 's#^\+##g'`
		do
			echo "$dep" >> $require_file
		done
	fi

	while read dep
	do
		sed -i "/^$dep\$/d" $require_file
	done < ${BB_FIX}/all.remove
}

gen_each_depend()
{
	pkg=$1
	fix_bb_deps=$2
	spec_deps_suffix=$3
	bbfile=$4

        debug_log "gen ${fix_bb_deps}"

	package_xml_deps=${ROS_DEPS_BASE}/$pkg-${spec_deps_suffix}
	require_file=${OUTPUT}/.tempDepends

	rm -f ${require_file}

	if [ -f ${package_xml_deps} ]
	then
		if [ "$fix_bb_deps" == "TDEPENDS" ]
		then
			cat ${package_xml_deps} | sed -e "s#^BuildRequires: ##g" > ${require_file}
		else
			cat ${package_xml_deps} | sed -e "s#^${spec_deps_suffix}: ##g" > ${require_file}
		fi
	fi

	spec_fix $pkg $spec_deps_suffix $require_file

        if [ ! -f ${require_file} ]
        then
		return
	fi

	sed -i 's#ros-%{ros_distro}-##g' $require_file
	
	if [ "$pkg" != "ament-cmake-core" -a "$pkg" != "ament-package" -a "$pkg" != "ros-workspace" ]
	then
		echo "ros-workspace" >> $require_file
	fi

	rename_requires $require_file
	rename_depend $require_file
	bb_fix $pkg $require_file $fix_bb_deps

	if [ "$fix_bb_deps" == "DEPENDS" ]
	then
		cat $require_file >> ${ROS_NATIVE_PKGS_TMP1}
		cat $require_file | sed -e 's#-devel$##g' -e 's#$#-native \\#g' -e 's#^#    #g' >> $bbfile
	else
		cat $require_file | sed -e 's#-devel$##g' -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
	fi
}

gen_depends()
{
	pkg=$1
	bbfile=$2

	echo 'DEPENDS = "\' >> $bbfile
	gen_each_depend $pkg DEPENDS BuildRequires $bbfile
	echo '"' >> $bbfile
	echo "" >> $bbfile

	echo 'RDEPENDS:${PN} += "\' >> $bbfile
	gen_each_depend $pkg RDEPENDS Requires $bbfile
	echo '"' >> $bbfile
	echo "" >> $bbfile

	echo 'TDEPENDS = "\' >> $bbfile
	gen_each_depend $pkg TDEPENDS test-BuildRequires $bbfile
	echo '"' >> $bbfile

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

gen_native_pkgs()
{
	[ -f ${ROS_NATIVE_PKGS_TMP1} ] && cat ${ROS_NATIVE_PKGS_TMP1} >> ${ROS_NATIVE_PKGS_TMP2}

	if [ -f ${ROS_NATIVE_PKGS_TMP2} ]
	then
		cat ${ROS_NATIVE_PKGS_TMP2} | sort | uniq >${ROS_NATIVE_PKGS_TMP1}
		mv ${ROS_NATIVE_PKGS_TMP1} ${ROS_NATIVE_PKGS_TMP2} 
	fi

	echo "# Generated by ros-porting-tools -- DO NOT EDIT" > ${ROS_NATIVE_PKGS}
	echo "# Copyright Huawei Technologies Co., Ltd." >> ${ROS_NATIVE_PKGS}
	echo "" >> ${ROS_NATIVE_PKGS}

	echo "ROS_NATIVE_PKGS = \"\\" >> ${ROS_NATIVE_PKGS}
	cat ${ROS_NATIVE_PKGS_TMP2} | sed -e 's#$#-native \\#g' -e 's#^#    #g' >> ${ROS_NATIVE_PKGS}
	echo "\"" >> ${ROS_NATIVE_PKGS}
}

main()
{
        prepare

        info_log "Start to analyse ros-pkg."

        for repo in `cat ${ROS_PKG_LIST} | awk '{print $2}' | sort | uniq`
        do
		[ "$GEN_ONE" == "" ] && info_log "start to generate bbfile for repository $repo"

                mkdir -p ${ROS_GENERAGTED_BB_BASE}/${repo}/
                cd ${ROS_GENERAGTED_BB_BASE}/${repo}/

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

			bpn=`grep "name:" ${ROS_DEPS_BASE}/$pkg-PackageXml | cut -d':' -f2 | head -1`
			echo "# package name in package.xml" >> $bbfile
			echo "ROS_BPN = \"${bpn}\"" >> $bbfile

			echo "# software tarball name" >> $bbfile
			echo "ROS_SPN = \"${pkg}\"" >> $bbfile

			echo "PV      = \"${base_version}\"" >> $bbfile
			echo "" >> $bbfile

			echo "inherit ros-distro-${ROS_DISTRO}" >> $bbfile
			echo "inherit ros-native-pkgs" >> $bbfile
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

	gen_native_pkgs

        info_log "Gen bb files done, you can find it in ${ROS_GENERAGTED_BB_BASE}"
}

main $*
