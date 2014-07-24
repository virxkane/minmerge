#!/usr/bin/perl

# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

use 5.006;
use warnings;

use File::Temp qw/tempfile/;

sub script_and_run_command($$$);
sub inject_part($$);

if (scalar(@ARGV) < 2)
{
	print "Too less arguments!\n";
	exit 1;
}

$MINMERGE_PATH = undef;
$MSYS_PATH = undef;

# Read minmerge & msys path from config.
{
	my $home = $ENV{'HOME'};					# in msys envoronment
	$home = $ENV{'APPDATA'} if !$home;		# in Windows cmd.exe
	my $fh;
	my $cfg_path = "$home/minmerge.cfg";
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
			$MSYS_PATH = $value if $key eq 'msys_path';
		}
		close($fh);
	}
	else
	{
		print "Can't read config file: \"$cfg_path\"!\n";
		exit 1;
	}

	if (!$MSYS_PATH || !$MINMERGE_PATH)
	{
		print << 'EOF';
minmerge not configured. You must configure minmerge, for example,
./minmerge.pl --setmsys c:/msys/1.0" --setminmerge c:/msys/1.0/build/minmerge
 or 
./minmerge.pl --setmsys c:/msys/1.0" --setminmerge $PWD
EOF
		exit 1;
	}
}

$SHELL = $MSYS_PATH . '/bin/sh.exe';

# imports
require "$MINMERGE_PATH/lib/shellscript.pm";
import shellscript;
require "$MINMERGE_PATH/lib/msyspathmap.pm";
import msyspathmap;
require "$MINMERGE_PATH/lib/pkg_version.pm";
import pkg_version;
require "$MINMERGE_PATH/lib/pkgdb.pm";
import pkgdb;

shellscript::setshell($SHELL);

$MINMERGE_PATH = posix2w32path($MINMERGE_PATH);

# main
my $xbuild;
my %xbuild_info;
my $cmds;
my @commands;
my $cmd;
my $ret;

$xbuild = shift;
{
	my @_st = stat($xbuild);
	if (!@_st)
	{
		print "File \"$xbuild\" don't exist!\n";
		exit 1;
	}
}
while ($cmd = shift)
{
	$cmds .= ' ' . $cmd;
}

# trim
$cmds =~ s/^\s*(.*)\s*$/$1/;
# simplify whitespaces
$cmds =~ s/\s+/ /g;
@commands = split(/ /, $cmds);

print "script: $xbuild\n";
print "commands: @commands\n";

my %cmds;
#~ my $cmd_clean = undef;
#~ my $cmd_setup = undef;
#~ my $cmd_fetch = undef;
#~ my $cmd_unpack = undef;
#~ my $cmd_prepare = undef;
#~ my $cmd_configure = undef;
#~ my $cmd_compile = undef;
#~ my $cmd_test = undef;
#~ my $cmd_install = undef;
#~ my $cmd_preinst = undef;
#~ my $cmd_qmerge = undef;
#~ my $cmd_postinst = undef;
#~ my $cmd_merge = undef;
#~ my $cmd_unmerge = undef;
#~ my $cmd_prerm = undef;
#~ my $cmd_postrm = undef;
#~ my $cmd_package = undef;

foreach (@commands)
{
	if ("clean" eq $_) { $cmds{clean} = 1; }
	elsif ("setup" eq $_) { $cmds{setup} = 1; }
	elsif ("fetch" eq $_) { $cmds{fetch} = 1; }
	elsif ("unpack" eq $_) { $cmds{unpack} = 1; }
	elsif ("prepare" eq $_) { $cmds{prepare} = 1; }
	elsif ("configure" eq $_) { $cmds{configure} = 1; }
	elsif ("compile" eq $_) { $cmds{compile} = 1; }
	elsif ("test" eq $_) { $cmds{test} = 1; }
	elsif ("install" eq $_) { $cmds{install} = 1; }
	elsif ("preinst" eq $_) { $cmds{preinst} = 1; }
	elsif ("qmerge" eq $_) { $cmds{qmerge} = 1; }
	elsif ("postinst" eq $_) { $cmds{postinst} = 1; }
	elsif ("merge" eq $_) {
		$cmds{fetch} = 1;
		$cmds{unpack} = 1;
		$cmds{prepare} = 1;
		$cmds{configure} = 1;
		$cmds{compile} = 1;
		$cmds{install} = 1;
		$cmds{preinst} = 1;
		$cmds{qmerge} = 1;
		$cmds{postinst} = 1;
	}
	elsif ("unmerge" eq $_) {
		$cmds{prerm} = 1;
		$cmds{unmerge} = 1;
		$cmds{postrm} = 1;
	}
	elsif ("prerm" eq $_) { $cmds{prerm} = 1; }
	elsif ("postrm" eq $_) { $cmds{postrm} = 1; }
	elsif ("package" eq $_) { $cmds{package} = 1; }
	else
	{
		print "Command not supported: $_\n";
		exit 1;
	}
}

