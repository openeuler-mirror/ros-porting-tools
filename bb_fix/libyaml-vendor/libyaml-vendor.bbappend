FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/libyaml_vendor/libyaml-0.2.5.tar.gz ${S}/
}
