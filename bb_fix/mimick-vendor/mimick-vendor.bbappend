FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/cpptoml/* \
"
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/mimick_vendor/Mimick-de11f8377eb95f932a03707b583bf3d4ce5bd3e7.tar.gz ${S}/
	cp ${OPENEULER_SP_DIR}/mimick_vendor/0-Mimick-remove-compile-flag-o0.patch ${S}/
}
