if [ ! -f "${WORKDIR}/.installed" ]
then
	die "package not installed yet!"
fi
merge || die "merge failed!"
# then remove early installed version of this package if exists
# excluding modified (i.e. new) files.
if [ "x${INST_XBUILD}" != "x" ]
then
	for _xbuild in ${INST_XBUILD}
	do
		echo "_xbuild=$_xbuild"

		pkg_info=(`inst_pkg_version_info "${_xbuild}"`)
		_cat=${pkg_info[0]}
		_pn=${pkg_info[1]}
		_pv=${pkg_info[2]}
		_pr=${pkg_info[3]}
		if [ "x${_pr}" = "x" ]
		then
			_pvr="${_pv}"
		else
			_pvr="${_pv}-${_pr}"
		fi
		_p=${_pn}-${_pv}
		_pf=${_pn}-${_pvr}

		einfo "Safely unmerging already-installed instance of ${_cat}/${_pf}..."
		remove_pkg "${_cat}/${_pf}" 0 || die
	done
fi
make_content || die
cp "${XBUILD}" "${PKGDBDIR}/" || die
