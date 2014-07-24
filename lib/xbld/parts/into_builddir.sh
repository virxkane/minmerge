# use only for this commands: configure, compile, test, install
if [ ! -d "${WORKDIR}" ]
then
	mmkdir "${WORKDIR}" || eerror "Can't create \"workdir\""
fi
cd "${WORKDIR}" || eerror "Can't chdir to \"workdir\""
if [ ! -d "${WORKDIR_TEMP}" ]
then
	mkdir "${WORKDIR_TEMP}" || eerror "Can't create temp dir"
fi

if [ "x${USE_CMAKE}" = "xyes" ]
then
	BUILD_IN_SEPARATE_DIR=yes
fi

if [ "x${BUILD_IN_SEPARATE_DIR}" = "xyes" ]
then
	if [ ! -d "${WORKDIR}/${PF}-build" ]
	then
		mkdir "${WORKDIR}/${PF}-build" || eerror "Can't create directory ${WORKDIR}/${PF}-build"
	fi
	cd "${WORKDIR}/${PF}-build"
else
	cd "${SOURCES_DIR}" || eerror "Can't cd to sources directory!"
fi
