#!/bin/sh
# Copyright 2010-2017 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

# All needed variables defined in defaults.conf and make.conf
# Also:
# following variables must be declared in xbuild file
#  SRC_URI

# In xbld.pl writen following variables:
# CATEGORY
# PN, PV, PR, PVR, PF, P, A
# SOURCES_DIR, CMAKE_SOURCES_DIR
# FILESDIR, WORKDIR, WORKDIR_TEMP, INSTDIR

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig

export CHOST
export CFLAGS
export CXXFLAGS

DISTDIRS="${DISTDIR} ${DISTDIR2} ${DISTDIR3} ${DISTDIR4} ${DISTDIR5}
			${DISTDIR6} ${DISTDIR7} ${DISTDIR8} ${DISTDIR9}"

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
	local f=`find_srcpackage $1`
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
	local f=`find_srcpackage $1`
	cp -p "${f}" .
	if [ $? -eq 0 ]
	then
		eend "OK"
	else
		eerror "failed"
	fi
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
			gunzip -fcd "$f" > $tmppatch
			;;
		*.bz2)
			tmppatch="${TMPDIR}/._patch"
			bunzip2 -fcd "$f" > $tmppatch
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
	local skip_autoheader=0;
	while [ "x$1" != "x" ]
	do
		case "$1" in
		"skip-autoheader" )
			skip_autoheader=1
			;;
		esac
		shift
	done
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
	if [ $skip_autoheader -ne 1 ]
	then
		grep "AM_CONFIG_HEADER" "${acfile}" > /dev/null 2>&1
		test $? -eq 0 && need_autoheader=1
		if [ $need_autoheader -eq 0 ]
		then
			grep "AC_CONFIG_HEADER" "${acfile}" > /dev/null 2>&1
			test $? -eq 0 && need_autoheader=1
		fi
	fi

	if [ $need_autoheader -eq 1 ]
	then
		ebegin "Running autoheader... "
		autoheader >> ${WORKDIR_TEMP}/autogen.log 2>&1
		test $? -eq 0 && eend "ok" || eerror "failed"
	fi

	if [ -f Makefile.am -o -f GNUmakefile.am ]
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
		eval echo cmake -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${PREFIX} $* "../${CMAKE_SOURCES_DIR}" > ${WORKDIR_TEMP}/CONFIGURE
		cmake -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=${PREFIX} $* "../${CMAKE_SOURCES_DIR}"
		if [ $? -eq 0 ]
		then
			einfo "cmake successfull"
			
			# fix native path of install prefix back to MSYS path
			cat CMakeCache.txt | sed -e "s/^CMAKE_INSTALL_PREFIX:PATH=.*$/CMAKE_INSTALL_PREFIX:PATH=\\${PREFIX}/" > CMakeCache.txt.new
			mv -f CMakeCache.txt.new CMakeCache.txt
			cat CMakeCache.txt | sed -e "s/^CMAKE_INSTALL_PREFIX:INTERNAL=.*$/CMAKE_INSTALL_PREFIX:INTERNAL=\\${PREFIX}/" > CMakeCache.txt.new
			mv -f CMakeCache.txt.new CMakeCache.txt
			cat cmake_install.cmake | sed -e "s/^[\ \t]*SET(CMAKE_INSTALL_PREFIX\ .*)\ *$/  SET(CMAKE_INSTALL_PREFIX\ \\${PREFIX})/" > cmake_install.cmake.new
			mv -f cmake_install.cmake.new cmake_install.cmake
			# Since cmake-3.11
			cat cmake_install.cmake | sed -e "s/^[\ \t]*set(CMAKE_INSTALL_PREFIX\ .*)\ *$/  set(CMAKE_INSTALL_PREFIX\ \\${PREFIX})/" > cmake_install.cmake.new
			mv -f cmake_install.cmake.new cmake_install.cmake
		else
			eerror "cmake failed"
		fi
	else
		if [ "x${CONFIGURE_SCRIPT}" = "x" ]
		then
			CONFIGURE_SCRIPT="configure"
		fi
		local ___conf_script=
		if [ "x${BUILD_IN_SEPARATE_DIR}" = "xyes" ]
		then
			___conf_script=../${SOURCES_DIR}/${CONFIGURE_SCRIPT}
		else
			___conf_script=./${CONFIGURE_SCRIPT}
		fi
		# filter some predefined arguments
		local _args=
		local _prefix=${PREFIX}
		local _cbuild=${CBUILD}
		local _chost=${CHOST}
		while [ -n "$1" ]
		do
			if echo $1 | grep --regexp='^--prefix=.\+$' > /dev/null
			then
				_prefix=`echo $1 | sed -e 's/^--prefix=\(.*\)$/\1/'`
			elif echo $1 | grep --regexp='^--build=.\+$' > /dev/null
			then
				_cbuild=`echo $1 | sed -e 's/^--build=\(.*\)$/\1/'`
			elif echo $1 | grep --regexp='^--host=.\+$' > /dev/null
			then
				_chost=`echo $1 | sed -e 's/^--host=\(.*\)$/\1/'`
			else
				_args="${_args} $1"
			fi
			shift
		done
		_args="--prefix=${_prefix} --build=${_cbuild} --host=${_chost} ${_args}"
		unset -v _prefix
		unset -v _cbuild
		unset -v _chost
		eval echo ${___conf_script} ${_args} > ${WORKDIR_TEMP}/CONFIGURE
		${___conf_script} ${_args}
		unset -v _args
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
	if [ "x${USE_CMAKE}" = "xyes" ]
	then
		local _jobs=`echo "${MAKEOPTS}" | sed -e 's/^-j\ *\(.*\)$/\1/'`
		if [ "x${_jobs}" = "x" ]
		then
			_jobs=1
		fi
		echo " * cmake --build . --parallel ${_jobs} --verbose $*"
		cmake --build . --parallel ${_jobs} --verbose $*
	else
		#if [ "x$1" = "xnoopts" ]
		#then
		#	make
		#else
			echo " * make ${MAKEOPTS} V=1 $*"
			eval make ${MAKEOPTS} V=1 $*
		#fi
	fi
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
	if [ "x${USE_CMAKE}" = "xyes" ]
	then
		cmake --install . --verbose --prefix "${INSTDIR}${PREFIX}"
	else
		if [ "x$1" == "x" ]
		then
			make DESTDIR="${INSTDIR}" V=1 install
		else
			make $* install
		fi
	fi
	if [ $? -eq 0 ]
	then
		eend "make install successfull."
	else
		eerror "make install failed!"
	fi
}
