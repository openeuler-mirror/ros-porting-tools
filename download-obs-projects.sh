#!/bin/bash

. base.sh

USER_INFO="$1"
OBS_PACKAGES_LIST=${OUTPUT}/obs-packages.list
OBS_BASE=${OUTPUT}/obs

prepare()
{
	if [ "$USER_INFO" == "" ]
	then
		echo "Usage:"
		echo "    ./$0 user:pass"
		echo ""
		exit 1
	fi

	mkdir -p ${OBS_BASE}
}

main()
{
	prepare

	info_log "Start to download obs projects."
	cd ${OBS_BASE}
	osc list  /${OBS_PROJECT} >${OBS_PACKAGES_LIST}

	while read pkg
	do
		info_log "start checkout package $pkg"
		osc co ${OBS_PROJECT}/$pkg
		[ $? -ne 0 ] && log_error "Checkout package $pkg error"
	done < ${OBS_PACKAGES_LIST}

	info_log "get status of projects ok"
}

main $*
