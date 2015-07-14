# Copyright 2010-2015 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

=head1 NAME

xbuild - Various usefull functions to work with xbuild files.

=head1 SYNOPSIS

	require "<custom libs path>/shellscrip.pm";
	import shellscript;
	require "<custom libs path>/pkg_version.pm";
	import pkg_version;
	require "<custom libs path>/my_chomp.pm";
	import my_chomp;
	require "<custom libs path>/pkgdb.pm";
	import pkgdb;
	require "<custom libs path>/xbuild.pm";
	import xbuild;

	setshell("c:/mingw/msys/1.0/bin/sh.exe");
	set_minmerge("c:/mingw/msys/1.0/build/minmerge");
	@var_list = get_xbuild_vars("SRC_URI");


=head1 DESCRIPTION

These routines allow you to obtain some usefull information from xbuild files.


=cut

package xbuild;

use 5.006;
use strict;

use File::Temp qw/tempfile/;
use Digest::MD5;
use File::Copy;
use File::Path;
use POSIX qw/S_ISDIR S_ISREG/;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(set_minmerge get_minmerge_configval get_xbuild_vars get_depends get_rdepends
				get_full_xbuild_var pkg_check_collision merge_package make_pkg_contents unmerge_package);

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
	print $fh "_features=\${FEATURES}\n";
	print $fh "source $_minmerge_path/etc/make.conf\n";
	print $fh "FEATURES=\"\${_features} \${FEATURES}\"\n";
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
	print $fh "load_module()\n";
	print $fh "{\n";
	print $fh "	:\n";
	print $fh "}\n";
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
	print $fh "load_module()\n";
	print $fh "{\n";
	print $fh "	:\n";
	print $fh "}\n";

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


=item C<pkg_check_collision>
X<pkg_check_collision> 

Check package collisions.
arguments:
0: prefix - where package will be installed (msys path).
1: prefix_w32 - where package will be installed (win32 path).
2: instdir - where placed package files.
3: pkgdbdir - where saved information about installed version of package.
4: ref to list of package files.

=cut

sub pkg_check_collision($$$$$)
{
	my ($prefix, $prefix_w32, $instdir, $pkgdbdir, $reflist) = @_;
	my @list = @$reflist;
	my $pkg_prevcont = $pkgdbdir . "/CONTENTS";
	
	my $res = 1;
	my @prevcont;
	my $fh;
	my $prefix_len = length($prefix);
	my $tmp;
	my ($type, $fname, $hash, $modtime);
	my $line;
	my $refname;
	my $targ_fname;
	my $found;
	my @_st;

	if (-f $pkg_prevcont)
	{
		if (!open($fh, "< $pkg_prevcont"))
		{
			print("Can't open file $pkg_prevcont\n");
			return 0;
		}
		my @lines = <$fh>;
		my $line;
		close($fh);
		foreach $line (@lines)
		{
			my_chomp::my_chomp $line;
			next if !$line;
			($type, $fname, $hash, $modtime) = split(/\t+/, $line, 4);
			next if $type ne 'fil';
			$tmp = substr($fname, 0, $prefix_len);
			if ($tmp ne $prefix)
			{
				print "Found invalid prefix in installed package: $tmp\n";
				#return 0;
			}
			next if $fname eq $prefix;
			push(@prevcont, $fname) if $type eq 'fil';
		}
	}

	foreach $line (@list)
	{
		$line = '/' . $line; # if substr($line, 0, 1) ne '/';
		$refname = $line;
		$tmp = substr($line, 0, $prefix_len);
		if ($tmp ne $prefix)
		{
			print "Found invalid prefix in installed tree: $tmp\n";
			return 0;
		}
		next if $line eq $prefix;
		$fname = $instdir . $line;
		$line = substr($line, $prefix_len);
		next if !$fname || length($line) == 0;
		if (substr($line, 0, 1) ne '/')
		{
			print "Found invalid prefix in installed tree!\n";
			return 0;
		}
		$targ_fname = $prefix_w32 . $line;
		#print "$refname => $targ_fname\n";
		@_st = stat("$targ_fname");
		if (@_st)
		{
			$found = 0;
			foreach (@prevcont)
			{
				if ($_ eq $refname)
				{
					$found = 1;
					last;
				}
			}
			if (!$found)
			{
				print "File $refname blocks package merge!\n";
				$res = 0;
				# find all conflicted files...
				#last;
			}
		}
	}
	return $res;
}


