#!/bin/sh
# Copyright 2010-2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

# All needed variables defined in defaults.conf and make.conf
# Also:
# following variables must be declared in xbuild file
#  SRC_URI

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig

export CHOST
export CFLAGS
export CXXFLAGS

FILESDIR="${PORTDIR}/${CATEGORY}/${PN}/files"
WORKDIR="${TMPDIR}/${PN}-build"
WORKDIR_TEMP="${WORKDIR}/temp"
INSTDIR="${WORKDIR}/image"
PKGDBBASE="${PREFIX}/var/db/pkg"
PKGDBDIR="${PKGDBBASE}/${CATEGORY}/${PF}"
PKGCONT="${PKGDBDIR}/CONTENTS"
TMPCONT="${WORKDIR_TEMP}/tmpcont"
PKG="${PKGDIR}/${PF}.bin.tar.xz"
DISTDIRS="${DISTDIR} ${DISTDIR2} ${DISTDIR3} ${DISTDIR4} ${DISTDIR5}
			${DISTDIR6} ${DISTDIR7} ${DISTDIR8} ${DISTDIR9}"

A=""
for uri in ${SRC_URI}
do
	A="${A} "`basename ${uri}`
done
unset -v uri

w32path_posix()
{
#	local mingw_w32path=`mount | grep '/mingw ' | head -n 1 | cut -f 1 -d ' ' | sed -e 's/\\\/\\\\\//' | tr A-Z a-z`
#	local usr_w32path=`mount | grep '/usr ' | head -n 1 | cut -f 1 -d ' ' | sed -e 's/\\\/\\\\\//' | tr A-Z a-z`
#	local msys_w32path=`mount | grep '/msys ' | head -n 1 | cut -f 1 -d ' ' | sed -e 's/\\\/\\\\\//' | tr A-Z a-z`
#	local tmp=`echo "$1" | sed -e "s/^${mingw_w32path}/\/mingw/"`
#	if [ "${tmp}" = "$1" ]
#	then
#		tmp=`echo "$1" | sed -e "s/^${usr_w32path}/\/usr/"`
#		if [ "${tmp}" = "$1" ]
#		then
#			tmp=`echo "$1" | sed -e "s/^${msys_w32path}/\/msys/"`
#		fi
#	fi
#	echo "${tmp}"
	local pwd1=`pwd`
	cd "$1"
	if [ $? -eq 0 ]
	then
		pwd
		cd ${pwd1}
	else
		echo ""
		die "Can't cd to $1"
	fi
}

posix_w32path()
{
	local pwd1=`pwd`
	cd "$1"
	if [ $? -eq 0 ]
	then
		pwd -W
		cd ${pwd1}
	else
		echo ""
		die "Can't cd to $1"
	fi
}

# create all components of path
mmkdir()
{
	install -d $1
}

is_sf_net()
{
	echo $1 | grep "^http://sourceforge.net/.*" > /dev/null 2>&1
	return $?
}

fetch()
{
	if echo "${RESTRICT}" | grep "fetch" > /dev/null 2>&1
	then
		die "fetch restricted!"
		return
	fi
	local pwd1=`pwd`
	local afile=$1
	test "x${afile}" = "x" && die "Invalid URL!"
	cd ${DISTDIR} || die "Can't cd to ${DISTDIR}!"
	local tmp_url=
	local tmp_afile=
	local url=
	if echo "${RESTRICT}" | grep "mirror" > /dev/null 2>&1
	then
		for tmp_url in ${SRC_URI}
		do
			tmp_afile=`basename ${tmp_url}`
			if test "x${tmp_afile}" = "x${afile}"
			then
				url=${tmp_url}
			fi
		done
		if is_sf_net "${url}"
		then
			url="${url}/download"
		fi
		wget -t 3 -N "${url}"
		if test $? -ne 0
		then
			die "fetch ${afile} failed!"
		fi
	else
		local mirror=
		local mirror_ind=1
		local mirrors_count=0
		local ind=1
		for mirror in ${SOURCE_MIRRORS}
		do
			mirrors_count=`expr ${mirrors_count} + 1`
		done
		for mirror in ${SOURCE_MIRRORS}
		do
			break
		done
		local url=${mirror}/distfiles/${afile}
		local last_url="no"
		while test "x${url}" != "x"
		do
			wget -t 3 -N "${url}"
			if test $? -eq 0
			then
				url=""
			else
				if test "x${last_url}" = "xyes"
				then
					die "fetch ${afile} failed!"
				fi
				if test ${mirror_ind} -lt ${mirrors_count}
				then
					ind=1
					for mirror in ${SOURCE_MIRRORS}
					do
						if test ${ind} -gt ${mirror_ind}
						then
							mirror_ind=${ind}
							break
						fi
						ind=`expr ${ind} + 1`
					done
					url=${mirror}/distfiles/${afile}
				else
					if test "x${last_url}" == "xyes"
					then
						url=""
					else
						for tmp_url in ${SRC_URI}
						do
							tmp_afile=`basename ${tmp_url}`
							if test "x${tmp_afile}" = "x${afile}"
							then
								url=${tmp_url}
								if is_sf_net "${url}"
								then
									url="${url}/download"
								fi
								last_url="yes"
							fi
						done
					fi
				fi
			fi
		done
	fi
	cd ${pwd1} || die "Can't return to last current directory!"
}

