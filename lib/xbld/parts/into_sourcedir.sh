if [ ! -d "${WORKDIR}" ]
then
	mmkdir "${WORKDIR}" || eerror "Can't create \"workdir\""
fi
cd "${WORKDIR}" || eerror "Can't chdir to \"workdir\""
if [ ! -d "${WORKDIR_TEMP}" ]
then
	mkdir "${WORKDIR_TEMP}" || eerror "Can't create temp dir"
fi

cd "${SOURCES_DIR}" || eerror "Can't cd to sources directory!"
