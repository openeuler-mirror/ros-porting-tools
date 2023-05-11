#!/bin/bash

. base.sh

GEN_ONE=$1

SPEC_TO_BB_LIST=${ROS_DISTRO}/spec_to_bb.list
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

gen_license()
{
	spec=$1
	bbfile=$2

	ret=`grep -i "^License:" $spec | head -1 | awk -F":" '{print $2}' | awk '$1=$1' | sed -e 's#and#\&#g'`
	if [ "$ret" == "" ]
	then
		error_log "license is null."
	fi
	echo "LICENSE = \"$ret\"" >> $bbfile
	echo "LIC_FILES_CHKSUM = \"\"" >> $bbfile
}
main()
{
        prepare

        info_log "Start to generate bb file."

	while read package_name package_type is_native bbfile_name spec_url source_name
        do
		echo "${package_name}" | grep -q "^#" && continue
		[ "$GEN_ONE" != "" -a "$package_name" != "$GEN_ONE" ] && continue

		if [ "${package_name}" == "" -o "${package_type}" == "" -o  "${is_native}" == "" -o  "${bbfile_name}" == "" -o  "${spec_url}" == "" ]
		then
			error_log "configuration of $package_name is incomplete."
			continue
		fi

		info_log "start to generate bbfile for $package_name"

		if [ "$is_native" == "yes" -a "$package_type" == "python" ]
		then
			bbfile=${BB_DEVTOOLS_BASE}/python/${bbfile_name}.bb
		elif [ "$is_native" == "yes" -a "$package_type" == "cmake" ]
		then
			bbfile=${BB_DEVTOOLS_BASE}/${bbfile_name}.bb
		else
			bbfile=${BB_EXTERNAL_BASE}/${bbfile_name}.bb
		fi

	        wget --no-check-certificate -q --show-progress --progress=bar:force 2>&1 -c -P ${BB_TMP_BASE} ${spec_url}

		#the format of spec_url must be like https://gitee.com/src-openeuler/catkin_pkg/raw/master/catkin-pkg.spec
		spec_name=`echo $spec_url | cut -d'/' -f8`
		branch=`echo $spec_url | cut -d'/' -f7`
		repo=`echo $spec_url | cut -d'/' -f5`
		git_url=`echo $spec_url | awk -F'/' '{print $1"//"$2"/"$3"/"$4}'`
		spec=${BB_TMP_BASE}/$spec_name
		
		if [ ! -f $spec ]
		then
			error_log "download spec error, $spec_url"
			continue
		fi

		echo "PN = \"${package_name}\"" > $bbfile

		gen_single_line_config $spec $bbfile "Summary:" "DESCRIPTION"
		gen_single_line_config $spec $bbfile "URL:" "HOMEPAGE"
		gen_license $spec $bbfile
		gen_single_line_config $spec $bbfile "Version:" "PV"
		echo "" >> $bbfile

		echo "inherit pypi setuptools3" >> $bbfile
		if [ "$package_type" == "" ]
		then
			echo "" >> $bbfile
			echo "PYPI_PACKAGE = \"${package_name}\"" >> $bbfile
			echo "" >> $bbfile
		fi

		echo "OPENEULER_GIT_URL = \"${git_url}\"" >> $bbfile
		echo "OPENEULER_REPO_NAME = \"${repo}\"" >> $bbfile
		echo 'OPENEULER_LOCAL_NAME = "${OPENEULER_REPO_NAME}"' >> $bbfile
		echo "OPENEULER_BRANCH = \"${branch}\"" >> $bbfile
		echo "" >> $bbfile

		echo "SRC_URI = \" \\" >> $bbfile
		if [ "$source_name" == "" ]
		then
			src_name=`grep "Source0:" $spec | head -1 | awk '{print $2}'`
		else
			src_name=$source_name
		fi
		echo "    file://\${OPENEULER_LOCAL_NAME}/${src_name} \\" >> $bbfile

		for patch in `grep "^Patch.*: " $spec | awk '{print $2}'`
		do
			echo "    file://\${OPENEULER_LOCAL_NAME}/${patch} \\" >> $bbfile
		done

		echo "\"" >> $bbfile
		echo 'S = "${WORKDIR}/${PN}-${PV}"' >> $bbfile
		echo "" >> $bbfile

		echo "DEPENDS += \" \\" >> $bbfile
		grep "^BuildRequires:" $spec | awk '{print $2}' | sed -e 's#$#-native \\#g' -e 's#^#    #g' >> $bbfile
		echo "\"" >> $bbfile
		echo "" >> $bbfile

		echo "RDEPENDS_\${PN} += \" \\" >> $bbfile
		grep "^Requires:" $spec | awk '{print $2}' | sed -e 's#$# \\#g' -e 's#^#    #g' >> $bbfile
		echo "\"" >> $bbfile
		echo "" >> $bbfile

		if [ "$is_native" == "yes" ]
		then
			echo "BBCLASSEXTEND = \"native nativesdk\"" >> $bbfile
		else
			echo "BBCLASSEXTEND = \"native\"" >> $bbfile
		fi
        done < ${SPEC_TO_BB_LIST}

        info_log "Gen bb files done, you can find it in ${ROS_BB_BASE}"
}

main $*
