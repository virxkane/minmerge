# prepare build process
mmkdir "${WORKDIR}" || eerror "Can't create \"workdir\""
cd "${WORKDIR}" || eerror "Can't chdir to \"workdir\""
mkdir "${WORKDIR_TEMP}" || eerror "Can't create temp dir"

src_unpack || die "unpack failed!"
