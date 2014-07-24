if [ ! -f "${WORKDIR}/.installed" ]
then
	die "package not installed yet!"
fi
make_package || die "package failed!"