=item C<merge_package>
X<merge_package> 

Merge package to system.
arguments:
0: prefix - where package will be installed (msys path).
1: prefix_w32 - where package will be installed (win32 path).
2: instdir - where placed package files.
3: ref to list of package files & dirs.

=cut

sub merge_package($$$$)
{
	my ($prefix, $prefix_w32, $instdir, $reflist) = @_;
	my @list = @$reflist;

	my $prefix_len = length($prefix);
	my $line;
	my $tmp;
	my $fname;
	my $targ_fname;
	my $res = 1;
	my $opstatus;
	my $fileflag = "";
	my @_st;
	my @_targ_st;

	foreach $line (@list)
	{
		$line = '/' . $line; # if substr($line, 0, 1) ne '/';
		$tmp = substr($line, 0, $prefix_len);
		if ($tmp ne $prefix)
		{
			print "Found invalid prefix in installed tree: $tmp\n";
			return 0;
		}
		next if $line eq $prefix;
		$fname = $instdir . $line;
		$line = substr($line, $prefix_len);
		next if !$fname || length($line) == 0;
		if (substr($line, 0, 1) ne '/')
		{
			print "Found invalid prefix in installed tree!\n";
			return 0;
		}
		$targ_fname = $prefix_w32 . $line;

		#print "$fname\n";
		#print "$targ_fname\n";

		$res = 1;
		@_st = stat($fname);
		@_targ_st = stat($targ_fname);
		if (S_ISDIR($_st[2]))
		{
			# create dir in live filesystem
			if (@_targ_st && !S_ISDIR($_targ_st[2]))
			{
				print("Found file $targ_fname but should be directory!\n");
				$res = 0;
			}
			else
			{
				if (@_targ_st && S_ISDIR($_targ_st[2]))
				{
					$res = 1;
					$opstatus = "---";
				}
				else
				{
					$res = mkdir($targ_fname);
					$opstatus = ">>>" if $res == 1;
				}
			}
			if ($res == 1)
			{
				printf "%s %-7s dir %s\n", $opstatus, $fileflag, $targ_fname;
			}
			else
			{
				printf "!!! failed  dir %s\n", $fname;
			}
		}
		elsif(S_ISREG($_st[2]))
		{
			# copy file to live filesystem
			if (@_targ_st && S_ISDIR($_targ_st[2]))
			{
				print("Found directory $targ_fname but we want copy to file with this name!\n");
				$res = 0;
			}
			else
			{
				# if file have readonly attribute - copy failed, then we remove target file firstly.
				$res = unlink($targ_fname) if (@_targ_st);
				$res = File::Copy::copy($fname, $targ_fname) if ($res);
				if ($res == 1)
				{
					utime($_st[8], $_st[9], $targ_fname);
				}
			}
			if ($res == 1)
			{
				printf ">>> %-7s fil %s\n", $fileflag, $targ_fname;
			}
			else
			{
				printf "!!! failed  fil %s\n", $targ_fname;
			}
		}
		last if ($res == 0);
	}
	return $res;
}

sub file_md5hash($)
{
	my $fname = $_[0];
	local *FILE;
	if (!open(FILE, "< $fname"))
	{
		return "";
	}
	binmode(FILE);
	my $res = Digest::MD5->new->addfile(*FILE)->hexdigest;
	close(FILE);
	return $res;
}

sub make_pkg_contents($$$$)
{
	print " * Make package contents... ";
	my ($prefix, $fname, $instdir, $ref_dirlist) = @_;
	my ($file, $ifile);
	my $mtime;
	my $fh;
	open($fh, "> $fname") || die "Can't create file $fname\n";
	foreach (@$ref_dirlist)
	{
		$file = '/' . $_;
		next if $file eq $prefix;
		$ifile = $instdir . $file;
		if (-d $ifile)
		{
			printf $fh "dir\t%s\n", $file;
		}
		else
		{
			(undef,undef,undef,undef,undef,undef,undef,undef,undef,$mtime,undef,undef,undef) = stat($ifile);
			printf $fh "fil\t%s\t%s\t%d\n", $file, file_md5hash($ifile), $mtime;
		}
	}
	close($fh);
	print "OK\n";
}

