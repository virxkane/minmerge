# Copyright 2010-2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

=head1 NAME

msyspathmap - Interpret msys path to Windows path.

=head1 SYNOPSIS

    require "<custom libs path>/shellscript.pm";
	import shellscript;
    require "<custom libs path>/msyspathmap.pm";
	import msyspathmap;
	
    shellscript::setshell("c:/msys/1.0/bin/sh.exe");
	my $gcc_path = "/mingw/bin/gcc.exe";
    my $gcc_path_w32 = posix2w32path($path);


=head1 DESCRIPTION

These routines allow you to convert pathes from msys (unix) notation to standart Windows pathes.


=cut

package msyspathmap;

use 5.006;
use strict;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(posix2w32path);

my %mounts_map;

sub init_mountsmap()
{
	#print "init_mountsmap()\n";
	my @lines = &shellscript::run_shellcmd("mount");
	if ($? != 0)
	{
		print "Fatal error: can't execute `mount'\n";
		return undef;
	}
	undef (%mounts_map);
	my $line;
	my ($unix_path, $w32_path);
	foreach $line (@lines)
	{
		# trim line
		$line =~ s/^\s*(.*)\s*/$1/;
		# simplify whitespaces
		$line =~ s/\s+/ /g;
		($w32_path, undef, $unix_path, undef) = split(/ /, $line, 4);
		$w32_path =~ tr/\\/\//;
		$mounts_map{$unix_path} = $w32_path;
	}
}

sub posix2w32path($)
{
	my ($path) = @_;
	my $len;
	my $frag;
	my $w32path = undef;
	my ($unix_path, $w32_path);

	# already win32 path
	return $path if $path =~ m/^[a-zA-Z]:.*/;

	if (!scalar(%mounts_map))
	{
		init_mountsmap();
	}
	while (($unix_path, $w32_path) = each(%mounts_map))
	{
		if ($path eq $unix_path)
		{
			$w32path = $w32_path;
			last;
		}
		$frag = $unix_path . "/";
		$len = length($frag);
		if (substr($path, 0, $len) eq $frag)
		{
			$w32path = $w32_path . "/" . substr($path, $len);
			last;
		}
	}
	while (each(%mounts_map))
	{
		;
	}
	if (!$w32path)
	{
		$w32path = $mounts_map{"/"} . $path;
	}
	return $w32path;
}

1;
