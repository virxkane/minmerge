
einfo "Extracting binary package..."

PKG="${PKGDIR}/${PF}.pkg.tar.xz"
PKG0="${PF}.pkg.tar"

if [ ! -d "${WORKDIR}" ]
then
	mkdir -p "${WORKDIR}" || eerror "Can't create \"workdir\""
fi
if [ ! -d "${WORKDIR_TEMP}" ]
then
	mkdir "${WORKDIR_TEMP}" || eerror "Can't create temp dir"
fi

if [ ! -d "${WORKDIR}/image" ]
then
	mkdir "${WORKDIR}/image" || eerror "Can't create \"${WORKDIR}/image\""
fi
cd "${WORKDIR}/image" || eerror "Can't chdir to \"${WORKDIR}/image\""

# unpack first stream with package content
# --single-stream key ommited in xz 5.0.3
xz -dk --stdout "${PKG}" | tar -xp || eerror "Extract failed!"

# extract metadata
cd "${WORKDIR_TEMP}" || eerror "Can't chdir to \"${WORKDIR_TEMP}\""
# '\s' work incorrect in grep 2.5 using '[[:space:]]'
offset=`xz -lv --robot "${PKG}" | grep -e '^stream[[:space:]]\+2[[:space:]]\+1[[:space:]]\+[[:digit:]]\+[[:space:]]\+.*$' | cut -f 4`
offset=`echo ${offset} | grep '[0-9]\+'`
if [ "x${offset}" = "x" ]
then
	eerror "Can't detect second stream in binary package archive!"
fi
dd if="${PKG}" of="temp.tar.xz" bs=1 skip=${offset} > /dev/null 2>&1
tar -xJf "temp.tar.xz" || eerror "Extract metadata failed!"
rm -f "temp.tar.xz"