%xbuild_info = pkgdb::xbuild_info($xbuild);

if ($cmds{fetch})
{
	$ret = script_and_run_command($xbuild, 'fetch', undef);
}
if ($cmds{setup})
{
	$ret = script_and_run_command($xbuild, 'setup', undef);
}
if ($cmds{unpack})
{
	$ret = script_and_run_command($xbuild, 'clean', undef);
	$ret = script_and_run_command($xbuild, 'unpack', undef);
}
if ($cmds{prepare})
{
	$ret = script_and_run_command($xbuild, 'prepare', 1);
}
if ($cmds{configure})
{
	$ret = script_and_run_command($xbuild, 'configure', 1);
}
if ($cmds{compile})
{
	$ret = script_and_run_command($xbuild, 'compile', 1);
}
if ($cmds{test})
{
	$ret = script_and_run_command($xbuild, 'test', 1);
}
if ($cmds{install})
{
	$ret = script_and_run_command($xbuild, 'install', 1);
}
if ($cmds{package})
{
	$ret = script_and_run_command($xbuild, 'package', 1);
}
if ($cmds{preinst})
{
	$ret = script_and_run_command($xbuild, 'preinst', 1);
}
if ($cmds{qmerge})
{
	$ret = script_and_run_command($xbuild, 'qmerge', 1);
}
if ($cmds{postinst})
{
	$ret = script_and_run_command($xbuild, 'postinst', undef);
}
if ($cmds{prerm})
{
	$ret = script_and_run_command($xbuild, 'prerm', undef);
}
if ($cmds{unmerge})
{
	$ret = script_and_run_command($xbuild, 'unmerge', undef);
}
if ($cmds{postrm})
{
	$ret = script_and_run_command($xbuild, 'postrm', undef);
}
if ($cmds{clean})
{
	$ret = script_and_run_command($xbuild, 'clean', undef);
}








# generate bash script for xbuild and one command
sub script_and_run_command($$$)
{
	my ($xbuild, $command, $use_source) = @_;
	my %xbuild_info = pkgdb::xbuild_info($xbuild);
	my ($fh, $fname) = tempfile(TMPDIR => 1, SUFFIX => ".sh");
	$fname =~ tr/\\/\//;

	print $fh "#!/bin/sh\n\n";
	print $fh "source $MINMERGE_PATH/etc/defaults.conf\n";
	print $fh "source $MINMERGE_PATH/etc/make.conf\n";

	print $fh "CATEGORY=$xbuild_info{cat}\n";
	print $fh "PN=$xbuild_info{pn}\n";
	print $fh "PV=$xbuild_info{pv}\n";
	print $fh "PR=$xbuild_info{pr}\n";
	print $fh "PVR=$xbuild_info{pvr}\n";
	print $fh "PF=$xbuild_info{pf}\n";
	print $fh "P=$xbuild_info{p}\n";
	# you can redefine this variables in xbuild file.
	print $fh "SOURCES_DIR=\${PF}\n";
	print $fh "source ${MINMERGE_PATH}/lib/xbld/deffuncs.sh\n";
	print $fh "source $xbuild\n";
	print $fh "if [ \"x\${CMAKE_SOURCES_DIR}\" = \"x\" ]\n";
	print $fh "then\n";
	print $fh "	CMAKE_SOURCES_DIR=\"\${SOURCES_DIR}\"\n";
	print $fh "fi\n";
	print $fh "source ${MINMERGE_PATH}/lib/xbld/library.sh\n";
	
	if ($use_source)
	{
		if ($command eq 'configure' || $command eq 'compile' || $command eq 'test' || $command eq 'install')
		{
			inject_part($fh, "into_builddir");
		}
		else
		{
			inject_part($fh, "into_sourcedir");
		}
	}
	inject_part($fh, $command);
	
	close($fh);
	# TODO: redirect output to "build.log"
	my $ret = system($SHELL, "--login", "-c", $fname);
	unlink($fname);
	# TODO: check result/return code
	return $ret;
}

sub inject_part($$)
{
	my ($fh, $part) = @_;
	my $fh_part;
	if (open($fh_part, "< ${MINMERGE_PATH}/lib/xbld/parts/${part}.sh"))
	{
		while (<$fh_part>)
		{
			print $fh $_;
		}
		close($fh_part);
	}
	else
	{
		print "Can't open part \'${part}\'!\n";
		exit 1;
	}
}
