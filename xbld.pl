#!/usr/bin/perl

#######################################################################
#  Copyright 2014-2016 Chernov A.A. <valexlin@gmail.com>              #
#  This is a part of mingw-portage project:                           #
#  http://sourceforge.net/projects/mingwportage/                      #
#  Distributed under the terms of the GNU General Public License v3   #
#######################################################################

use 5.006;
use warnings;
#no warnings qw(once);

use File::Temp qw/tempfile/;
use File::Basename qw/basename/;
use File::Copy;
use File::Path;
use IPC::Open3;
use Time::Local;
use Cwd;
use POSIX qw/S_ISDIR S_ISREG/;

sub script_and_run_command($$$$);
sub inject_part($$);
sub read_modules($);
sub src_uri_list2hash(@);
sub fetch_file($$;$);
sub dir_list($$);
sub touch_to_filelist($$);
sub strip_binary_list($$);
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
./minmerge.pl --setmsys c:/msys2" --setminmerge c:/msys2/build/minmerge
 or 
./minmerge.pl --setmsys c:/msys2" --setminmerge $PWD
EOF
		exit 1;
	}
}

$SHELL = $MSYS_PATH . '/bin/sh.exe';
$SHELL = $MSYS_PATH . '/usr/bin/sh.exe' if ! -f $SHELL;

# imports
require "$MINMERGE_PATH/lib/shellscript.pm";
import shellscript;
require "$MINMERGE_PATH/lib/msyspathmap.pm";
import msyspathmap;
require "$MINMERGE_PATH/lib/pkg_version.pm";
import pkg_version;
require "$MINMERGE_PATH/lib/my_chomp.pm";
import my_chomp;
require "$MINMERGE_PATH/lib/pkgdb.pm";
import pkgdb;
require "$MINMERGE_PATH/lib/xbuild.pm";
import xbuild;
require "$MINMERGE_PATH/lib/mmfeatures.pm";
import mmfeatures;
require "$MINMERGE_PATH/lib/infodir.pm";
import infodir;

# stub for warnings 'once'
if ($mmfeatures::FEATURE_BUILDPKG) { if ($mmfeatures::FEATURE_BUILDPKG) {;} }
if ($mmfeatures::FEATURE_SAVELOG) { if ($mmfeatures::FEATURE_SAVELOG) {;} }
if ($mmfeatures::FEATURE_COLLISION_PROTECT) { if ($mmfeatures::FEATURE_COLLISION_PROTECT) {;} }

shellscript::setshell($SHELL);
$MINMERGE_PATH = posix2w32path($MINMERGE_PATH);
xbuild::set_minmerge($MINMERGE_PATH);

# minmerge config vars:
my $prefix = get_minmerge_configval("PREFIX");
if (length($prefix) > 1 && substr($prefix, length($prefix) - 1, 1) eq '/')
{
	$prefix = substr($prefix, 0, length($prefix) - 1);
}
my $prefix_w32 = posix2w32path($prefix);
my $pkgdbbase_w32 = $prefix_w32 . "/var/db/pkg";
my $portdir = get_minmerge_configval("PORTDIR");
my $portdir_w32 = posix2w32path($portdir);
my %features = parse_features(get_minmerge_configval("FEATURES"));

my $distdir = posix2w32path(get_minmerge_configval("DISTDIR"));
my @distdirs;
$distdirs[0] = $distdir;
$distdirs[1] = posix2w32path(get_minmerge_configval("DISTDIR2"));
$distdirs[2] = posix2w32path(get_minmerge_configval("DISTDIR3"));
$distdirs[3] = posix2w32path(get_minmerge_configval("DISTDIR4"));
$distdirs[4] = posix2w32path(get_minmerge_configval("DISTDIR5"));
$distdirs[5] = posix2w32path(get_minmerge_configval("DISTDIR6"));
$distdirs[6] = posix2w32path(get_minmerge_configval("DISTDIR7"));
$distdirs[7] = posix2w32path(get_minmerge_configval("DISTDIR8"));
$distdirs[8] = posix2w32path(get_minmerge_configval("DISTDIR9"));
my @source_mirrors;
{
	my $str = get_minmerge_configval("SOURCE_MIRRORS");
	foreach (split(/\s+/, $str))
	{
		push(@source_mirrors, $_);
	}
}
my $tmpdir = get_minmerge_configval("TMPDIR");
my $tmpdir_w32 = posix2w32path($tmpdir);
setportage_info({bldext => 'xbuild', prefix => $prefix_w32, portdir => $portdir_w32, metadata => $pkgdbbase_w32});

