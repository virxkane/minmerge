#!/bin/sh

# Copyright 2010-2013 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

BUILD_IN_SEPARATE_DIR=no

einfo()
{
	echo -n " * "
	echo $1
}

ebegin()
{
	echo -n " * $1"	
}

eend()
{
	echo $1
}

eerror()
{
	echo "$1" | tee -a "${BUILDLOG}"
	exit 1
}

die()
{
	echo "$1"
	exit 1
}

# default functions
pkg_setup()
{
	return 0
}

src_unpack()
{
	unpack ${A}
	if [ $? -ne 0 ]
	then
		return $?
	fi
	cd "${SOURCES_DIR}" || eerror "Can't cd to sources directory!"
}

src_prepare()
{
	return 0
}

src_configure()
{
	econf
}

src_compile()
{
	emake
}

src_install()
{
	emake_install
}

src_test()
{
	return 0
}

pkg_preinst()
{
	return 0
}

pkg_postinst()
{
	return 0
}

pkg_prerm()
{
	return 0
}

pkg_postrm()
{
	return 0
}

pkg_config()
{
	return 0
}
