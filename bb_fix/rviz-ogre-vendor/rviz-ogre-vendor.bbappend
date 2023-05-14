FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/rviz/ogre-rm-Media-1.12.1.tar.gz ${S}/
}