# setup openssl for wget
$ENV{OPENSSL_CONF}=$prefix_w32 . "/etc/ssl/openssl.cnf";
$ENV{SSL_CERT_DIR}=$prefix_w32 . "/etc/ssl/certs";

# main
my $xbuild;
my %xbuild_info;
my %restrict;
my $binpkg;
my $cmds;
my @commands;
my $cmd;
my $ret;

my $workdir;
my $workdir_w32;
my $workdir_temp;
my $workdir_temp_w32;
#my $buildlog;
my $buildlog_w32;
my $instdir;
my $instdir_w32;
my $pkgdbdir_w32;

my %src_uri_hash;
my @A;

$xbuild = shift;
{
	if (! -f $xbuild)
	{
		print "File \"$xbuild\" don't exist!\n";
		exit 1;
	}
}
while ($cmd = shift)
{
	if ($cmd =~ m/\.pkg\.tar\.xz$/)
	{
		$binpkg = $cmd;
	}
	else
	{
		$cmds .= ' ' . $cmd;
	}
}
# trim
$cmds =~ s/^\s*(.*)\s*$/$1/;
# simplify whitespaces
$cmds =~ s/\s+/ /g;
@commands = split(/ /, $cmds);

if ($binpkg && ! -f $binpkg)
{
	print "Binary package \"$binpkg\" don't exist!\n";
	exit 1;
}

#print "script: $xbuild\n";
#print "binpkg: $binpkg\n";
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
	elsif ("instbin" eq $_) {
		$cmds{expandbin} = 1;
		$cmds{qmerge} = 1;
		$cmds{postinst} = 1;
	}
	else
	{
		print "Command not supported: $_\n";
		exit 1;
	}
}

%xbuild_info = pkgdb::xbuild_info($xbuild);

# xbuild's variables
$workdir = "$tmpdir/$xbuild_info{pn}-build";
$workdir_w32 = "$tmpdir_w32/$xbuild_info{pn}-build";
$workdir_temp = "$workdir/temp";
$workdir_temp_w32 = "$workdir_w32/temp";
#$buildlog = "$workdir_temp/build.log";
$buildlog_w32 = "$workdir_temp_w32/build.log";
$instdir = "$workdir/image";
$instdir_w32 = "$workdir_w32/image";
$pkgdbdir_w32 = "$pkgdbbase_w32/$xbuild_info{cat}/$xbuild_info{pf}";

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