=item C<unmerge_package>
X<unmerge_package> 

Unmerge package - remove from system.
arguments:
0: prefix - where package will be installed (msys path).
1: prefix_w32 - where package will be installed (win32 path).
2: pkgdbdir - where saved information about this installed package.
3: xbuild - path to installed copy of xbuild.
4: force delete flag, if set to nonzero delete also modified files (optional).

=cut

sub unmerge_package($$$$;$)
{
	my ($prefix, $prefix_w32, $pkgdbdir, $xbuild, $force) = @_;
	my $pkgcont = $pkgdbdir . "/CONTENTS";

	my $res = 1;
	my $prefix_len = length($prefix);
	my $tmp;
	my $fh;
	if (!open($fh, "< $pkgcont"))
	{
		print("Can't open file $pkgcont\n");
		return 0;
	}
	my @lines = <$fh>;
	close($fh);
	my $line;
	my $len;
	my $fileflag;
	my $opstatus;
	my ($type, $fname, $hash, $modtime);
	my ($etype, $ehash, $emodtime);
	my @dirlist = ();
	my $ret;
	foreach $line (@lines)
	{
		my_chomp::my_chomp $line;
		next if !$line;
		($type, $fname, $hash, $modtime) = split(/\s+/, $line, 4);
		$tmp = substr($fname, 0, $prefix_len);
		if ($tmp ne $prefix)
		{
			print "Found invalid prefix in installed package: $tmp\n";
			#return 0;
		}
		next if $fname eq $prefix;
		$fname = substr($fname, $prefix_len);
		next if !$fname || length($fname) == 0;
		if (substr($fname, 0, 1) ne '/')
		{
			print "Found invalid prefix in installed package!\n";
			#return 0;
		}
		$fname = $prefix_w32 . $fname;
	#print "type=$type; fname=$fname, hash=$hash, modtime=$modtime\n";
		if (-e $fname)
		{
			$fileflag = "";
			if ($type eq "fil")
			{
				$ehash = file_md5hash($fname);
				(undef,undef,undef,undef,undef,undef,undef,undef,undef,$emodtime,undef,undef,undef) = stat($fname);
	#print "ehash=$ehash, emodtime=$emodtime\n\n";
			}
			else
			{
				$ehash = "";
				$emodtime = "";
			}
			if ($type eq "fil")
			{
				if ($hash ne $ehash || $modtime != $emodtime)
				{
					# file is changed!
					#print "M   $fname modified!!!\n";
					#print "    hash=$hash, ehash=$ehash\n";
					$fileflag = "mod";
					if (!$force)
					{
						printf "--- %-7s fil %s\n", $fileflag, $fname;
						next;
					}
				}
				# OK, delete this file
				$ret = unlink($fname);
				if ($ret == 1)
				{
					$opstatus = "<<<";
				}
				else
				{
					$opstatus = "---";
					$fileflag .= " err";
					$res = 0;
				}
				$len = length($fileflag);
				if ($len > 7)
				{
					$fileflag = substr($fileflag, 0, 7);
				}
				printf "%s %-7s fil %s\n", $opstatus, $fileflag, $fname;
			}
			elsif ($type eq "dir")
			{
				push(@dirlist, $fname);
			}
		}
		last if !$res;
	}
	return $res if !$res;
	if (scalar(@dirlist) > 0)
	{
		@dirlist = sort { 
							return 1 if $a lt $b;
							return -1 if $a gt $b;
							return 0;			
						} @dirlist;
		foreach $fname (@dirlist)
		{
			$fileflag = "";
			$ret = rmdir($fname);
			if ($ret == 1)
			{
				$opstatus = "<<<";
			}
			else
			{
				$opstatus = "---";
				$fileflag = "!empty";
				#$res = 0;
			}
			printf "%s %-7s dir %s\n", $opstatus, $fileflag, $fname;
			last if !$res;
		}
	}
	# remove $pkgdbdir recursively
	if ($res)
	{
		$res = File::Path::rmtree($pkgdbdir) > 0;
	}
	return $res;
}

1;
