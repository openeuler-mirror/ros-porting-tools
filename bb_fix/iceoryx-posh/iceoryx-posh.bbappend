FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/iceoryx/cpptoml-0.1.1.tar.gz ${S}/cmake/cpptoml
}
