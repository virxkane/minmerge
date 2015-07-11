#!/usr/bin/perl -W

# Copyright 2015 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

BEGIN {
	$XMERGE_PATH = "d:/msys2_x64/build/minmerge";
	$MSYS_PATH = "d:/msys2_x64";
	$SHELL = "$MSYS_PATH/usr/bin/sh.exe";

	require "$XMERGE_PATH/lib/infodir.pm";
	import infodir;
}

# test posix2w32path()
print "Test regenerate_infodir():\n";

my $path = "/mingw/share/info/";
my $ret = regenerate_infodir($SHELL, $path);
print "return code is $ret\n";

1;
