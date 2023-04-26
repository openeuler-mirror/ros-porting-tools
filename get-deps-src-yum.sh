#!/bin/bash

. base.sh

ROS_DEPS_SRC=${OUTPUT}/ros-deps-src.list
ROS_DEPS_YUM=${OUTPUT}/ros-deps-yum.list

prepare()
{
        if [ ! -f ${ROS_DEPS_SRC} ]
        then
                error_log "Can not find ${ROS_DEPS_SRC}, you can use get-deps-src.sh to create it"
                exit 1
        fi

        cat /etc/os-release | grep -q openEuler
        if [ $? -ne 0 ]
        then
                error_log "Please run me in openEuler system"
                exit 1
        fi

        >${ROS_DEPS_YUM}
}

main()
{
        prepare

        info_log "Start to analyse ros-pkg."

        while read pkg src
        do
                info_log "Analyse $pkg"
                if [ "$src" = "" ]
                then
                        src="NULL"
                fi

                yum search $pkg >${OUTPUT}/.yum 2>/dev/null

                grep -Rq "^$pkg\." ${OUTPUT}/.yum
                if [ $? -eq 0 ]
                then
                        echo -e "$pkg\t$src\t$pkg" >>${ROS_DEPS_YUM}
                        continue
                fi

                devel=`echo "$pkg" | sed "s/-dev$/-devel/g"`
                yum search $devel >${OUTPUT}/.yum 2>/dev/null
                grep -Rq "^$devel\." ${OUTPUT}/.yum
                if [ $? -eq 0 ]
                then
                        echo -e "$pkg\t$src\t$devel" >>${ROS_DEPS_YUM}
                        continue
                fi

                lib=`echo "$devel" | sed "s/^lib//g"`
                yum search $lib >${OUTPUT}/.yum 2>/dev/null
                grep -Rq "^$lib\." ${OUTPUT}/.yum
                if [ $? -eq 0 ]
                then
                        echo -e "$pkg\t$src\t$lib" >>${ROS_DEPS_YUM}
                        continue
                fi

                echo -e "$pkg\t$src\t" >>${ROS_DEPS_YUM}

        done < ${ROS_DEPS_SRC}


        info_log "Gen ros-deps-yum.list done, you can find it in ${ROS_DEPS_YUM}"
}

main $*