if ($cmds{clean})
{
	$ret = script_and_run_command($xbuild, 'clean', undef, $buildlog_w32);
	die "Cleanup failed!\n" if $ret != 0;
}
if ($cmds{fetch})
{
	# 1. check dist files
	my ($uri, $file);
	my $adir;
	my @_st;
	my $found;
	my $found_all = 1;
	my %dln_list;
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
		# secondly if downloading from mirrors failed - download from original URL.
		if (!$ret)
		{
			$ret = fetch_file($distdir, $uri, $file);
		}
		die "Fetch $file failed!\n" if !$ret;
	}
}
if ($cmds{setup})
{
	$ret = script_and_run_command($xbuild, 'setup', undef, $buildlog_w32);
	die "Setup failed!\n" if $ret != 0;
}
if ($cmds{unpack})
{
	my $label = "$workdir_w32/.unpacked";
	if (! -e $label)
	{
		$ret = script_and_run_command($xbuild, 'clean', undef, $buildlog_w32);
		die "Cleanup failed!\n" if $ret != 0;
		$ret = script_and_run_command($xbuild, 'unpack', undef, $buildlog_w32);
		die "Unpack failed!\n" if $ret != 0;
		my $fh;
		close $fh if open($fh, "> $label");
	}
	else
	{
		print("Package already unpacked, to force this operation\n");
		print("delete file $label\n");
	}
}
if ($cmds{prepare})
{
	my $label0 = "$workdir_w32/.unpacked";
	my $label = "$workdir_w32/.prepared";
	if (! -e $label0)
	{
		die "Package not unpacked yet!\n";
	}
	if (! -e $label)
	{
		$ret = script_and_run_command($xbuild, 'prepare', 1, $buildlog_w32);
		die "Prepare failed!\n" if $ret != 0;
		my $fh;
		close $fh if open($fh, "> $label");
	}
	else
	{
		print("Package already prepared, to force this operation\n");
		print("delete file $label\n");
	}
}
if ($cmds{configure})
{
	my $label0 = "$workdir_w32/.prepared";
	my $label = "$workdir_w32/.configured";
	if (! -e $label0)
	{
		die "Package not prepared yet!\n";
	}
	if (! -e $label)
	{
		# save some config values
		my $fh;
		open($fh, "> $workdir_temp_w32/CBUILD") || die "Can't create $workdir_temp_w32/CBUILD!\n";
		print $fh get_minmerge_configval("CBUILD") . "\n";
		close($fh);
		open($fh, "> $workdir_temp_w32/CHOST") || die "Can't create $workdir_temp_w32/CHOST!\n";
		print $fh get_minmerge_configval("CHOST") . "\n";
		close($fh);
		open($fh, "> $workdir_temp_w32/CFLAGS") || die "Can't create $workdir_temp_w32/CFLAGS!\n";
		print $fh get_minmerge_configval("CFLAGS") . "\n";
		close($fh);
		open($fh, "> $workdir_temp_w32/CXXFLAGS") || die "Can't create $workdir_temp_w32/CXXFLAGS!\n";
		print $fh get_minmerge_configval("CXXFLAGS") . "\n";
		close($fh);
		open($fh, "> $workdir_temp_w32/environment") || die "Can't create $workdir_temp_w32/environment!\n";
		while (my($envkey, $envval) = each(%ENV))
		{
			print $fh "$envkey=$envval\n";
		}
		close($fh);
		# run command
		$ret = script_and_run_command($xbuild, 'configure', 1, $buildlog_w32);
		die "configure failed!\n" if $ret != 0;
		close $fh if open($fh, "> $label");
	}
	else
	{
		print("Package already configured, to force this operation\n");
		print("delete file $label\n");
	}
}
if ($cmds{compile})
{
	my $label0 = "$workdir_w32/.configured";
	my $label = "$workdir_w32/.compiled";
	if (! -e $label0)
	{
		die "Package not configured yet!\n";
	}
	if (! -e $label)
	{
		$ret = script_and_run_command($xbuild, 'compile', 1, $buildlog_w32);
		die "compile failed!\n" if $ret != 0;
		my $fh;
		close $fh if open($fh, "> $label");
		open($fh, "> $workdir_temp_w32/BUILD_TIME") || die "Can't create $workdir_temp_w32/BUILD_TIME!\n";
		print $fh time() . "\n";
		close($fh);
	}
	else
	{
		print("Package already compiled, to force this operation\n");
		print("delete file $label\n");
	}
}
if ($cmds{test})
{
	my $label0 = "$workdir_w32/.compiled";
	my $label = "$workdir_w32/.tested";
	if (! -e $label0)
	{
		die "Package not compiled yet!\n";
	}
	if (! -e $label)
	{
		$ret = script_and_run_command($xbuild, 'test', 1, $buildlog_w32);
		die "test failed!\n" if $ret != 0;
		my $fh;
		close $fh if open($fh, "> $label");
	}
	else
	{
		print("Package already tested, to force this operation\n");
		print("delete file $label\n");
	}
}
if ($cmds{install})
{
	my $label0 = "$workdir_w32/.compiled";
	my $label = "$workdir_w32/.installed";
	if (! -e $label0)
	{
		die "Package not compiled yet!\n";
	}
	if (! -e $label)
	{
		if (! -d $instdir_w32)
		{
			mkdir($instdir_w32, 0755) || die "Can't create $instdir_w32!\n";
		}
		$ret = script_and_run_command($xbuild, 'install', 1, $buildlog_w32);
		die "Install failed!\n" if $ret != 0;
		# create list of installed dirs & files.
		my @dirlist = dir_list($instdir_w32, '');
		if (!$restrict{strip})
		{
			print " * Strip executables and libraries:\n";
			strip_binary_list($instdir_w32, \@dirlist);
		}
		# remove GNU info dir to exclude collisions.
		my $infodir = "$instdir_w32/$prefix/share/info/dir";
		if (-f $infodir)
		{
			unlink($infodir) || die "Failed to remove local info directory index file!";
		}
		$ret = File::Copy::copy($xbuild, $workdir_temp_w32 . '/' . File::Basename::basename($xbuild));
		die "xbuild copy failed!\n" if !$ret;
		close $fh if open($fh, "> $label");
	}
	else
	{
		print("Package already installed, to force this operation\n");
		print("delete file $label\n");
	}
}
if ($cmds{package})
{
	my $label0 = "$workdir_w32/.installed";
	if (! -e $label0)
	{
		die "Package not installed yet!\n";
	}
	$ret = script_and_run_command($xbuild, 'package', 1, $buildlog_w32);
	die "package failed!\n" if $ret != 0;
}
if ($cmds{expandbin})
{
	my $label = "$workdir_w32/.installed";
	$ret = script_and_run_command($xbuild, 'expandbin', undef, undef);
	die "expanding binary package failed!\n" if $ret != 0;
	# Replace xbuild ref with extracted from binary package.
	$xbuild = $workdir_temp_w32 . '/' . File::Basename::basename($xbuild);
	close $fh if open($fh, "> $label");
}
if ($cmds{preinst})
{
	$ret = script_and_run_command($xbuild, 'preinst', 1, $buildlog_w32);
	die "preinst failed!\n" if $ret != 0;
}
if ($cmds{qmerge})
{
	my $label0 = "$workdir_w32/.installed";
	if (! -e $label0)
	{
		die "Package not installed yet!\n";
	}

	my $ixbuild = find_installed_xbuild("$xbuild_info{cat}/$xbuild_info{pn}");
	my %ixbuild_info;
	my $ipkgdbdir;
	if ($ixbuild)
	{
		%ixbuild_info = xbuild_info($ixbuild);
		$ipkgdbdir = "$pkgdbbase_w32/$ixbuild_info{cat}/$ixbuild_info{pf}";
	}

	my @dirlist = dir_list($instdir_w32, '');
	my @pkg_files;
	my $f_entry;
	my $have_info_files;
	my $_prefix = $prefix;
	$_prefix = substr($_prefix, 1) if (substr($_prefix, 0, 1) eq '/');
	foreach (@dirlist)
	{
		$f_entry = $instdir_w32 . '/' . $_;
		push(@pkg_files, $_) if -f $f_entry;
		$have_info_files = 1 if m/^${_prefix}\/share\/info\/.*\.info$/;
	}
	if ($features{$mmfeatures::FEATURE_COLLISION_PROTECT})
	{
		print " * checking " . scalar(@pkg_files) . " files for package collisions...\n";
		$ret = pkg_check_collision($prefix, $prefix_w32, $instdir_w32, $ipkgdbdir, \@pkg_files);
		die "collision check failed!\n" if !$ret;
	}
	# update modtime of each file to current time
	# Later in make_pkg_contents() function this time saved in content list file.
	# This is needed to correctly update package (see unmerge_package() function).
	touch_to_filelist($instdir_w32, \@dirlist);

	print " * Merge package to system...\n";
	$ret = merge_package($prefix, $prefix_w32, $instdir_w32, \@dirlist);
	die "merge failed!\n" if !$ret;
	if ($ixbuild)
	{
		print " * Safely unmerging already-installed instance of $ixbuild_info{cat}/$ixbuild_info{pf}...\n";
		$ret = unmerge_package($prefix, $prefix_w32, $ipkgdbdir, $ixbuild);
		die "Unmerge $ixbuild_info{cat}/$ixbuild_info{pf} failed!" if !$ret;
	}
	if ($have_info_files)
	{
		# regenerate info directory index file.
		print "Regenerating GNU info directory index...\n";
		regenerate_infodir($SHELL, "$prefix/share/info/");
	}
	File::Path::mkpath($pkgdbdir_w32);
	$ret = File::Copy::copy("$workdir_temp_w32/CHOST", "$pkgdbdir_w32/CHOST");
	$ret = File::Copy::copy("$workdir_temp_w32/CBUILD", "$pkgdbdir_w32/CBUILD") if ($ret);
	$ret = File::Copy::copy("$workdir_temp_w32/CFLAGS", "$pkgdbdir_w32/CFLAGS") if ($ret);
	$ret = File::Copy::copy("$workdir_temp_w32/CXXFLAGS", "$pkgdbdir_w32/CXXFLAGS") if ($ret);
	$ret = File::Copy::copy("$workdir_temp_w32/BUILD_TIME", "$pkgdbdir_w32/BUILD_TIME") if ($ret);
	$ret = File::Copy::copy("$workdir_temp_w32/environment", "$pkgdbdir_w32/environment") if ($ret);
	if (-f "$workdir_temp_w32/CONFIGURE")
	{
		$ret = File::Copy::copy("$workdir_temp_w32/CONFIGURE", "$pkgdbdir_w32/CONFIGURE") if ($ret);
	}
	my @_stat = stat("$workdir_temp_w32/build.log");
	if ($ret && $features{$mmfeatures::FEATURE_SAVELOG} && @_stat && $_stat[7] != 0)
	{
		$ret = File::Copy::copy("$workdir_temp_w32/build.log", "$pkgdbdir_w32/build.log");
		if ($ret)
		{
			$ret = system($SHELL,  "--login", "-c", "xz -z $pkgdbdir_w32/build.log") == 0;
			if (!$ret)
			{
				print "Can't compress buildlog!\n";
			}
		}
	}
	$ret = File::Copy::copy($workdir_temp_w32 . '/' . File::Basename::basename($xbuild),
						$pkgdbdir_w32 . '/' . File::Basename::basename($xbuild)) if $ret;
	if ($ret)
	{
		make_pkg_contents($prefix, "$pkgdbdir_w32/CONTENTS", $instdir_w32, \@dirlist);
	}
	else
	{
		die "Failed to copy package information!\n";
	}
}
if ($cmds{postinst})
{
	$ret = script_and_run_command($xbuild, 'postinst', undef, $buildlog_w32);
	die "Postinst failed!\n" if $ret != 0;
}
if ($cmds{prerm})
{
	$ret = script_and_run_command($xbuild, 'prerm', undef, $buildlog_w32);
	die "Prerm failed!\n" if $ret != 0;
}
if ($cmds{unmerge})
{
	print " * Unmerging package $xbuild_info{cat}/$xbuild_info{pf}...\n";
	$ret = unmerge_package($prefix, $prefix_w32, $pkgdbdir_w32, $xbuild, 1);
	die "Unmerge $xbuild_info{cat}/$xbuild_info{pf} failed!" if !$ret;	
}
if ($cmds{postrm})
{
	# TODO: такого файла в дереве portage уже может и не быть,
	# а в $pkgdbdir_w32 уже нет
	$x = "$portdir_w32/$xbuild_info{cat}/$xbuild_info{pn}/$xbuild_info{pf}.$xbuild_info{bldext}";
	$ret = script_and_run_command($x, 'postrm', undef, $buildlog_w32);
	die "Postrm failed!\n" if $ret != 0;
}
if ($cmds{clean})
{
	$ret = script_and_run_command($xbuild, 'clean', undef, $buildlog_w32);
	die "Cleanup failed!\n" if $ret != 0;
}

