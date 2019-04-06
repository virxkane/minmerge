#!/usr/bin/perl

# Copyright 2019 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

$MINMERGE_PATH = undef;

BEGIN {
	# Read minmerge & msys path from config.
	my $home = $ENV{'HOME'};				# in msys environment
	$home = $ENV{'APPDATA'} if !$home;		# in Windows cmd.exe
	my $fh;
	my $cfg_path = "$home/minmerge.cfg";
	my @_stat = stat($cfg_path);
	if (@_stat)
	{
		# config exist, read from this
		if (open($fh, "< $cfg_path"))
		{
			my @lines = <$fh>;
			my $idx;
			my ($key, $value);
			foreach (@lines)
			{
				chomp;
				# trim
				s/\s+(.*)\s+/$1/;
				next if length($_) == 0;
				next if substr($_, 0, 1) eq '#';
				$idx = index($_, '#');
				$_ = substr($_, 0, $idx) if $idx > 0;
				($key, $value) = split(/=/, $_, 2);
				$key =~ s/\s+(.*)\s+/$1/;
				$value =~ s/\s+(.*)\s+/$1/;
				# parse $key, $value
				$MINMERGE_PATH = $value if $key eq 'minmerge_path';
			}
			close($fh);
		}
		else
		{
			print "Can't read config file: \"$cfg_path\"!\n";
			exit 1;
		}
	}

	if (!$MINMERGE_PATH)
	{
		print "MINMERGE_PATH is unset!\n";
		exit 1;
	}

	require "$MINMERGE_PATH/lib/pkg_version.pm";
	import pkg_version;
	require "$MINMERGE_PATH/lib/pkgdb.pm";
	import pkgdb;

	setportage_info({prefix => '/mingw'});
}

# test get_all_installed_xbuilds()

my @pkgs = get_all_installed_xbuilds();
my $pkg;
foreach $pkg (@pkgs)
{
	print "${pkg}\n"
}
