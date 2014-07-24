if [ ! -f "${WORKDIR}/.compiled" ]
then
	die "package not compiled yet!"
fi
if [ ! -f "${WORKDIR}/.installed" ]
then
	src_install || die "install failed!"
	make_tmpcontent
	# strip executables/libraries
	if echo "${RESTRICT}" | grep "strip" > /dev/null 2>&1
	then
		:
	else
		strip_package
	fi
	touch "${WORKDIR}/.installed"
else
	einfo "package already installed, to force this operation"
	einfo "delete file ${WORKDIR}/.installed"
fi
