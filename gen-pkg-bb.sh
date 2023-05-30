#!/bin/bash

. base.sh

GEN_ONE=$1

BB_FIX=${ROOT}/bb_fix
BB_FIX_PKG_REMAP=${BB_FIX}/pkg.remap
ROS_PKG_SRC=${OUTPUT}/ros-pkg-src.list
ROS_PACKAGE_FIX=${ROOT}/package_fix
ROS_PKG_REMAP=${ROOT}/spec_fix/pkg.remap
ROS_GENERAGTED_BB_BASE=${ROS_BB_BASE}/recipes-generated

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
	fi

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

	lic_org=`grep "<license" ${pkg_dir}/package.xml`
	lic_beginline=`grep -n "<license" ${pkg_dir}/package.xml | head -1 | cut -d':' -f1`
	lic_endline=`grep -n "<license" ${pkg_dir}/package.xml | tail -1 | cut -d':' -f1`
	lic_md5=`sed -n "${lic_beginline},${lic_endline}p" ${pkg_dir}/package.xml | md5sum | cut -d' ' -f1`

	echo "LICENSE = \"$lics\"" >> $bbfile
	echo "LIC_FILES_CHKSUM = \"file://package.xml;beginline=${lic_beginline};endline=${lic_endline};md5=${lic_md5}\"" >> $bbfile
	echo "" >> $bbfile
}

gen_src_url()
{
	pkg=$1
	bbfile=$2
	git_url=$3
	tree=$4
	path=$5

	if [ "$SRC_TAR_FROM" != "ubuntu" ]
	then
		echo "OPENEULER_GIT_URL = \"$git_url\"" >> $bbfile
		echo "OPENEULER_BRANCH = \"${tree}\"" >> $bbfile
		echo "S = \"\${WORKDIR}/${path}\"" >> $bbfile
	fi

	echo "SRC_URI = \" \\" >> $bbfile
	if [ "$SRC_TAR_FROM" == "ubuntu" ]
	then
		echo "    file://\${OPENEULER_LOCAL_NAME}/ros-\${ROS_DISTRO}-\${ROS_SPN}_\${PV}.orig.tar.gz \\" >> $bbfile
	else
		echo "    file://${path} \\" >> $bbfile
	fi

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

	for dep in `cat $require_file`
	do
		map=`grep "^${dep} " ${ROS_PKG_REMAP}`
		[ "$map" == "" ] && continue

		bb_pkg=`echo $map | cut -d' ' -f2`
		sed -i "s#^${dep}\$#${bb_pkg}#g" $require_file
	done
}

# rename the openEuler rpm package name to openEuler embedded package name,
# such as in openEuler Server system, the name of python package setuptools_scm is 
# python3-setuptools_scm, but in openEuler embedded system, the name is 
# python3-setuptools-scm(bcauses the bbfile name use _ to split package name and version).
# use bb_fix/pkg.remap
rename_depend()
{
	require_file=$1

	for dep in `cat $require_file`
	do
		map=`grep "^${dep} " ${BB_FIX_PKG_REMAP}`
		#echo $dep $map
		[ "$map" == "" ] && continue

		bb_pkg=`echo $map | cut -d' ' -f2`
		sed -i "s#^${dep}\$#${bb_pkg}#g" $require_file
	done
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

		if [ "$SRC_TAR_FROM" != "ubuntu" ]
		then
			sed -i "s#_#-#g" ${require_file}
			sed -i "s#ros-distro#ros_distro#g" ${require_file}
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

	cat $require_file | sed -e 's#-devel$##g' | sort | uniq >${OUTPUT}/.temp${fix_bb_deps}

	if [ "$fix_bb_deps" == "DEPENDS" ]
	then
		if [ ! -f ${OUTPUT}/.tempRDEPENDS ]
		then
			bb_fix $pkg ${OUTPUT}/.temp${fix_bb_deps} $fix_bb_deps
			cat ${OUTPUT}/.temp${fix_bb_deps} | sort | uniq | sed -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
			return
		fi

		rm -f ${OUTPUT}/.temp${fix_bb_deps}

		for i in `cat $require_file | sed -e 's#-devel$##g' | sort | uniq`
		do
			grep -q "^${i}$" ${OUTPUT}/.tempRDEPENDS
			if [ $? -eq 0 -o "${i##*-}" == "native" ]
			then
				# if package in RDEPENDS, it's must a target device package.
				echo "$i" >> ${OUTPUT}/.temp${fix_bb_deps}
			else
				echo "${i}-native" >> ${OUTPUT}/.temp${fix_bb_deps}
			fi
		done
		cat ${OUTPUT}/.tempRDEPENDS >> ${OUTPUT}/.temp${fix_bb_deps}
	fi
	
	bb_fix $pkg ${OUTPUT}/.temp${fix_bb_deps} $fix_bb_deps

	if [ "$fix_bb_deps" == "RDEPENDS" ]
	then
		cat ${OUTPUT}/.temp${fix_bb_deps} | sed -e 's#-native$##g' | sort | uniq | sed -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
	else
		cat ${OUTPUT}/.temp${fix_bb_deps} | sort | uniq | sed -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
	fi
}

