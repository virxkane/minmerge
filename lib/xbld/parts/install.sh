if [ ! -f "${WORKDIR}/.compiled" ]
then
	die "package not compiled yet!"
fi
if [ ! -f "${WORKDIR}/.installed" ]
then
	src_install || die "install failed!"
	touch "${WORKDIR}/.installed"
else
	einfo "package already installed, to force this operation"
	einfo "delete file ${WORKDIR}/.installed"
fi