check_files()
{
	local afile=
	local adir=
	local found=
	for afile in $A
	do
		found=0
		for adir in $DISTDIRS
		do
			if [ -f ${adir}/${afile} ]
			then
				local afile_sz=`ls -l ${adir}/${afile} | awk '{print $5}'`
				if [ ${afile_sz} -ge 0 ]
				then
					found=1
				fi
			fi
		done
		if [ $found -eq 0 ]
		then
			fetch ${afile}
		fi
	done
	return 0
}

find_srcpackage()
{
	local tmp=""
	local f=""
	local adir=""
	for adir in $DISTDIRS
	do
		tmp="${adir}/$1"
		if [ -e "${tmp}" ]
		then
			f="${tmp}"
		fi
	done
	echo ${f}
}

unpack_tar()
{
	ebegin "Unpacking $1 ... "
	local f=`find_srcpackage $1`
	local fm=$2
	local ign=$3
	#tar -xjf $f > ${LOGFILE} 2>&1
	tar ${fm} --no-same-owner -xf "${f}" > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		eend "OK"
	else
		if [ "x$ign" = "xign" ]
		then
			eend "error(s) in archive, ignoring."
		else
			eerror "failed"
		fi
	fi
}

unpack_zip()
{
	ebegin "Unpacking $1 ... "
	local tmp=""
	local f=""
	local adir=""
	for adir in $DISTDIRS
	do
		tmp="${adir}/$1"
		if [ -e "${tmp}" ]
		then
			f="${tmp}"
		fi
	done
	unzip "${f}" > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		eend "OK"
	else
		eerror "failed"
	fi
}

unpack_copy()
{
	ebegin "Unpacking $1 ... "
	local tmp=""
	local f=""
	local adir=""
	local ret=1
	for adir in $DISTDIRS
	do
		tmp="${adir}/$1"
		if [ -e "${tmp}" ]
		then
			f="${tmp}"
		fi
	done
	cp -p "${f}" .
	if [ $? -eq 0 ]
	then
		eend "OK"
		ret=0
	else
		eerror "failed"
	fi
	return $ret
}

unpack_one()
{
	case $1 in
		*.tar.lzma)
			unpack_tar $1 --lzma $2
			;;
		*.tar.bz2|*.tbz2)
			unpack_tar $1 --bzip2 $2
			;;
		*.tar.gz|*.tgz)
			unpack_tar $1 --gzip $2
			;;
		*.tar.xz)
			unpack_tar $1 --xz $2
			;;
		*.tar)
			unpack_tar $1 $2
			;;
		*.zip)
			unpack_zip $1 $2
			;;
		*) eerror "Unknown format!" ;;
	esac
	return $?
}

is_archive()
{
	case $1 in
		*.tar.lzma)       return 0;;
		*.tar.bz2|*.tbz2) return 0;;
		*.tar.gz|*.tgz)   return 0;;
		*.tar.xz)         return 0;;
		*.tar)            return 0;;
		*.zip)            return 0;;
	esac
	return 1
}

unpack()
{
	local f=
	local ret=
	for f in $*
	do
		if is_archive $f
		then
			unpack_one $f
			ret=$?
		else
			unpack_copy $f
			ret=$?
		fi
		if [ $ret -ne 0 ]
		then
			break
		fi
	done
	return $ret
}

epatch()
{
	einfo "Applying patch $1 ... "
	local p_lines=1
	if [ "x$2" != "x" ]
	then
		p_lines=$2
	fi
	local f="${FILESDIR}/$1"
	local tmppatch=
	case $1 in
		*.gz)
			tmppatch="${TMPDIR}/._patch"
			gunzip -fcd $f > $tmppatch
			;;
		*.bz2)
			tmppatch="${TMPDIR}/._patch"
			bunzip2 -fcd $f > $tmppatch
			;;
	esac
	if [ -n "${tmppatch}" ]
	then
		patch -N -t -p${p_lines} -i "$tmppatch"
	else
		patch -N -t -p${p_lines} -i "$f"
	fi
	if [ $? -eq 0 ]
	then
		echo "patching done."
	else
		eerror "patching failed"
	fi
	if [ -n "${tmppatch}" ]
	then
		rm -f "$tmppatch"
	fi
}

