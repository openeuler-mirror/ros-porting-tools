#!/bin/bash

. base.sh

act=$1
GITEE_TOKEN=$2

GITEE_URL=git@gitee.com
GITEE_BASE=${OUTPUT}/gitee
GITEE_PUSH_LIST=${GITEE_BASE}/push.list

prepare()
{
	if [ "$act" == "" -o "$GITEE_TOKEN" == "" ]
	then
		echo "Usage:"
		echo "    ./$0 [fork|clone|commit|pr|merge] gitee_token"
		echo ""
		exit 1
	fi

	if [ ! -f ${ROS_PROJECTS_NAME} ]
	then
		error_log "Please give the source repo path of ros"
		exit 1
	fi

	mkdir -p ${GITEE_BASE}
}

fork_projects()
{
	while read project
	do
		echo "start to fork project $project"
		grep -q "^${project}$" ${OUTPUT}/.has_forked && continue
		echo curl -X POST --header \''Content-Type:application/json;charset=UTF8'\' \'https://gitee.com/api/v5/repos/${GITEE_ORG}/${project}/forks\' -d \''{"access_token":"'${GITEE_TOKEN}'","name":"openEuler_'${project}'","path":"openEuler_'${project}'"}'\' >${OUTPUT}/.post
		bash ${OUTPUT}/.post 1>/dev/null 2>&1
		if [ $? -ne 0 ]
		then
			error_log "fail to fork project $project"
			exit 1
		fi

		echo $project >>${OUTPUT}/.has_forked

	done < ${ROS_PROJECTS_NAME}
}

clone_projects()
{
	info_log "Start to clone projects from $GITEE_URL"

	while read project
	do
		project=openEuler_${project}
		info_log "start clone project ${project}"
		
		if [ -d ${GITEE_BASE}/${project}/.git ]
		then
			cd ${GITEE_BASE}/${project}
			git pull origin ${ROS_DISTRO}
			continue
		fi

		cd ${GITEE_BASE}
		git clone https://${GITEE_DOMAIN}/will_niutao/${project}.git
		if [ $? -ne 0 ]
		then
			error_log "fail to clone project ${project}"
			continue
		fi
		cd ${project}
		git branch -a | grep "/${OPENEULER_DEV_BRANCH}"
		if [ $? -eq 0 ]
		then
			git checkout ${OPENEULER_DEV_BRANCH}
		else
			error_log "no ros branch ${OPENEULER_DEV_BRANCH}"
			echo $project ${OPENEULER_DEV_BRANCH} >> ${OUTPUT}/gitee/no_branch
		fi

		git branch -a | grep "/${OPENEULER_SP_BRANCH}"
		if [ $? -ne 0 ]
		then
			error_log "no ros branch ${OPENEULER_SP_BRANCH}"
			echo $project ${OPENEULER_SP_BRANCH} >> ${OUTPUT}/gitee/no_branch
		fi
		git branch -a | grep "/${OPENEULER_NEXT_BRANCH}"
		if [ $? -ne 0 ]
		then
			error_log "no ros branch ${OPENEULER_NEXT_BRANCH}"
			echo $project ${OPENEULER_NEXT_BRANCH} >> ${OUTPUT}/gitee/no_branch
		fi

	done < ${ROS_PROJECTS_NAME}

	info_log "clone project ok"
}

