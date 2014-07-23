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

sub print_hash(%);

# testing pkg_version
my $vv;
my %vvv;

# must be correct
print "   Valid samples:\n";

$vv = "6";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "6-r1";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3-r5";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3_beta";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3_rc3";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3_beta3";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3_beta3-r6";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "6b";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "6bc";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "6bcz";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "2014a";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.0.1h-r1";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.0.1.20140512";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.0.1_pre20140512";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.0.1_p6";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "2.8.9";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "2.8.12.2";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

print "\n   With patterns:\n";

# with patterns
$vv = "1.*.1";
%vvv = parse_version($vv, 1);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.1.1_pre*";
%vvv = parse_version($vv, 1);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

print "\n   Invalid samples:\n";

# must be invalid(undef)
$vv = "1.0.1_p";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.0.1*";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.1.1_pre*";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.*";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.=";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "6-r";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3_beka3-r6";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "1.2.3-rW";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

$vv = "a3.3";
%vvv = parse_version($vv);
print "$vv: "; print_hash(%vvv); print "\n";
print version2string(%vvv) . "\n";

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
