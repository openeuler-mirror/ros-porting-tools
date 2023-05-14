FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/ignition_math6_vendor/ignition-math6_6.9.2.tar.gz ${S}/
}
