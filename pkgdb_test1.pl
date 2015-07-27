#!/usr/bin/perl

# Copyright 2014-2015 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

BEGIN {
	# TODO: remove this define and read from config.
	$XMERGE_PATH = "d:/msys_4_64/build/minmerge";
	$MSYS_PATH = "d:/msys_4_64";

	require "$XMERGE_PATH/lib/pkg_version.pm";
	import pkg_version;
	require "$XMERGE_PATH/lib/pkgdb.pm";
	import pkgdb;
}

setportage_info({portdir => "d:/msys_4_64/build/portage", prefix => "d:/mingw64"});

# test find_xbuild()
print "Test find_xbuild():\n";

my $patom = "=zlib-1.2.8";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "=zlib-1.2.*";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "sys-libs/zlib";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "<sys-libs/zlib-1.2.7";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "sys-devel/gcc-core";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "dev-util/cmake";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "=media-libs/gegl-0.2.*";
my $bld = find_xbuild($patom);
print "patom: $patom => $bld\n";

# test find_xbuild()
print "\nTest find_installed_xbuild():\n";

my $patom = "sys-libs/zlib";
my $bld = find_installed_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "=zlib-1.2.8";
my $bld = find_installed_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "gui-libs/gtk+";
my $bld = find_installed_xbuild($patom);
print "patom: $patom => $bld\n";

my $patom = "dev-util/cmake";
my $bld = find_installed_xbuild($patom);
print "patom: $patom => $bld\n";
