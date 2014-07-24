if [ ! -f "${WORKDIR}/.unpacked" ]
then
	die "package not unpacked yet!"
fi
if [ ! -f "${WORKDIR}/.prepared" ]
then
	src_prepare || die "prepare failed!"
	touch "${WORKDIR}/.prepared"
else
	einfo "package already prepared, to force this operation"
	einfo "delete file ${WORKDIR}/.prepared"
fi
