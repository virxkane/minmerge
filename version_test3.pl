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
my ($pat, $ver);
my $cond;
my %ver;
my $cmp_res;

$ver = "1.2.3";
%ver = parse_version($ver);
$pat = "1.2.3";
$cond = '=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.3";
%ver = parse_version($ver);
$pat = "1.2.*";
$cond = '=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.3";
%ver = parse_version($ver);
$pat = "1.*";
$cond = '=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.3";
%ver = parse_version($ver);
$pat = "1.*.3";
$cond = '=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.3";
%ver = parse_version($ver);
$pat = "1.2.6";
$cond = '>';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.6";
%ver = parse_version($ver);
$pat = "1.2.6";
$cond = '>=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.8";
%ver = parse_version($ver);
$pat = "1.2.6";
$cond = '>';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.8";
%ver = parse_version($ver);
$pat = "1.2.6";
$cond = '>=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.6";
%ver = parse_version($ver);
$pat = "1.2.3";
$cond = '<';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.6";
%ver = parse_version($ver);
$pat = "1.2.6";
$cond = '<=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.6";
%ver = parse_version($ver);
$pat = "1.2.8";
$cond = '<';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";

$ver = "1.2.6";
%ver = parse_version($ver);
$pat = "1.2.8";
$cond = '<=';
$cmp_res = version_test($cond, $pat, \%ver);
print "version_test($cond, $pat, $ver) return $cmp_res\n";
