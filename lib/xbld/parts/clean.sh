if [ -d "${WORKDIR}" ]
then
	ebegin "Cleaning \"${WORKDIR}\" ... "
	cd "${TMPDIR}"
	rm -rf "${WORKDIR}"
	if [ $? -eq 0 ]
	then
		eend "OK"
	else
		eerror "failed"
	fi
fi
