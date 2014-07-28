# Copyright 2010-2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

=head1 NAME

xbuild - Various usefull function to work with xbuild files.

=head1 SYNOPSIS

    require "<custom libs path>/shellscrip.pm";
	import shellscript;
    require "<custom libs path>/pkg_version.pm";
	import pkg_version;
    require "<custom libs path>/pkgdb.pm";
	import pkgdb;
    require "<custom libs path>/xbuild.pm";
	import xbuild;
	
    setshell("c:/mingw/msys/1.0/bin/sh.exe");
	set_minmerge("c:/mingw/msys/1.0/build/minmerge");
	@var_list = get_xbuild_vars("SRC_URI");


=head1 DESCRIPTION

These routines allow you to run various script or shell commands.
But this scripts/commands must be non interactive, i.e. output only!


=cut

package xbuild;

use 5.006;
use strict;

use File::Temp qw/tempfile/;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(set_minmerge get_minmerge_configval get_xbuild_vars get_depends get_rdepends get_full_xbuild_var);

my $_minmerge_path;

=over 4

=item C<set_minmerge>
X<set_minmerge> 

Set minmerge directory.

=cut
sub set_minmerge($)
{
	$_minmerge_path = $_[0];
}

=item C<get_minmerge_configval>
X<get_minmerge_configval> 

Gets value of minmerge config value.

=cut

sub get_minmerge_configval($)
{
	my ($varname) = @_;
	my @lines;
	my $value = undef;
	my ($fh, $fname) = tempfile();
	$fname =~ tr/\\/\//;

	print $fh "#!/bin/sh\n\n";
	print $fh "source $_minmerge_path/etc/defaults.conf\n";
	print $fh "source $_minmerge_path/etc/make.conf\n";
	print $fh "echo \$$varname\n";
	close($fh);

	@lines = shellscript::run_shellscript($fname);
	if ($? != 0)
	{
		print "Fatal error: can't execute file $fname!\n";
		return $value;
	}
	$value = $lines[0];
	# cleanup
	unlink $fname;
	return $value;
}

=item C<get_xbuild_vars>
X<get_xbuild_vars> 

Gets value of xbuild variables. Count of variables not limited.
Any axiliary variables not defined, and as a consequence some variables have
brokend, such as 'SRC_URI', 'SOURCES_DIR', etc.

=cut

sub get_xbuild_vars(@)
{
	my $xbuild = shift;
	my @vars = @_;
	my @lines;
	my @res;
	my $value;
	my ($fh, $fname) = tempfile(TMPDIR => 1, SUFFIX => ".sh");
	$fname =~ tr/\\/\//;

	print $fh "#!/bin/sh\n\n";
	print $fh "source $_minmerge_path/etc/defaults.conf\n";
	print $fh "source $_minmerge_path/etc/make.conf\n";
	print $fh "source $xbuild\n";
	foreach (@vars)
	{
		print $fh "echo \$$_\n";
	}
	close($fh);

	@lines = shellscript::run_shellscript($fname);
	if ($? != 0)
	{
		print "Fatal error: can't execute file $fname!\n";
		unlink $fname;
		return $value;
	}
	foreach (@lines)
	{
		# trim
		s/^\s*(.*)\s*/$1/;
		# simplify whitespaces
		s/\s+/ /;
		push @res, split if $_;
	}
	# cleanup
	unlink $fname;
	return @res;
}

=item C<get_full_xbuild_vars>
X<get_full_xbuild_vars> 

Gets value of xbuild variables. Count of variables not limited.
In addition defined axiliary variables, that provide valid value for some variables such as 'SRC_URI', 'SOURCES_DIR', etc.

=cut

sub get_full_xbuild_vars(@)
{
	my $xbuild = shift;
	my @vars = @_;
	my @lines;
	my @res;
	my $value;
	my %xbuild_info = pkgdb::xbuild_info($xbuild);
	my ($fh, $fname) = tempfile(TMPDIR => 1, SUFFIX => ".sh");
	$fname =~ tr/\\/\//;

	print $fh "#!/bin/sh\n\n";
	print $fh "source $_minmerge_path/etc/defaults.conf\n";
	print $fh "source $_minmerge_path/etc/make.conf\n";

	print $fh "CATEGORY=$xbuild_info{cat}\n";
	print $fh "PN=$xbuild_info{pn}\n";
	print $fh "PV=$xbuild_info{pv}\n";
	print $fh "PR=$xbuild_info{pr}\n";
	print $fh "PVR=$xbuild_info{pvr}\n";
	print $fh "PF=$xbuild_info{pf}\n";
	print $fh "P=$xbuild_info{p}\n";
	print $fh "SOURCES_DIR=\${PF}\n";
	print $fh "source $_minmerge_path/lib/xbld/deffuncs.sh\n";

	print $fh "source $xbuild\n";
	foreach (@vars)
	{
		print $fh "echo \$$_\n";
	}
	close($fh);

	@lines = shellscript::run_shellscript($fname);
	if ($? != 0)
	{
		print "Fatal error: can't execute file $fname!\n";
		unlink $fname;
		return $value;
	}
	foreach (@lines)
	{
		# trim
		s/^\s*(.*)\s*/$1/;
		# simplify whitespaces
		s/\s+/ /;
		push @res, split if $_;
	}
	# cleanup
	unlink $fname;
	return @res;
}

sub get_depends($)
{
	return get_xbuild_vars($_[0], 'DEPEND', 'RDEPEND');
}

sub get_rdepends($)
{
	return get_xbuild_vars($_[0], 'RDEPEND');
}

1;
