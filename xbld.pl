#!/usr/bin/perl

# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

use 5.006;
use warnings;

use File::Temp qw/tempfile/;
use File::Basename qw/basename/;
use IPC::Open3;
use Time::Local;
use Cwd;
use POSIX;

sub script_and_run_command($$$);
sub inject_part($$);
sub src_uri_list2hash(@);
sub fetch_file($$;$);
sub dir_list($$);
sub touch_to_filelist(@);
sub strip_binary_list(@);
sub strip_binary($$);

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
require "$MINMERGE_PATH/lib/xbuild.pm";
import xbuild;

shellscript::setshell($SHELL);
$MINMERGE_PATH = posix2w32path($MINMERGE_PATH);
xbuild::set_minmerge($MINMERGE_PATH);

# minmerge config vars:
my $prefix = get_minmerge_configval("PREFIX");
my $prefix_w32 = posix2w32path($prefix);
my $pkgdbbase = $prefix_w32 . "/var/db/pkg";
#my $portdir = get_minmerge_configval("PORTDIR");
#my $portdir_w32 = posix2w32path($portdir);
my %features;
{
	my $str = get_minmerge_configval("FEATURES");
	$str =~ s/\s*(.*)\s*/$1/;
	$str =~ s/\s+/ /;
	foreach (split(/ /, $str))
	{
		$features{$_} = 1;
	}
}
my $distdir = get_minmerge_configval("DISTDIR");
my @distdirs;
$distdirs[0] = $distdir;
$distdirs[1] = get_minmerge_configval("DISTDIR2");
$distdirs[2] = get_minmerge_configval("DISTDIR3");
$distdirs[3] = get_minmerge_configval("DISTDIR4");
$distdirs[4] = get_minmerge_configval("DISTDIR5");
$distdirs[5] = get_minmerge_configval("DISTDIR6");
$distdirs[6] = get_minmerge_configval("DISTDIR7");
$distdirs[7] = get_minmerge_configval("DISTDIR8");
$distdirs[8] = get_minmerge_configval("DISTDIR9");
$distdir = posix2w32path($distdir);
my @source_mirrors;
{
	my $str = get_minmerge_configval("SOURCE_MIRRORS");
	foreach (split(/\s+/, $str))
	{
		push(@source_mirrors, $_);
	}
}
my $tmpdir = get_minmerge_configval("TMPDIR");
$tmpdir = posix2w32path($tmpdir);

# main
my $xbuild;
my %xbuild_info;
my %restrict;
my $cmds;
my @commands;
my $cmd;
my $ret;

my $workdir;
my $workdir_temp;
my $instdir;
my %src_uri_hash;
my @A;

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

#print "script: $xbuild\n";
#print "commands: @commands\n";

# fill restrict hash
{
	my @lines = xbuild::get_xbuild_vars($xbuild, "RESTRICT");
	if (@lines)
	{
		my $line = join(" ", @lines);
		$line =~ s/\s*(.*)\s*/$1/;
		$line =~ s/\s+/ /;
		foreach (split(/ /, $line))
		{
			$restrict{$_} = 1;
		}
	}
}

my %cmds;
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

# xbuild's variables
$workdir = "$tmpdir/$xbuild_info{pn}-build";
$workdir_temp = "$workdir/temp";
$instdir = "$workdir/image";

# SRC_URI & A
{
	my @src_uri = ();
	@A = ();
	my ($uri, $file);
	my @lines = xbuild::get_full_xbuild_vars($xbuild, "SRC_URI");
	if (@lines)
	{
		my $line = join(" ", @lines);
		$line =~ s/^\s*(.*)\s*$/$1/;
		foreach (split(/\s+/, $line))
		{
			push(@src_uri, $_);
		}
		%src_uri_hash = src_uri_list2hash(@src_uri);
		while (($uri, $file) = each(%src_uri_hash))
		{
			push(@A, $file);
		}
	}
}

# Perform commands

