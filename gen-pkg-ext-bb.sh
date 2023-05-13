#!/bin/bash

. base.sh

GEN_ONE=$1

SPEC_TO_BB_LIST=${ROS_DISTRO}/spec_to_bb.list
BB_FIX=${ROOT}/bb_fix
BB_FIX_PKG_REMAP=${BB_FIX}/pkg.remap
BB_DEVTOOLS_BASE=${ROS_BB_BASE}/recipes-devtools
BB_EXTERNAL_BASE=${ROS_BB_BASE}/recipes-external
BB_TMP_BASE=${ROS_BB_BASE}/.tmp

prepare()
{
        if [ ! -f ${SPEC_TO_BB_LIST} ]
        then
                error_log "Can not find ${SPEC_TO_BB_LIST}."
                exit 1
        fi

	if [ "$GEN_ONE" == "" ]
	then
	        rm -rf ${BB_DEVTOOLS_BASE}
	        rm -rf ${BB_EXTERNAL_BASE}
	fi

	mkdir -p ${BB_DEVTOOLS_BASE}/python
	mkdir -p ${BB_EXTERNAL_BASE}
	mkdir -p ${BB_TMP_BASE}
}

gen_single_line_config()
{
	spec=$1
	bbfile=$2
	prefix=$3
	config_key=$4

	ret=`grep -i "^${prefix}" $spec | head -1 | awk -F"${prefix}" '{print $2}' | awk '$1=$1'`
	if [ "$ret" == "" ]
	then
		error_log "${config_key} is null."
	fi
	echo "${config_key} = \"$ret\"" >> $bbfile
}

gen_src_uri()
{
	spec=$1
	bbfile=$2
	src_name=$3
	pkg=$4

	echo "SRC_URI = \" \\" >> $bbfile
	echo "    file://\${OPENEULER_LOCAL_NAME}/${src_name} \\" >> $bbfile

	for patch in `grep "^Patch.*: " $spec | awk '{print $2}'`
	do
		echo "    file://\${OPENEULER_LOCAL_NAME}/${patch} \\" >> $bbfile
	done

	other_cfg=`ls ${BB_FIX}/$pkg 2>/dev/null | grep -v fix`
	if [ "$other_cfg" == "" ]
	then
		echo "\"" >> $bbfile
		return
	fi

	pkg_bb_dir=`dirname "$bbfile"`
	`cd ${BB_FIX}/$pkg && ls | grep -v fix | xargs -i cp -r {} ${pkg_bb_dir}`

	for patch in `cd ${BB_FIX}/$package_name/files 2>/dev/null && ls *.patch`
	do
		echo "    file://${patch} \\" >> $bbfile
	done

	echo "\"" >> $bbfile
}

gen_license()
{
	spec=$1
	bbfile=$2
	spec_name=$3

	grep -i "^License:" $spec | head -1 | awk -F":" '{print $2}' | awk '$1=$1' | sed -e "s# and #\n#g" > ${OUTPUT}/.tempLicense
	lics=""
	while read lic
	do
		yocto_lic=`python3 ${ROOT}/get-license.py "$lic"`
		[ "$yocto_lic" == "" ] && error_log "can not get license, origin license is \"$lic\"" && exit 1

		if [ "$lics" == "" ]
		then
			lics="$yocto_lic"
		else
			lics="$lics & $yocto_lic"
		fi
	done < ${OUTPUT}/.tempLicense

	if [ "$lics" == "" ]
	then
		error_log "license is null."
	fi

	echo "LICENSE = \"$lics\"" >> $bbfile
	
	#md5=`md5sum $spec | cut -d' ' -f1`
	#echo "LIC_FILES_CHKSUM = \"file://../${spec_name};md5=${md5}\"" >> $bbfile
	echo "LIC_FILES_CHKSUM = \"file://\${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10\"" >> $bbfile
}

rename_depend()
{
	dep=$1

	echo "$dep" | grep -q "^python%{python3_pkgversion}"
	[ $? -eq 0 ] && dep=`echo "$dep" | sed -e 's#python%{python3_pkgversion}#python3#g'`

	grep -q "^$dep " ${BB_FIX_PKG_REMAP}
	[ $? -ne 0 ] && echo "$dep" && return

	grep "^$dep " ${BB_FIX_PKG_REMAP} | cut -d' ' -f2
}

is_delete_depends()
{
	dep=$1
	pkg=$2
	fix_bb_deps=$3

	grep -q "^$dep$" ${BB_FIX}/all.remove && return 0

	[ ! -f ${BB_FIX}/${pkg}/fix/${fix_bb_deps} ] && return 1

	grep -q "^\-${dep}$" ${BB_FIX}/${pkg}/fix/${fix_bb_deps} && return 0

	return 1
}

gen_depends()
{
	spec=$1
	bbfile=$2
	bbfile_name=$3

	echo "DEPENDS += \" \\" >> $bbfile
	for dep in `grep "^BuildRequires:" $spec | awk '{print $2}' | sed -e 's#-devel##g'`
	do
		is_delete_depends $dep $bbfile_name DEPENDS && continue

		dep_new=`rename_depend $dep`
		echo $dep_new | sed -e 's#$#-native \\#g' -e 's#^#    #g' >> $bbfile
	done
	echo "\"" >> $bbfile
	echo "" >> $bbfile
}

