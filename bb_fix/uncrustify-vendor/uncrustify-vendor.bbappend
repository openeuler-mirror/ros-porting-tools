FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/uncrustify_vendor/uncrustify-0.72.0.tar.gz ${S}/
}