if ($cmds{fetch})
{
	# 1. check dist files
	my ($uri, $file);
	my $adir;
	my @_st;
	my $found;
	my $found_all = 1;
	my %dln_list;
	#foreach $file (@A)
	while (($uri, $file) = each(%src_uri_hash))
	{
		# TODO: skip repeated files
		$found = 0;
		foreach $adir (@distdirs)
		{
			next if !$adir;
			@_st = stat("$adir/$file");
			if (@_st)
			{
				if ($_st[7] != 0)
				{
					# TODO: also check fingerprint
					$found = 1;
					print "$file  OK\n";
				}
			}
		}
		if (!$found)
		{
			$dln_list{$uri} = $file;
			$found_all = 0;
		}
	}
	if (!$found_all && $restrict{fetch})
	{
		print "This xbuild have fetch restrict, you must download this files manualy:\n";
		while (($uri, $file) = each(%src_uri_hash))
		{
			print "   $uri -> $distdir/$file\n";
		}
		exit 1;
	}
	# 2. download ommited/broken files
	while (($uri, $file) = each(%dln_list))
	{
		# firstly download from @source_mirrors
		$ret = 0;
		if (!$restrict{mirror})
		{
			my $mirror;
			my $muri;
			foreach $mirror (@source_mirrors)
			{
				$muri = $mirror . '/distfiles/' . $file;
				$ret = fetch_file($distdir, $muri);
				last if $ret;
			}
		}
		if (!$ret)
		{
			$ret = fetch_file($distdir, $uri, $file);
			if (!$ret)
			{
				print "Fetch $file failed!\n";
				exit 1;
			}
		}
	}
}
if ($cmds{setup})
{
	$ret = script_and_run_command($xbuild, 'setup', undef);
	if ($ret != 0)
	{
		print "Setup failed!\n";
		exit 1;
	}
}
if ($cmds{unpack})
{
	$ret = script_and_run_command($xbuild, 'clean', undef);
	if ($ret != 0)
	{
		print "Cleanup failed!\n";
		exit 1;
	}
	$ret = script_and_run_command($xbuild, 'unpack', undef);
	if ($ret != 0)
	{
		print "Unpack failed!\n";
		exit 1;
	}
}
if ($cmds{prepare})
{
	$ret = script_and_run_command($xbuild, 'prepare', 1);
	if ($ret != 0)
	{
		print "Prepare failed!\n";
		exit 1;
	}
}
if ($cmds{configure})
{
	$ret = script_and_run_command($xbuild, 'configure', 1);
	if ($ret != 0)
	{
		print "Configure failed!\n";
		exit 1;
	}
}
if ($cmds{compile})
{
	$ret = script_and_run_command($xbuild, 'compile', 1);
	if ($ret != 0)
	{
		print "Compile failed!\n";
		exit 1;
	}
}
if ($cmds{test})
{
	$ret = script_and_run_command($xbuild, 'test', 1);
	if ($ret != 0)
	{
		print "Test failed!\n";
		exit 1;
	}
}
if ($cmds{install})
{
	$ret = script_and_run_command($xbuild, 'install', 1);
	if ($ret != 0)
	{
		print "Install failed!\n";
		exit 1;
	}
	# create list of installed dirs & files.
	my @dirlist = dir_list($instdir, '/');
	# write thislist to file
	my $fh;
	if (open($fh, "> $workdir_temp/contents"))
	{
		foreach (@dirlist)
		{
			print $fh "$_\n";
		}
		close($fh);
	}
	else
	{
		print "Can't write contents of package!\n";
		exit 1;
	}
	# update modtime of each files to current time
	# later in make_content function this time saved in content list.
	# And in make_package function files saved also with this time.
	# This is needed to correctly update package (see merge.pl).
	touch_to_filelist($instdir, @dirlist);
	if (!$restrict{strip})
	{
		print "Strip executables and libraries:\n";
		strip_binary_list($instdir, @dirlist);
	}
}
if ($cmds{package})
{
	$ret = script_and_run_command($xbuild, 'package', 1);
}
if ($cmds{preinst})
{
	$ret = script_and_run_command($xbuild, 'preinst', 1);
	if ($ret != 0)
	{
		print "Preinst failed!\n";
		exit 1;
	}
}
if ($cmds{qmerge})
{
	# rewrite in perl (here)
	$ret = script_and_run_command($xbuild, 'qmerge', 1);
}
if ($cmds{postinst})
{
	$ret = script_and_run_command($xbuild, 'postinst', undef);
	if ($ret != 0)
	{
		print "Postinst failed!\n";
		exit 1;
	}
}
if ($cmds{prerm})
{
	$ret = script_and_run_command($xbuild, 'prerm', undef);
	if ($ret != 0)
	{
		print "Prerm failed!\n";
		exit 1;
	}
}
if ($cmds{unmerge})
{
	# rewrite in perl (here)
	$ret = script_and_run_command($xbuild, 'unmerge', undef);
}
if ($cmds{postrm})
{
	$ret = script_and_run_command($xbuild, 'postrm', undef);
	if ($ret != 0)
	{
		print "Postrm failed!\n";
		exit 1;
	}
}
if ($cmds{clean})
{
	$ret = script_and_run_command($xbuild, 'clean', undef);
	if ($ret != 0)
	{
		print "Cleanup failed!\n";
		exit 1;
	}
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
	print $fh "A=";
	foreach (@A)
	{
		print $fh $_ . ' ';
	} print $fh "\n";
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

# return hash with following pairs:
# uri => filename
# input - uri list like this:
# http://foo.bar.com/file.tgz?download -> file.tgz
# http://foo.bar.com/file.tbz
sub src_uri_list2hash(@)
{
	my %res_hash;
	my $prev;
	my $have_arrow = 0;
	my $uri;
	foreach (@_)
	{
		if ("->" eq $_)
		{
			$have_arrow = 1;
			if (!$prev)
			{
				print "Before '->' you must specify URI!\n";
				return %res_hash;
			}
			$uri = $prev;
		}
		else
		{
			if ($have_arrow)
			{
				$res_hash{$uri} = $_;
				$have_arrow = 0;
			}
			else
			{
				$res_hash{$_} = File::Basename::basename($_);
				$prev = $_;
			}
		}
	}
	if ($have_arrow)
	{
		print "After '->' you must specify file!\n";
	}
	return %res_hash;
}

sub strMonth2number($)
{
	my ($str) = @_;
	my $res = -1;
	my @month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
	for (my $i = 0; $i < 12; $i++)
	{
		if ($str =~ m/$month[$i]/i)
		{
			$res = $i + 1;
			last;
		}
	}
	return $res;
}

# input: string
# return unix time
sub str2date($)
{
	# строки вида:
	#   1) MS IIS format
	#     07-11-06  02:08PM
	#     08-07-06  08:24AM
	#   2) short format
	#     Jun 28 21:08
	#     Sep 13  2005
	#     Feb 22 15:23
	#   3) long format
	#     Wed, 28 Jun 2006 21:08:43 GMT
	#     Tue, 13 Sep 2005 04:07:24 GMT
	my ($str) = @_;
	my @list = split(/\s+/, $str);
	my $count = @list;
	my $res = -1;
	
	## char* ptr;
	my $idx;
	my ($hour, $min, $sec);
	
	if ($count != 2 && $count != 3 && $count != 6)
	{
		return -1;
	}
	my $cur_t = time();
	my @cur_tm = localtime($cur_t);
	my @lt;
	if ($count == 2)				# MS IIS format
	{
		my @dt_list = split(/-/, $list[0]);
		my $dt_count = @dt_list;
		if ($dt_count == 3 && $dt_list[0] =~ m/\d+/ && $dt_list[1] =~ m/\d+/ && $dt_list[2] =~ m/\d+/)
		{
			# fill date
			$lt[3] = $dt_list[1];		# mday
			$lt[4] = $dt_list[0] - 1;	# month
			$lt[5] = $dt_list[2];		# year
			if ($lt[5] < 30)
			{
				$lt[5] += 2000;
			}
			else
			{
				$lt[5] += 1900;
			}
			# fill time
			$idx = index($list[1], ':');
			if ($idx > 0)
			{
				$lt[2] = substr($list[1], 0, $idx);		# hour
				$lt[1] = substr($list[1], $idx + 1, 2);	# min
				if ($idx + 3 < length($list[1]))
				{
					my $_str = substr($list[1], $idx + 3);
					$lt[2] += 12 if $_str eq 'PM';
				}
			}
			$lt[0] = 0;
			$res = timelocal(@lt);
		}
	}
	elsif ($count == 3)				# short format
	{
		$lt[4] = strMonth2number($list[0]) - 1;  # month
		$lt[3] = $list[1];				# mday
		$idx = index($list[2], ':');
		if ($idx > 0)
		{
			$lt[5] = $cur_tm[5] + 1900;
			$lt[2] = substr($list[2], 0, $idx);
			$lt[1] = substr($list[2], $idx + 1);
			$lt[0] = 0;
			# test year field
			my $tt = timelocal(@lt);
			$lt[5] =-1 if $tt > $cur_t;
		}
		else
		{
			$lt[5] = $list[2];
			$lt[2] = 0;
			$lt[1] = 0;
			$lt[0] = 0;
		}
		$res = timelocal(@lt);
	}
	elsif ($count == 6)		# long format
	{
		$lt[3] = $list[1];
		$lt[4] = strMonth2number($list[2]) - 1;
		$lt[5] = $list[3];
		my @tm_list = split(/:/, $list[4]);
		my $tm_count = @tm_list;
		if ($tm_count == 3)
		{
			$lt[2] = $tm_list[0];
			$lt[1] = $tm_list[1];
			$lt[0] = $tm_list[2];
			if ($list[5] =~ m/GMT/i)
			{
				$res = timegm(@lt);
			}
			else
			{
				# to-do: fix conversion with other timezone
				$res = timelocal(@lt);
			}
		}
	}
	return $res;
}

# arguments: dir, uri, file
# dir - where file saved
# uri - URL of file
# file - target file name (optional)
# return value: 1 if successfull, 0 - otherwise.
sub fetch_file($$;$)
{
	my ($destdir, $uri, $fname) = @_;
	my $ret;
	if ($fname)
	{
		my $targ = $destdir . '/' . $fname;
		my $timestamp = -1;
		# firstly get timestamp
		local *CHLD_OUT;
		local *CHLD_ERR;
		local *CHLD_IN;
		my $pid;
		my @lines;
		my $line;
		$pid = IPC::Open3::open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, "wget", "--server-response", "--spider", "$uri");
		$line = <CHLD_OUT>;
		$line = <CHLD_ERR> if !$line;
		while ($line)
		{
			chomp $line;
			push(@lines, $line);
			$line = <CHLD_OUT>;
			$line = <CHLD_ERR> if !$line;
		}
		waitpid($pid, 0);
		close(CHLD_ERR);
		close(CHLD_OUT);
		close(CHLD_IN);
		foreach (@lines)
		{
			if (m/^\s*Last-Modified: (.*)$/)
			{
				$timestamp = str2date($1);
			}
		}
		#$ret = $? >> 8;
		# And finaly download file
		$ret = system("wget $uri -O $targ");
		if ($ret == 0)
		{
			utime($timestamp, $timestamp, $targ);
		}
	}
	else
	{
		my $cwd_saved = getcwd();
		if (chdir($destdir))
		{
			$ret = system("wget -c $uri");
			chdir($cwd_saved);
		}
	}
	return $ret == 0;
}

