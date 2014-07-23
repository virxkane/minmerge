# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

=head1 NAME

pkgdb - Methods for getting various information about `mingw-portage' packages.

=head1 SYNOPSIS

    require "<custom libs path>/pkg_version.pm";
	import pkg_version;
    require "<custom libs path>/pkgdb.pm";
	import pkgdb;

	$portage_info{portdir} = "c:/msys/1.0/build/portage";
	$portage_info{prefix} = "c:/mingw";
	setportage_info(\%portage_info);

	my $xbuild = find_xbuild("zlib");
	$xbuild = find_xbuild(">=dev-libs/gmp-5.1");
	$xbuild = find_xbuild("=dev-libs/gmp-5.0.*");

	my $ixbuild = find_installed_xbuild("zlib");
	$ixbuild = find_installed_xbuild(">=dev-libs/gmp-5.1");
	$ixbuild = find_installed_xbuild("=dev-libs/gmp-5.0.*");


=head1 DESCRIPTION

These routines allow you to find build script for package atom.
Also we have routine to find script for installed package.


=cut

package pkgdb;

use 5.006;
use strict;

use POSIX;
use File::Basename qw/fileparse dirname basename/;
use File::Temp qw/tempfile/;

BEGIN
{
	require Exporter;

	our @ISA = qw(Exporter);
	our @EXPORT = qw(setportage_info find_xbuild find_installed_xbuild xbuild_info
					add_to_world remove_from_world is_in_world
					get_system_set get_world_set);
}

=over 4

=item C<setportage_info>
X<setportage_info> 

Set various portage parameters. Now support these options as hash keys:
bldext - extension of  build script,
portdir - portage directory (where you place build scripts),
prefix - mingw prefix (where you place all mingw packages),
metadata - directory with installed packages metadata (usualy it's <prefix>/var/db/pkg)
 
  setportage_info({portdir => $portdir, prefix => $prefix});

or

  $portage_info{portdir} = "c:/msys/1.0/build/portage";
  $portage_info{prefix} = "c:/mingw";
  setportage_info(\%portage_info);

=cut

my %portage_info = (bldext => 'xbuild', prefix => 'c:/mingw', portdir => '/x/', metadata => 'c:/mingw/var/db/pkg');

# system packages
my @system_set = ('meta-virtual/system-headers', 'meta-virtual/system-libc',
				'sys-devel/binutils', 'sys-devel/gcc-core-c++',
				'sys-devel/automake', 'sys-devel/libtool',
				'net-misc/wget');

sub setportage_info($)
{
	my ($ref) = @_;
	my %info = %$ref;
	$portage_info{bldext} = $info{bldext} if defined($info{bldext});
	$portage_info{portdir} = $info{portdir} if defined($info{portdir});
	if (defined($info{prefix}))
	{
		$portage_info{prefix} = $info{prefix};
		if (defined($info{metadata}))
		{
			$portage_info{metadata} = $info{metadata};
		}
		else
		{
			$portage_info{metadata} = $portage_info{prefix} . '/var/db/pkg';
		}
	}
}

=item C<find_xbuild>
X<find_xbuild> 

Find build script for specified package atom:

  my $xbld = find_xbuild('zlib');
  if ($xblf)
  {
    # some action on this script ...
  }
  $xbld = find_xbuild('>=zlib-1.2.8');
  $xbld = find_xbuild('<sys-devel/zlib-1.2.7');

=cut

sub find_xbuild($)
{
	return find_xbuild_private($_[0], 0);
}

=item C<find_installed_xbuild>
X<find_installed_xbuild> 

Find build script for specified installed package:

  my $xbld = find_installed_xbuild('zlib');
  if ($xblf)
  {
    # some action on this script ...
  }
  $xbld = find_installed_xbuild('>=zlib-1.2.8');
  $xbld = find_installed_xbuild('<sys-devel/zlib-1.2.7');

=cut

sub find_installed_xbuild($)
{
	return find_xbuild_private($_[0], 1);
}

sub find_xbuild_private($$)
{
	my ($patom, $installed) = @_;
	my $portdir = !$installed ? $portage_info{portdir} : $portage_info{metadata};
	my $xbuild_ext = $portage_info{bldext};
	my $res;
	return undef unless (defined($patom) && length($patom) > 2);

	my $have_ver = 0;
	my $pname;
	my $cond = "";
	my $version = "";
	my $category = "";
	my $conflict = 0;	# if we found this atom in multiple categories.
	my ($tstr, $len);
	my ($idx, $pidx);
	my ($dh_p, $dir_p_ent, $ent_p_mode);
	my ($dh, $dirname, $dir_ent, $ent_mode);
	my (@candidates, $candidate, $cand_ver_s, %cand_ver, %cand_ver_p, $cmp_res);

	if (substr($patom, 0, 1) eq '=')
	{
		$cond = '=';
		$pname = substr($patom, 1);
	}
	elsif (substr($patom, 0, 2) eq '>=')
	{
		$cond = '>=';
		$pname = substr($patom, 2);
	}
	elsif (substr($patom, 0, 2) eq '<=')
	{
		$cond = '<=';
		$pname = substr($patom, 2);
	}
	elsif (substr($patom, 0, 1) eq '>')
	{
		$cond = '>';
		$pname = substr($patom, 1);
	}
	elsif (substr($patom, 0, 1) eq '<')
	{
		$cond = '<';
		$pname = substr($patom, 1);
	}
	else
	{
		$pname = $patom;
	}
	if ($cond)
	{
		$have_ver = 1;
	}
	$idx = index($pname, '/');
	if ($idx > 0)
	{
		$category = substr($pname, 0, $idx);
		$pname = substr($pname, $idx + 1);
	}
	if ($have_ver)
	{
		$idx = index($pname, '-');
		while ($idx > 0)
		{
			$pidx = $idx;
			$idx = index($pname, '-', $idx + 1);
		}
		if ($pidx > 0)
		{
			$version = substr($pname, $pidx + 1);
			$pname = substr($pname, 0, $pidx);
		}
		else
		{
			$have_ver = 0;
		}
	}
	#if ($installed)
	#{
	#	print "cond = \"$cond\"\n";
	#	print "pname = $pname\n";
	#	print "version = $version\n";
	#}

	# find category with this $pname
	if (length($category) == 0)
	{
		if (opendir($dh_p, $portdir))
		{
			$dir_p_ent = readdir($dh_p);
			while ($dir_p_ent)
			{
				(undef,undef,$ent_p_mode,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef) = stat($portdir . "/" . $dir_p_ent);
				if (S_ISDIR($ent_p_mode))
				{
					#if ($dir_p_ent ne '.' && $dir_p_ent ne '..')
					if (!($dir_p_ent =~ m/^\..*$/))
					{
						$dirname = $portdir . "/" . $dir_p_ent;
						if (opendir($dh, $dirname))
						{
							$dir_ent = readdir($dh);
							while ($dir_ent)
							{
								(undef,undef,$ent_mode,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef) = stat($dirname . "/" . $dir_ent);
								if (S_ISDIR($ent_mode))
								{
									#if ($dir_ent ne '.' && $dir_ent ne '..')
									if (!($dir_ent =~ m/^\..*$/))
									{
										#print "$dir_p_ent/$dir_ent\n";
										if ($installed)
										{
											$len = length($pname);
											if (length($dir_ent) > $len + 1)
											{
												$tstr = substr($dir_ent, $len);
												if (substr($dir_ent, 0, $len) eq $pname && substr($tstr, 0, 1) eq '-')
												{
													$tstr = substr($tstr, 1);
													if (pkg_version::is_valid_version($tstr))
													{
														$conflict = 1 if length($category) > 0;
														$category = $dir_p_ent;
													}
												}
											}
										}
										else
										{
											if ($dir_ent eq $pname)
											{
												$conflict = 1 if length($category) > 0;
												$category = $dir_p_ent;
											}
										}
									}
								}
								$dir_ent = readdir($dh);
							}
							closedir($dh);
						}
					}
				}
				$dir_p_ent = readdir($dh_p);
			}
			closedir($dh_p);
		}
		else
		{
			print "No such file or directory: $portdir\n";
			return $res;
		}
	}
	if ($conflict)
	{
		print "Founded this atom $patom in multiple categories!\n";
		print "Please specify category\n";
		return $res;
	}
	#print "category = $category\n";
	if (length($category) > 0)
	{
		if ($installed)
		{
			$dirname = $portdir . '/' . $category;
		}
		else
		{
			$dirname = $portdir . '/' . $category . '/' . $pname;
		}
		if (opendir($dh, $dirname))
		{
			$dir_ent = readdir($dh);
			while ($dir_ent)
			{
				(undef,undef,$ent_mode,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef) = stat($dirname . "/" . $dir_ent);
				if ($installed)
				{
					if (S_ISDIR($ent_mode))
					{
						# here in regex we can't use $pname, that is can contains special characters (gcc-core-c++)
						$len = length($pname);
						if (length($dir_ent) > $len + 1 &&
							substr($dir_ent, 0, $len) eq $pname &&
							substr($dir_ent, $len, 1) eq '-')
						{
							$cand_ver_s = substr($dir_ent, $len + 1);
							%cand_ver = pkg_version::parse_version($cand_ver_s);
							if (defined($cand_ver{major}))
							{
								#print "dir_ent = $dir_ent, mode = $ent_mode, version = $cand_ver_s\n";
								if ($version)
								{
									if (pkg_version::version_test($cond, $version, \%cand_ver))
									{
										push(@candidates, $dirname . '/' . $dir_ent .  '/' . $dir_ent . ".$xbuild_ext");
									}
								}
								else
								{
									push(@candidates, $dirname . '/' . $dir_ent . '/' . $dir_ent . ".$xbuild_ext");
								}
							}
							else
							{
								print "$dir_ent have invalid version number, skipped!\n";
							}
						}
					}
				}
				else
				{
					if (S_ISREG($ent_mode))
					{
						# here in regex we can't use $pname, that is can contains special characters (gcc-core-c++)
						$len = length($pname);
						if (length($dir_ent) > $len + 1 + 1 + length($xbuild_ext) &&
							substr($dir_ent, 0, $len) eq $pname &&
							substr($dir_ent, $len, 1) eq '-')
						{
							if ($dir_ent =~ m/^.*\.$xbuild_ext$/)
							{
								$cand_ver_s = substr($dir_ent, $len + 1);
								$cand_ver_s =~ s/\.$xbuild_ext//;
								%cand_ver = pkg_version::parse_version($cand_ver_s);
								if (defined($cand_ver{major}))
								{
									#print "dir_ent = $dir_ent, mode = $ent_mode, version = $cand_ver_s\n";
									if ($version)
									{
										if (pkg_version::version_test($cond, $version, \%cand_ver))
										{
											push(@candidates, $dirname . '/' . $dir_ent);
										}
									}
									else
									{
										push(@candidates, $dirname . '/' . $dir_ent);
									}
								}
								else
								{
									print "$dir_ent have invalid version number, skipped!\n";
								}
							}
						}
					}
				}
				$dir_ent = readdir($dh);
			}
			closedir($dh);
		}
		else
		{
			#print "No such file or directory: $dirname\n";
			return $res;
		}
	}
	else
	{
		print "Not found: $patom\n";
		return $res;
	}

	# select newest in candidates.
	undef(%cand_ver_p);
	for $candidate (@candidates)
	{
		$tstr = basename($candidate);
		$len = length($pname);
		$tstr = substr($tstr, $len + 1);
		if ($tstr =~ m/^(.*)\.$xbuild_ext$/)
		{
			$cand_ver_s = $1;
			%cand_ver = pkg_version::parse_version($cand_ver_s);
			$cmp_res = pkg_version::version_compare(\%cand_ver, \%cand_ver_p);
			if ($cmp_res > 0)
			{
				$res = $candidate;
				%cand_ver_p = %cand_ver;
			}
		}
	}

	return $res;
}

=item C<xbuild_info>
X<xbuild_info> 

Return hash with information abount package by build script.

  %pkg_info = xbuild_info("/build/portage/media-libs/libogg/libogg-1.3.0.xbuild");

Returned hash consist following keys:
bldext - extension of build script
cat - package category
pn - package name
pv - package version
pr - build script revision
pvr - package version with revision
p - package name with version
pf - package name with version and revision

=cut

sub xbuild_info($)
{
	my ($file) = @_;
	my %res;
	my %empty;
	my %parsed_ver;
	my $tstr;
	my ($filename, $path, $suffix) = fileparse($file, q/\.\w*/);
	my ($idx, $pidx);

	if ($suffix =~ m/^\.(\w*)$/)
	{
		$res{bldext} = $1;
	}
	else
	{
		return %empty;
	}

	$pidx = -1;
	$idx = index($filename, '-');
	while ($idx > 0)
	{
		$pidx = $idx;
		$idx = index($filename, '-', $idx + 1);
	}
	# failed...
	return %empty if $pidx == -1;

	$res{pn} = substr($filename, 0, $pidx);
	$res{pvr} = substr($filename, $pidx + 1);
	$idx = index($res{pvr}, '-');
	if ($idx > 0)
	{
		$res{pv} = substr($res{pvr}, 0, $idx);
		$res{pr} = substr($res{pvr}, $idx + 1);
	}
	else
	{
		$res{pv} = $res{pvr};
		$res{pr} = "";
	}
	$res{p} = $res{pn} . '-' . $res{pv};
	$res{pf} = $res{pn} . '-' . $res{pvr};

	# fetch category
	$tstr = dirname($file);
	return %empty if !$tstr || $tstr eq '.';
	$tstr = dirname($tstr);
	return %empty if !$tstr || $tstr eq '.';
	$res{cat} = basename($tstr);

	return %res;
}

sub my_chomp;

=item C<add_to_world>
X<add_to_world> 

=cut

sub add_to_world($)
{
	my ($xbuild) = @_;
	my $world = $portage_info{metadata} . "/world";
	my $fh;
	my %info = xbuild_info($xbuild);
	my $record = "$info{cat}/$info{pn}";
	my $found = 0;
	my @lines;
	my $res = 0;
	#$world =~ tr|/|\\|;
	if (open($fh, "< $world"))
	{
		my @lines = <$fh>;
		foreach (@lines)
		{
			my_chomp;
			if ($_ eq $record)
			{
				$found = 1;
				last;
			}
		}
		close($fh);
	}
	if (!$found)
	{
		if (open($fh, ">> $world"))
		{
			$res = print $fh "$record\n";
			close($fh);
		}
		else
		{
			print "Can't open for writing: $world\n";
		}
	}
	return $res;
}

=item C<remove_from_world>
X<remove_from_world> 

=cut

sub remove_from_world($)
{
	my ($xbuild) = @_;
	my $world = $portage_info{metadata} . "/world";
	my $res = 0;
	my ($tw_fh, $tmpworld) = File::Temp::tempfile(DIR => $portage_info{metadata});

	my $fh;
	my %info = xbuild_info($xbuild);
	my $record = "$info{cat}/$info{pn}";
	my $found = 0;
	my @lines;
	if (open($fh, "< $world"))
	{
		@lines = <$fh>;
		sort @lines;
		foreach (@lines)
		{
			my_chomp;
			print $tw_fh "$_\n" if $_ ne $record;
		}
		close($fh);
		close($tw_fh);
		$res = unlink($world);
		$res = rename($tmpworld, $world) if $res;
	}
	else
	{
		close($tw_fh);
	}
	return $res;
}

=item C<is_in_world>
X<is_in_world> 

Check if package associated with specified xbuild is in world file. 
Return 1 if package is registered in world, 0 otherwise.

=cut

sub is_in_world($)
{
	my ($xbuild) = @_;
	my $world = $portage_info{metadata} . "/world";
	my $fh;
	my %info = xbuild_info($xbuild);
	my $record = "$info{cat}/$info{pn}";
	my $found = 0;
	my @lines;
	if (open($fh, "< $world"))
	{
		@lines = <$fh>;
		foreach (@lines)
		{
			my_chomp;
			if ($_ eq $record)
			{
				$found = 1;
				last;
			}
		}
		close($fh);
	}
	return $found;
}

sub get_system_set()
{
	return @system_set;
}

sub get_world_set()
{
	my $world = $portage_info{metadata} . "/world";
	my $fh;
	my @packages;
	my @lines;
	if (open($fh, "< $world"))
	{
		@lines = <$fh>;
		foreach (@lines)
		{
			my_chomp;
			push(@packages, $_);
		}
		close($fh);
	}
	return @packages;
}

# In msys perl standard function chomp don't remove \r char from sequence '\r\n'.
sub my_chomp
{
	my $res = 0;
	my $line;
	if (defined($_[0]))
	{
		$line = \$_[0];
	}
	else
	{
		$line = \$_;
	}
	my $len = length($$line);
	my $c;
	if ($len > 0)
	{
		$c = ord(substr($$line, $len - 1, 1)); 
		if ($c == 0x0A)
		{
			$$line = substr($$line, 0, $len - 1);
			$len--;
			$res++;
		}
	}
	if ($len > 0)
	{
		$c = ord(substr($$line, $len - 1, 1)); 
		if ($c == 0x0D)
		{
			$$line = substr($$line, 0, $len - 1);
			$res++;
		}
	}
	return $res;
}

1;