gen_depends()
{
	pkg=$1
	bbfile=$2

	rm -f ${OUTPUT}/{.tempRDEPENDS,.tempDEPENDS,.tempTDEPENDS}
	echo 'RDEPENDS:${PN} += "\' >> $bbfile
	gen_each_depend $pkg RDEPENDS Requires $bbfile
	echo '"' >> $bbfile
	echo "" >> $bbfile

	echo 'DEPENDS = "\' >> $bbfile
	gen_each_depend $pkg DEPENDS BuildRequires $bbfile
	echo '"' >> $bbfile
	echo "" >> $bbfile

	echo 'TDEPENDS = "\' >> $bbfile
	gen_each_depend $pkg TDEPENDS test-BuildRequires $bbfile
	echo '"' >> $bbfile

	echo "" >> $bbfile
}

gen_appends()
{
	pkg=$1
	bbfile=$2

	[ ! -f ${BB_FIX}/${pkg}/fix/APPENDS ] && return

	cat ${BB_FIX}/${pkg}/fix/APPENDS >> $bbfile
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

                mkdir -p ${ROS_GENERAGTED_BB_BASE}/${repo}/
                cd ${ROS_GENERAGTED_BB_BASE}/${repo}/

                grep -P "\t$repo\t" ${ROS_PKG_SRC} >${OUTPUT}/.repo_pkgs
                grep -P "\t$repo/" ${ROS_PKG_SRC} >>${OUTPUT}/.repo_pkgs

                while read pkg path version git_url tree
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

			if [ "$SRC_TAR_FROM" == "ubuntu" ]
			then
	                	pkg_dir_name=`cd ${ROS_SRC_BASE}/${repo} && ls ros-${ROS_DISTRO}-${pkg}_*.orig.tar.gz | sed -e "s#.orig.tar.gz##g" | sed -e "s#_#-#g"`
			else
	                	pkg_dir_name=`echo $path | sed -e "s#${repo}/##g"`
			fi

			mkdir -p ${ROS_GENERAGTED_BB_BASE}/${repo}/${pkg}

			#bbfile=${pkg}_${base_version}-${release_version}.bb
			bbfile=${ROS_GENERAGTED_BB_BASE}/${repo}/${pkg}/${pkg}.bb

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
			echo "" >> $bbfile

			gen_description $pkg $bbfile
        		
			maintainer=`grep maintainer: ${ROS_DEPS_BASE}/$pkg-PackageXml | awk -F"maintainer:" '{print $2}'`
			echo "AUTHOR = \"${maintainer}\"" >> $bbfile

        		url=`grep url: ${ROS_DEPS_BASE}/$pkg-PackageXml | awk -F"url:" '{print $2}' | sed -n '1p'`
			[ "$url" == "" ] && url="https://wiki.ros.org"
			echo "HOMEPAGE = \"${url}\"" >> $bbfile
			echo "" >> $bbfile

			gen_license $pkg ${ROS_SRC_BASE}/${repo}/${pkg_dir_name} $bbfile
			gen_src_url $pkg $bbfile $git_url $tree $path
			gen_depends $pkg $bbfile
			gen_appends $pkg $bbfile
			gen_build_type ${ROS_SRC_BASE}/${repo}/${pkg_dir_name} $bbfile
                done < ${OUTPUT}/.repo_pkgs
        done

        info_log "Gen bb files done, you can find it in ${ROS_GENERAGTED_BB_BASE}"
}

main $*
