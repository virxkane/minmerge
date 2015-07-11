
einfo "Make package archive..."

PKG="${PKGDIR}/${PF}.pkg.tar.xz"

pwd1=`cd`
cd "${INSTDIR}" || die "chdir to ${INSTDIR} failed!"
tar -cvJpf "${PKG}" . || die "tar failed!"
cd "${WORKDIR_TEMP}" || die "chdir to ${WORKDIR_TEMP} failed!"
tar -cJf "${WORKDIR}/temp.tar.xz" * || die "tar failed!"
cat "${WORKDIR}/temp.tar.xz" >> "${PKG}"
rm -f "${WORKDIR}/temp.tar.xz"
cd "$pwd1" || die "chdir to ${INSTDIR} failed!"
