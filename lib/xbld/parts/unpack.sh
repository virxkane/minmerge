if [ ! -f "${WORKDIR}/.unpacked" ]
then
	# prepare build process
	test -d "${WORKDIR}" && cleanup
	mmkdir "${WORKDIR}" || eerror "Can't create \"workdir\""
	cd "${WORKDIR}" || eerror "Can't chdir to \"workdir\""
	mkdir "${WORKDIR_TEMP}" || eerror "Can't create temp dir"

	src_unpack || die "unpack failed!"
	touch "${WORKDIR}/.unpacked"
else
	einfo "package already unpacked, to force this operation"
	einfo "delete file ${WORKDIR}/.unpacked"
fi