# End of main.
1;



# generate and run bash script for xbuild and one specified command.
sub script_and_run_command($$$$)
{
	my ($xbuild, $command, $use_source, $logfile) = @_;
	my %xbuild_info = pkgdb::xbuild_info($xbuild);
	my ($fh, $fname) = tempfile(TMPDIR => 1, SUFFIX => ".sh");
	my $ret = -1;
	$fname =~ tr/\\/\//;
	my @modules = read_modules($xbuild);

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

	print $fh "FILESDIR=\"$portdir/$xbuild_info{cat}/$xbuild_info{pn}/files\"\n";
	print $fh "WORKDIR=\"$workdir\"\n";
	print $fh "WORKDIR_TEMP=\"$workdir_temp\"\n";
	print $fh "INSTDIR=\"$instdir\"\n";

	# you can redefine this variables in xbuild file.
	print $fh "SOURCES_DIR=\${P}\n";
	print $fh "source ${MINMERGE_PATH}/lib/xbld/deffuncs.sh\n";
	print $fh "A=\"";
	foreach (@A)
	{
		print $fh $_ . ' ';
	} print $fh "\"\n";

	print $fh "load_module()\n";
	print $fh "{\n";
	print $fh "	:\n";
	print $fh "}\n";
	foreach (@modules)
	{
		print $fh "source ${portdir}/pkg-modules/${_}.sh\n";
	}

	print $fh "source $xbuild\n";
	print $fh "if [ \"x\${CMAKE_SOURCES_DIR}\" = \"x\" ]\n";
	print $fh "then\n";
	print $fh "	CMAKE_SOURCES_DIR=\"\${SOURCES_DIR}\"\n";
	print $fh "fi\n";
	print $fh "source ${MINMERGE_PATH}/lib/xbld/library.sh\n";
	if ($use_source)
	{
		if ($command =~ m/configure|compile|test|install/)
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

	$fh = undef;
	if ($command =~ m/configure|compile|test|install/)
	{
		if (!open($fh, ">> $logfile"))
		{
			unlink($fname);
			die "Can't open $logfile!\n";
		}
		$fh->autoflush(1);
	}
	if ($fh)
	{
		my $fh_cmd;
		if (open($fh_cmd, "$SHELL --login -c $fname 2>&1 |"))
		{
			my $saved_autoflush = $|;
			$| = 1;
			while (<$fh_cmd>)
			{
				print $_;
				print $fh $_;
			}
			close($fh_cmd);
			$ret = $?;
			$| = $saved_autoflush;
		}
		close($fh);
	}
	else
	{
		$ret = system($SHELL,  "--login", "-c", $fname);
	}
	unlink($fname);
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
		die "Can't open part \'${part}\'!\n";
	}
}

