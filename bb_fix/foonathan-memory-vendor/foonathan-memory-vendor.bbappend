FILES:${PN}:prepend = " \
    ${ros_prefix}/lib/foonathan_memory/* \
"
export OPENEULER_SP_DIR
do_configure:prepend() {
	cp ${OPENEULER_SP_DIR}/foonathan_memory_vendor/memory-0.7-1.tar.gz ${S}
}
