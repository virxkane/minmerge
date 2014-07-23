#!/usr/bin/perl

# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
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

sub print_hash(%);

# test xbuild_info()

my $script = "c:/msys/1.0/build/portage/sys-libs/zlib/zlib-1.2.8.xbuild";
my %info = xbuild_info($script);
print "script: $script\n";
print_hash(%info); print "\n";

my $script = "c:/msys/1.0/build/portage/sys-libs/zlib/zlib-1.2.8-r12.xbuild";
my %info = xbuild_info($script);
print "script: $script\n";
print_hash(%info); print "\n";

my $script = "c:/mingw/var/db/pkg/sys-libs/zlib-1.2.8/zlib-1.2.8-r12.xbuild";
my %info = xbuild_info($script);
print "script: $script\n";
print_hash(%info); print "\n";

my $script = "/sys-libs/zlib/zlib-1.2.8-r12.xbuild";
my %info = xbuild_info($script);
print "script: $script\n";
print_hash(%info); print "\n";

my $script = "zlib/zlib-1.2.8-r12.xbuild";
my %info = xbuild_info($script);
print "script: $script\n";
print_hash(%info); print "\n";

sub print_hash(%)
{
	my (%h) = @_;
	my ($key, $val) = each(%h);
	while (defined($key) && defined($val))
	{
		print $key . '=>' . $val;
		if (($key, $val) = each(%h))
		{
			print ',';
		}
		else
		{
			last;
		}
	}
}
