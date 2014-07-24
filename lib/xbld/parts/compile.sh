if [ ! -f "${WORKDIR}/.configured" ]
then
	die "package not configured yet!"
fi
if [ ! -f "${WORKDIR}/.compiled" ]
then
	src_compile || die "compile failed!"
	touch "${WORKDIR}/.compiled"
else
	einfo "package already compiled, to force this operation"
	einfo "delete file ${WORKDIR}/.compiled"
fi