sub read_modules($)
{
	my ($xbuild) = @_;
	my @modules = ();
	my $fh;
	if (open($fh, "< $xbuild"))
	{
		while (<$fh>)
		{
			&my_chomp::my_chomp($_);
			if (m/^\s*load_module\s+(.*)$/)
			{
				push(@modules, split / /, $1);
			}
		}
		close($fh);
	}
	else
	{
		die "Can't open $xbuild!\n";
	}
	return @modules;
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
		my @lines;
		my $line;
		my $pid = IPC::Open3::open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, "wget", "--server-response", "--spider", "$uri");
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

# read directory recursively and return list with its contents
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
sub touch_to_filelist($$)
{
	my ($prefix, $ref_dirlist) = @_;
	my $fname;
	foreach (@$ref_dirlist)
	{
		next if !$_;
		$fname = $prefix . '/' . $_;
		utime(undef, undef, $fname);
	}
}

# strip binary files
# first argument - directory prefix
sub strip_binary_list($$)
{
	my ($prefix, $ref_dirlist) = @_;
	my $fname;
	my $bname;
	my @_st;
	foreach (@$ref_dirlist)
	{
		next if !$_;
		$fname = $prefix . '/' . $_;
		@_st = stat($fname);
		if (@_st)
		{
			if (S_ISREG($_st[2]))
			{
				$bname = File::Basename::basename($_);
				if ($bname =~ m/^.*\.exe$|^.*\.dll$|^.*\.so$/ && !($bname =~ m/^.*\dd\.dll$/))
				{
					if (strip_binary($fname, 'r'))
					{
						print "\t$_\n";
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
						print "\t$_\n";
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

