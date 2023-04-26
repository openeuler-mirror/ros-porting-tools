#!/bin/bash

. base.sh

ROS_PROJECTS_LIST=${ROOT}/${ROS_DISTRO}/ros-projects.list
ROS_VERSION_FIX=${ROOT}/${ROS_DISTRO}/ros-version-fix
ROS_REPOS=${OUTPUT}/ros.repos
ROS_REPOS_URL=${OUTPUT}/ros.url

project_version_fix()
{
	project=$1
	org_version=$2

	if [ ! -f ${ROS_VERSION_FIX} ]
	then
		echo $org_version
		return 0
	fi

	while read p fix_version
	do
		if [ "$p" = "$project" ]
		then
			echo $fix_version
			return 0
		fi
	done < ${ROS_VERSION_FIX}

	echo $org_version
	return 0
}

main()
{
	if [ ! -f ${ROS_PROJECTS_LIST}  ]
	then
		error_log "can not find ${ROS_PROJECTS_LIST}"
		exit 1
	fi

	info_log "find ${ROS_PROJECTS_LIST}"

	> ${ROS_PKG_LIST}
	> ${ROS_REPOS_URL}
	> ${ROS_PROJECTS_NAME}
	echo "repositories:" >${ROS_REPOS}

	while read pkg url status version
	do
		if [ "$pkg" = "" ]
		then
			continue
		fi

		if [ "$status" = "disabled" -o "$status" = "unknown" ]
		then
			info_log "$pkg is unknown or disabled, ignore"
			continue
		fi

		echo $url | grep -q "^https://github.com"
		if [ "$?" -eq 0 ]
		then
			echo $url | grep -q ".git$"
			if [ "$?" -eq 0 ]
			then
				project_name=`echo $url | awk 'BEGIN {FS="\\\.git"} {print $1}' | awk -F"/" '{print $NF}'`
				tree=master
				new_url=$url
			else
				project_name=`echo $url | awk -F"/tree/" '{print $1}' | awk -F"/" '{print $NF}'`
				tree=`echo $url | awk -F"/tree/" '{print $2}'`
				new_url=`echo $url | awk -F"/tree/" '{print $1}'`.git
			fi
		fi

		echo $url | grep -q "^https://gitlab.com"
		if [ "$?" -eq 0 ]
		then
			echo $url | grep -q ".git$"
			if [ "$?" -eq 0 ]
			then
				project_name=`echo $url | awk 'BEGIN {FS="\\\.git"} {print $1}' | awk -F"/" '{print $NF}'`
				tree=main
				new_url=$url
			else
				echo $url | grep -q "/tree"
				if [ "$?" -ne 0 ]
				then
					project_name=`echo $url | awk -F"/" '{print $NF}'`
					tree=main
					new_url=${url}.git
				fi
			fi
		fi

		echo $url | grep -q "^https://bitbucket.org"
		if [ "$?" -eq 0 ]
		then
			echo $url | grep -q ".git$"
			if [ "$?" -eq 0 ]
			then
				project_name=`echo $url | awk 'BEGIN {FS="\\\.git"} {print $1}' | awk -F"/" '{print $NF}'`
				tree=master
				new_url=$url
			fi
		fi

		if [ "$project_name" = "" -o "${new_url}" = "" -o "$version" = "" ]
		then
			error_log "Faild to analyse $pkg $url $new_url $version"
			exit 1
		fi

		echo -e "$pkg\t$project_name\t$version" >> ${ROS_PKG_LIST}

		grep -Fq "$new_url" ${ROS_REPOS_URL}
		if [ $? -eq 0 ]
		then
			continue
		fi

		echo "$new_url" >> ${ROS_REPOS_URL}
		echo "$project_name" >> ${ROS_PROJECTS_NAME}

		fix_version=`project_version_fix $project_name $tree`

		echo "  $project_name:" >> ${ROS_REPOS}
		echo "    type: git" >> ${ROS_REPOS}
		echo "    url: $new_url" >> ${ROS_REPOS}
		echo "    version: $fix_version" >> ${ROS_REPOS}

		echo -n "."
	done < ${ROS_PROJECTS_LIST}

	info_log "Gen ros.repos done, you can find it in ${ROS_REPOS}"
}

main
