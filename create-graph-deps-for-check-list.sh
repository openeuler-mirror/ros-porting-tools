#!/bin/bash

. base.sh

ROS_CHECK_LIST=${ROOT}/ros-check.list
ROS_GRAPH_BASE=${OUTPUT}/graph
ROS_BUILD_STATUS=${OUTPUT}/ros-build-status.list

prepare()
{
	if [ ! -f ${ROS_PKG_LIST} ]
	then
		error_log "Can not find ${ROS_PKG_LIST}, you can use get-repo-list.sh to create it"
		exit 1
	fi

	if [ ! -f ${ROS_BUILD_STATUS} ]
	then
		error_log "Please give the ${ROS_CHECK_LIST}"
		exit 1
	fi

	if [ ! -d ${ROS_REPO_BASE} ]
	then
		error_log "Ros repo bae not found"
		exit 1
	fi

	mkdir -p ${ROS_GRAPH_BASE}
	rm -rf ${ROS_GRAPH_BASE}/*

}

get_deps()
{
	is_more=$1
	out_file=$2

	if [ "$is_more" == "1" ]
	then
		grep -F " -" ros.dot | awk -F"->" '{print $2}' | sort >.ros.deps
	else
		grep -F " -" ros.dot | awk -F"->" '{print $1}' | sort >.ros.deps
	fi

	cat .ros.deps | uniq >ros.deps
	>.ros.imp
	for i in `cat ros.deps`
	do
		if [ "$is_more" == "1" ]
		then
			n=`grep -P "$i\$" .ros.deps | wc -l`
		else
			n=`grep -P "^$i " .ros.deps | wc -l`
		fi
		pkg=`echo $i | sed -e "s#_#-#g" | sed -e "s#ros-${ROS_DISTRO}-##g"`
		s=`grep -P "^$pkg\t" ${ROS_BUILD_STATUS} | awk '{print $2}'`
		[ "$s" == "succeeded" ] && continue

		printf "%03d %s\n" $n $i >>.ros.imp
	done
	cat .ros.imp | sort >$out_file
}

main()
{
	prepare

	info_log "Start to analyse ros-pkg."

	cd ${ROS_GRAPH_BASE}

	find ${ROS_REPO_BASE} -name "*.spec" >.all_spec

	>.succeeded.list

	while read project status
	do
		if [ "$status" == "succeeded" ]
		then
			echo "$project" >>.succeeded.list
			continue
		fi

		s=`grep -F "/${project}.spec" .all_spec`

		[ "$s" == "" ] && continue
		cp $s ${ROS_GRAPH_BASE}
	done < ${ROS_BUILD_STATUS}

	ls *.spec | xargs sed -i '/ros-%{ros_distro}-ros-workspace/d'
	ls *.spec | xargs sed -i "s#%{ros_distro}#${ROS_DISTRO}#g"
	ls *.spec | xargs sed -i "s#^BuildRequires:#Requires:#g"

	for i in `ls *.spec`
	do
		n=`grep " RosPkgName" $i | awk '{print $3}'`
		sed -i "s#%{RosPkgName}#$n#g" $i
	done

	if [ -f ${ROS_OUTPUT_TMP}/.build_succeeded ]
	then
		for i in `cat ${ROS_OUTPUT_TMP}/.build_succeeded`
		do
			sed -i "/Requires: $i$/d" *.spec
		done
	fi

	rpm_spec_dependency_analyzer --output ros.dot *.spec

	sed -i "/GraphicsMagick_c/d" ros.dot

	while read project
	do
		sed -i "/$project$/d" ros.dot
	done < .succeeded.list

	get_deps 1 ros.deps.more
	get_deps 0 ros.deps.less

	cp ros.dot .ros.dot
	sed -i "s#-#_#g" .ros.dot
	sed -i 's#_>#->#g' .ros.dot
	dot -Tsvg .ros.dot -o ros.svg

	info_log "get status of projects ok"
}

main $*
