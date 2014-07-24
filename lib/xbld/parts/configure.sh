if [ ! -f "${WORKDIR}/.prepared" ]
then
	die "package not prepared yet!"
fi
if [ ! -f "${WORKDIR}/.configured" ]
then
	src_configure || die "configure failed!"
	touch "${WORKDIR}/.configured"
else
	einfo "package already configured, to force this operation"
	einfo "delete file ${WORKDIR}/.configured"
fi
