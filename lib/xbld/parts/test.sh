if [ ! -f "${WORKDIR}/.compiled" ]
then
	die "package not compiled yet!"
fi
if [ ! -f "${WORKDIR}/.tested" ]
then
	src_test || die "test failed!"
	touch "${WORKDIR}/.tested"
else
	einfo "package already tested, to force this operation"
	einfo "delete file ${WORKDIR}/.tested"
fi
