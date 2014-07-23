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
}

# testing pkg_version
my ($vv1, $vv2);
my (%vvv1, %vvv2);
my $cmp_res;

$vv1 = "1.2.3";
%vvv1 = parse_version($vv1);
$vv2 = "1.2.3";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "1.2.6";
%vvv1 = parse_version($vv1);
$vv2 = "1.2.8";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "1.2.8";
%vvv1 = parse_version($vv1);
$vv2 = "1.2.6";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "1.2.3";
%vvv1 = parse_version($vv1);
$vv2 = "1.2.3_p3";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "1.1";
%vvv1 = parse_version($vv1);
$vv2 = "1.2_pre20140405";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "1.2_p2";
%vvv1 = parse_version($vv1);
$vv2 = "1.2_pre20140405";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "1.2";
%vvv1 = parse_version($vv1);
$vv2 = "1.2.0";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

$vv1 = "2.8.9";
%vvv1 = parse_version($vv1);
$vv2 = "2.8.12.2";
%vvv2 = parse_version($vv2);
$cmp_res = version_compare(\%vvv1, \%vvv2);
print "version_compare($vv1, $vv2) return $cmp_res\n";