# read directory and return list with its contents
sub dir_list($$)
{
	my ($dir, $prefix) = @_;
	my $dh;
	my @res_list;
	my $entry;
	my $f_entry;
	my @_st;
	if (opendir($dh, $dir))
	{
		while ($entry = readdir($dh))
		{
			next if ($entry eq '..' || $entry eq '.');
			$f_entry = $dir . '/' . $entry;
			push(@res_list, $prefix . $entry);
			@_st = stat($f_entry);
			if (S_ISDIR($_st[2]))
			{
				push(@res_list, dir_list($f_entry, $prefix . $entry . '/'));
			}
		}
		@res_list = sort(@res_list);
		closedir($dh);
	}
	return @res_list;
}

# touch to all files in list
# first argument - directory prefix
sub touch_to_filelist(@)
{
	my ($prefix, @dirlist) = @_;
	my $fname;
	foreach (@dirlist)
	{
		next if !$_;
		$fname = $prefix . '/' . $_;
		utime(undef, undef, $fname);
	}
}

# strip binary files
# first argument - directory prefix
sub strip_binary_list(@)
{
	my ($prefix, @dirlist) = @_;
	my $fname;
	my $bname;
	my @_st;
	foreach (@dirlist)
	{
		next if !$_;
		$fname = $prefix . '/' . $_;
		@_st = stat($fname);
		if (@_st)
		{
			if (S_ISREG($_st[2]))
			{
				$bname = File::Basename::basename($_);
				if ($bname =~ m/^.*\.exe$|^.*\.dll$/ && !($bname =~ m/^.*\dd\.dll$/))
				{
					if (strip_binary($fname, 'r'))
					{
						print "\t.$_\n";
					}
					else
					{
						print "strip failed at $_!\n";
						last;
					}
				}
				elsif ($bname =~ m/^.*\.a$|^.*\.o$/ && !($bname =~ m/^lib.*dll\.a/) && !($bname =~ m/^lib.*\dd\.a/))
				{
					if (strip_binary($fname, 'l'))
					{
						print "\t.$_\n";
					}
					else
					{
						print "strip failed at $_!\n";
						last;
					}
				}
			}
		}
	}
}

sub strip_binary($$)
{
	my ($fname, $type) = @_;
	my $arg;
	if ($type =~ m/r|runtime/)
	{
		$arg = "--strip-unneeded";
	}
	elsif ($type =~ m/l|library|o|object/)
	{
		$arg = "--strip-debug"
	}
	else
	{
		$arg = "";
	}
	return system("strip $arg $fname") == 0;
}