gen_rdepends()
{
	spec=$1
	bbfile=$2
	bbfile_name=$3

	echo "RDEPENDS_\${PN} += \" \\" >> $bbfile
	for dep in `grep "^Requires:" $spec | awk '{print $2}' | sed -e 's#-devel##g'`
	do
		is_delete_depends $dep $bbfile_name RDEPENDS && continue

		dep_new=`rename_depend $dep`
		echo $dep_new | sed -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
	done

	echo "\"" >> $bbfile
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

gen_files()
{
	bbfile=$1

	echo 'FILES:${PN}: += " \' >> $bbfile
	echo '    ${libdir}/${BPN}/cmake/* \' >> $bbfile
	echo '    ${libdir}/cmake/* \' >> $bbfile
	echo '    ${prefix}/lib/${BPN}/cmake/* \' >> $bbfile
	echo '    ${prefix}/lib/cmake/* \' >> $bbfile
	echo '"' >> $bbfile
	echo "" >> $bbfile
}

main()
{
        prepare

        info_log "Start to generate bb file."

	while read package_name package_type is_native bbfile_name spec_url source_name unpack_name
        do
		echo "${package_name}" | grep -q "^#" && continue
		[ "$GEN_ONE" != "" -a "$package_name" != "$GEN_ONE" ] && continue

		if [ "${package_name}" == "" -o "${package_type}" == "" -o  "${is_native}" == "" -o  "${bbfile_name}" == "" -o  "${spec_url}" == "" -o  "${source_name}" == "" -o  "${unpack_name}" == "" ]
		then
			error_log "configuration of $package_name is incomplete."
			continue
		fi

		info_log "start to generate bbfile for $package_name"

		if [ "$is_native" == "yes" -a "$package_type" == "python" ]
		then
			bbfile_prefix=${BB_DEVTOOLS_BASE}/python
		elif [ "$is_native" == "yes" -a "$package_type" == "cmake" ]
		then
			bbfile_prefix=${BB_DEVTOOLS_BASE}
		else
			bbfile_prefix=${BB_EXTERNAL_BASE}
		fi

		[ -d ${BB_FIX}/$package_name ] && bbfile_prefix="$bbfile_prefix/$package_name"

		mkdir -p ${bbfile_prefix}

		bbfile=${bbfile_prefix}/${bbfile_name}.bb

		#the format of spec_url must be like https://gitee.com/src-openeuler/catkin_pkg/raw/master/catkin-pkg.spec
		spec_name=`echo $spec_url | cut -d'/' -f8`
		branch=`echo $spec_url | cut -d'/' -f7`
		repo=`echo $spec_url | cut -d'/' -f5`
		git_url=`echo $spec_url | awk -F'/' '{print $1"//"$2"/"$3"/"$4}'`
		spec=${BB_TMP_BASE}/$spec_name
		
		[ ! -f $spec ] && wget --no-check-certificate -q --show-progress --progress=bar:force 2>&1 -c -P ${BB_TMP_BASE} ${spec_url}

		if [ ! -f $spec ]
		then
			error_log "download spec error, $spec_url"
			continue
		fi

		echo "PN = \"${package_name}\"" > $bbfile

		gen_single_line_config $spec $bbfile "Summary:" "DESCRIPTION"
		gen_single_line_config $spec $bbfile "URL:" "HOMEPAGE"
		gen_license $spec $bbfile $spec_name
		gen_single_line_config $spec $bbfile "Version:" "PV"
		echo "" >> $bbfile

		if [ "$package_type" == "python" ]
		then
			echo "inherit pypi setuptools3" >> $bbfile
			echo "" >> $bbfile
			echo "PYPI_PACKAGE = \"${package_name}\"" >> $bbfile
			echo "" >> $bbfile
		else
			echo "inherit cmake" >> $bbfile
			echo "" >> $bbfile
		fi

		echo "OPENEULER_GIT_URL = \"${git_url}\"" >> $bbfile
		echo "OPENEULER_REPO_NAME = \"${repo}\"" >> $bbfile
		echo 'OPENEULER_LOCAL_NAME = "${OPENEULER_REPO_NAME}"' >> $bbfile
		echo "OPENEULER_BRANCH = \"${branch}\"" >> $bbfile
		echo "" >> $bbfile

		gen_src_uri $spec $bbfile $source_name $package_name
		echo "S = \"\${WORKDIR}/${unpack_name}\"" >> $bbfile
		echo "" >> $bbfile

		gen_depends $spec $bbfile $bbfile_name
		gen_rdepends $spec $bbfile $bbfile_name

		gen_appends $package_name $bbfile

		if [ "$is_native" == "yes" ]
		then
			echo "BBCLASSEXTEND = \"native nativesdk\"" >> $bbfile
		else
			echo "BBCLASSEXTEND = \"native\"" >> $bbfile
		fi

		#gen_files $bbfile
        done < ${SPEC_TO_BB_LIST}

        info_log "Gen bb files done, you can find it in ${ROS_BB_BASE}"
}

main $*