eautoreconf()
{
	if [ ! -f Makefile.am -a ! -f Makefile.in ]
	then
		eerror "This project not use automake!"
		return
	fi

	local acfile=configure.in
	if [ ! -f "${acfile}" ]
	then
		acfile=configure.ac
	fi
	if [ ! -f "${acfile}" ]
	then
		einfo "This project not use autoconf!"
		return
	fi

	local aclocal_args=""
	if [ -n "${AT_M4DIR}" ]
	then
		aclocal_args="-I${AT_M4DIR}"
	fi

	ebegin "Running aclocal ${aclocal_args}... "
	aclocal ${aclocal_args} > ${WORKDIR_TEMP}/autogen.log 2>&1
	test $? -eq 0 && eend "ok" || eerror "failed"

	ebegin "Running libtoolize --copy --force --install --automake... "
	libtoolize --copy --force --install --automake >> ${WORKDIR_TEMP}/autogen.log 2>&1
	test $? -eq 0 && eend "ok" || eerror "failed"

	ebegin "Running aclocal ${aclocal_args}... "
	aclocal ${aclocal_args} >> ${WORKDIR_TEMP}/autogen.log 2>&1
	test $? -eq 0 && eend "ok" || eerror "failed"

	ebegin "Running autoconf... "
	autoconf >> ${WORKDIR_TEMP}/autogen.log 2>&1
	test $? -eq 0 && eend "ok" || eerror "failed"

	local need_autoheader=0
	grep "AM_CONFIG_HEADER" "${acfile}" > /dev/null 2>&1
	test $? -eq 0 && need_autoheader=1
	if [ $need_autoheader -eq 0 ]
	then
		grep "AC_CONFIG_HEADER" "${acfile}" > /dev/null 2>&1
		test $? -eq 0 && need_autoheader=1
	fi

	if [ $need_autoheader -eq 1 ]
	then
		ebegin "Running autoheader... "
		autoheader >> ${WORKDIR_TEMP}/autogen.log 2>&1
		test $? -eq 0 && eend "ok" || eerror "failed"
	fi

	if [ -f Makefile.am ]
	then
		ebegin "Running automake --add-missing --copy --foreign... "
		automake --add-missing --copy --foreign >> ${WORKDIR_TEMP}/autogen.log 2>&1
		test $? -eq 0 && eend "ok" || eerror "failed"
	fi
}

checkexitcode()
{
	if [ $1 -ne 0 ]
	then
		eerror $2
	fi
}

econf()
{
	# now we already in build dir, see part "into_builddir.sh"
	if [ "x${USE_CMAKE}" = "xyes" ]
	then
		cmake -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${PREFIX} $* "../${CMAKE_SOURCES_DIR}"
		if [ $? -eq 0 ]
		then
			einfo "cmake successfull"
			
			# fix native path of install prefix back to MSYS path
			cat CMakeCache.txt | sed -e "s/^CMAKE_INSTALL_PREFIX:PATH=.*$/CMAKE_INSTALL_PREFIX:PATH=\\${PREFIX}/" > CMakeCache.txt.new
			mv -f CMakeCache.txt.new CMakeCache.txt
			cat cmake_install.cmake | sed -e "s/^\ *SET(CMAKE_INSTALL_PREFIX\ .*)\ *$/  SET(CMAKE_INSTALL_PREFIX\ \\${PREFIX})/" > cmake_install.cmake.new
			mv -f cmake_install.cmake.new cmake_install.cmake
		else
			eerror "cmake failed"
		fi
	else
		local ___conf_script=
		if [ "x${BUILD_IN_SEPARATE_DIR}" = "xyes" ]
		then
			___conf_script=../${SOURCES_DIR}/configure
		else
			___conf_script=./configure
		fi
		${___conf_script} --prefix=${PREFIX} --build=${CBUILD} --host=${CHOST} $*
		if [ $? -eq 0 ]
		then
			einfo "configure successfull"
		else
			eerror "configure failed"
		fi
	fi
}

emake()
{
	#if [ "x$1" = "xnoopts" ]
	#then
	#	make
	#else
		echo " * make ${MAKEOPTS} $*"
		eval make ${MAKEOPTS} $*
	#fi
	if [ $? -eq 0 ]
	then
		eend "make successfull."
	else
		eerror "make failed!"
	fi
}