commit_projects()
{
	info_log "Start to commit projects from $GITEE_URL"

	rm -f ${GITEE_PUSH_LIST}

	while read project
	do
		fork_project=openEuler_${project}
		info_log "start commit project ${project}"

		cd ${OUTPUT}/gitee/${fork_project}

		rm -rf *
		git checkout -- README.md README.en.md
		git checkout -- *.yaml 2>/dev/null
		cp ${OUTPUT}/repo/${project}/* .
		git status | grep -qE "modified:|Untracked|deleted:"
		if [ $? -ne 0 ]
		then
			#info_log "nothing changed of project $project, continue"
			continue
		fi
		#git status
		#continue

		git add -A *
		git add -u
		git status

		git commit -s -m "upload ROS ${ROS_DISTRO} package on `date`"
		git push origin ${OPENEULER_DEV_BRANCH}:${OPENEULER_DEV_BRANCH}
		if [ $? -ne 0 ]
		then
			error_log "fail to push project ${project}"
			continue
		fi

		echo ${fork_project} >> ${GITEE_PUSH_LIST}

	done < ${ROS_PROJECTS_NAME}

	info_log "commit project ok"
}


create_pr_projects()
{
	rm -f ${OUTPUT}/.has_create_pr
	while read project
	do
		pkg=`echo $project | sed -s "s#openEuler_##g"`
		echo "start to create pr for project $project"
		grep -q "^${project}$" ${OUTPUT}/.has_create_pr && continue
		echo curl -X POST --header \''Content-Type:application/json;charset=UTF8'\' \'https://gitee.com/api/v5/repos/${GITEE_ORG}/${pkg}/pulls\' -d \''{"access_token":"'${GITEE_TOKEN}'","title":"Upload ROS '${ROS_DISTRO}'","head":"will_niutao:'${OPENEULER_DEV_BRANCH}'","base":"'${OPENEULER_DEV_BRANCH}'"}'\' >${OUTPUT}/.post
		bash ${OUTPUT}/.post >${OUTPUT}/.pr
		if [ $? -ne 0 ]
		then
			error_log "fail to fork project $project"
			exit 1
		fi
		
		pr_id=`cat ${OUTPUT}/.pr  | sed -s "s#,#\n#g" | grep html_url | grep pulls | awk -F"/pulls/" '{print $2}' | cut -d'"' -f1`
		echo curl -X POST --header \''Content-Type:application/json;charset=UTF8'\' \'https://gitee.com/api/v5/repos/${GITEE_ORG}/${pkg}/pulls/${pr_id}/comments\' -d \''{"access_token":"'${GITEE_TOKEN}'","body":"/sync '${OPENEULER_NEXT_BRANCH} ${OPENEULER_SP_BRANCH}'"}'\' >${OUTPUT}/.post
		bash ${OUTPUT}/.post >${OUTPUT}/.pr


		echo $project >>${OUTPUT}/.has_create_pr

	done < ${GITEE_PUSH_LIST}

	info_log "commit project ok"
}

auto_merge_pr()
{
	while read pkg
	do
		echo "start to get pr for project $project"
		echo curl -X GET --header \''Content-Type:application/json;charset=UTF8'\' \''https://gitee.com/api/v5/repos/'${GITEE_ORG}'/'${pkg}'/pulls?access_token='${GITEE_TOKEN}'&state=open&sort=created&direction=desc&page=1&per_page=20'\' >${OUTPUT}/.post
		bash ${OUTPUT}/.post >${OUTPUT}/.pr
		if [ $? -ne 0 ]
		then
			error_log "fail to fork project $project"
			exit 1
		fi
		
		pr_id=`cat ${OUTPUT}/.pr  | sed -s "s#,#\n#g" | grep html_url | grep pulls | awk -F"/pulls/" '{print $2}' | cut -d'"' -f1`
		for pr in $pr_id
		do
			echo curl -X POST --header \''Content-Type:application/json;charset=UTF8'\' \'https://gitee.com/api/v5/repos/${GITEE_ORG}/${pkg}/pulls/${pr}/comments\' -d \''{"access_token":"'${GITEE_TOKEN}'","body":"/lgtm"}'\' >${OUTPUT}/.post
			bash ${OUTPUT}/.post >${OUTPUT}/.pr

			sleep 5

			echo curl -X POST --header \''Content-Type:application/json;charset=UTF8'\' \'https://gitee.com/api/v5/repos/${GITEE_ORG}/${pkg}/pulls/${pr}/comments\' -d \''{"access_token":"'${GITEE_TOKEN}'","body":"/approve"}'\' >${OUTPUT}/.post
			bash ${OUTPUT}/.post >${OUTPUT}/.pr
		done
	done < ${GITEE_PUSH_LIST}

	info_log "merge project ok"
}

main()
{
	prepare

	case $act in
	"fork")
		fork_projects
	;;
	"clone")
		clone_projects
	;;
	"commit")
		commit_projects
	;;
	"pr")
		create_pr_projects
	;;
	"merge")
		auto_merge_pr
	;;
	*)
		echo "Usage:"
		echo "    ./$0 [fork|clone|commit|pr|merge] gitee_token"
		echo ""
	;;
	esac
}
main $*