emake_install()
{
	mmkdir "${INSTDIR}"
	if [ "x$1" == "x" ]
	then
		make DESTDIR="${INSTDIR}" install
	else
		make $* install
	fi
	if [ $? -eq 0 ]
	then
		eend "make install successfull."
	else
		eerror "make install failed!"
	fi
}

#~ cleanup()
#~ {
	#~ if [ -d "${WORKDIR}" ]
	#~ then
		#~ ebegin "Cleaning \"${WORKDIR}\" ... "	
		#~ cd "${TMPDIR}"
		#~ rm -rf "${WORKDIR}"
		#~ if [ $? -eq 0 ]
		#~ then
			#~ eend "OK"
		#~ else
			#~ eerror "failed"
		#~ fi
	#~ fi
#~ }

strip_package()
{
	# to-do: rewrite in perl!
	einfo "Strip files in package..."
	local bfile=
	local tst=
	for file in `cat "${TMPCONT}"`
	do
		bfile=`basename $file`
		tst=`echo "$bfile" | grep ".*\.exe$\|.*\.dll$"`
		if [ "$tst" = "$bfile" ]
		then
			tst=`echo "$bfile" | grep "^.*[1234567890]d.dll$"`
			if [ "x${tst}" = "x" ]
			then
				strip --strip-unneeded "${INSTDIR}/$file"
				echo "	$file"
			fi
		fi
		tst=`echo "$bfile" | grep ".*\.a$\|.*\.o$"`
		if [ "$tst" = "$bfile" ]
		then
			tst=`echo "$bfile" | grep "^lib.*[1234567890]d\.a$\|^lib.*dll\.a$"`
			if [ "x${tst}" = "x" ]
			then
				strip --strip-debug "${INSTDIR}/$file"
				echo "	$file"
			fi
		fi
	done
}

make_tmpcontent()
{
	local pwd1=`pwd`
	cd "$INSTDIR"
	find . -print > "${TMPCONT}" 2>/dev/null
	# update modtime of each file to current time
	# later in make_content function this time saved in content list.
	# And in make_package function files saved also with this time.
	# This is need to corrent update package (see merge.pl).
	for file in `cat ${TMPCONT}`
	do
		if [ -f "${file}" ]
		then
			touch "${file}"
		fi
	done
	cd "${pwd1}"
}

make_content()
{
	ebegin "Make package contents... "
	local d=`dirname ${PKGCONT}`
	mmkdir "$d"
	local pwd1=`pwd`
	cd "$INSTDIR"

	local file=
	local ffile=
	local md5hash=
	local modtime=
	# truncate file if exist
	cat /dev/null > "${PKGCONT}"
	for file in `cat ${TMPCONT}`
	do
		# cut first character '.'
		ffile=`echo "${file}" | cut -c 2-`
		if test "x${ffile}" = "x" -o "x${ffile}" = "x${PREFIX}"
		then
			continue
		fi
		if test -d "${file}"
		then
			echo -e "dir\t${ffile}" >> "${PKGCONT}"
		else
			md5hash=`md5hash "${file}"`
			modtime=`filemodtime "${file}"`
			echo -e "fil\t${ffile}\t${md5hash}\t${modtime}" >> "${PKGCONT}"
		fi
	done
	rm -f "${tmplist}"
	cd "$pwd1"
	eend "OK"
	return 0
}

make_package()
{
	einfo "Make package archive..."
	local pwd1=`cd`
	cd "${INSTDIR}"
	tar -cvJpf "${PKG}" .
	ret=$?
	cd "$pwd1"
	return $ret
}

merge()
{
	einfo "Merge package to system..."
	perl ${XMERGE_PATH}/lib/merge.pl "${INSTDIR}" "${TMPCONT}"
	return $?
}

#  OBSOLETE: for removal!!!
# find installed packages with this name
# arguments:
# 1) package name like ${CATEGORY}/${PN} or just ${PN}
find_installed_pkg()
{
	local pn=$1

	local cat_name=`echo "${pn}" | sed -e "s/^\(.*\)\/.*$/\1/"`
	if [ "${cat_name}" != "${pn}" ]
	then
		pn=`echo ${pn} | sed -e "s/^.*\/\(.*\)$/\1/"`
	else
		cat_name=""
	fi

	local list=
	if [ "x${cat_name}" != "x" ]
	then
		list=`ls ${PKGDBBASE}/${cat_name} | grep ${pn}'-[0-9].*'`
	else
		list=`ls ${PKGDBBASE}/*/ | grep ${pn}'-[0-9].*'`
	fi
	# to-do: extract version part from name and check data, for example, slot
	echo $list
}
