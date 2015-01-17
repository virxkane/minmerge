#!/usr/bin/perl

# Copyright 2014-2015 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

use 5.006;
use warnings;

use Cwd;
use Getopt::Long qw/GetOptions Configure/;

use constant MM_VERSION => "0.1.4.1";

# forward function declarations
sub calc_deps($;$$$);
sub check_conflicted_deps(@);
sub remove_duplicates(@);

my $s_help=0;
my $s_depclean=0;
my $s_unmerge=0;
my $s_pretend=0;
my $s_update=0;
my $s_oneshot=0;
my $s_deep=0;
my $s_nodeps=0;
my $s_emptytree=0;
my $s_usepkg=0;
my $s_fetchonly=0;
my $s_verbose=0;
my $s_info=0;
# config values
my $s_msys_path;
my $s_minmerge_path;

Getopt::Long::Configure("bundling", "no_ignore_case");
Getopt::Long::GetOptions(
			'setmsys=s' => \$s_msys_path,
			'setminmerge=s' => \$s_minmerge_path,

			'h|help' => \$s_help,
			'c|depclean' => \$s_depclean,
			'C|unmerge' => \$s_unmerge,

			'p|pretend' => \$s_pretend,
			'u|update' => \$s_update,
			'1|oneshot' => \$s_oneshot,
			'D|deep' => \$s_deep,
			'O|nodeps' => \$s_nodeps,
			'e|emptytree' => \$s_emptytree,
			'k|usepkg' => \$s_usepkg,
			'f|fetchonly' => \$s_fetchonly,
			'v|verbose' => \$s_verbose,
			'i|info' => \$s_info
		);

if ($s_help)
{
	print << 'EOF';
Usage: minmerge.pl <config_opts> || <opts> <pkg_name>
configure  options:
   --setmsys <path>     Set path to msys and exit.
   --setminmerge <path> Set path to minmerge and exit.
options:
   -h
   --help       Show this screen.
   -i
   --info       Show some information about configuration.
   -c
   --depclean   Cleans the system by removing packages that are not associated with explicitly merged packages.
   -C
   --unmerge    Removes all matching packages.

   -p
   --pretend    Only show list of affected packages.
   -u
   --update     When we check dependencies we also check new version of packages.
   -1
   --oneshot    Do not add to packages world list.
   -D
   --deep       Check dependencies recursively.
   -O
   --nodeps     Merges specified packages without merging any dependencies.
   -e
   --emptytree  Reinstalls target atoms and their entire deep dependency tree.
   -k
   --usepkg     Install package from existing binary packages instead of building from sources.
   -f
   --fetchonly  Instead of package build just download sources.
   -v
   --verbose    Be more verbose.
EOF
	exit 0;
}

$MINMERGE_PATH = undef;
$MSYS_PATH = undef;

# Read minmerge & msys path from config.
my $home = $ENV{'HOME'};					# in msys envoronment
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
			$MSYS_PATH = $value if $key eq 'msys_path';
		}
		close($fh);
	}
	else
	{
		print "Can't read config file: \"$cfg_path\"!\n";
		exit 1;
	}
}

if ($s_msys_path)
{
	$MSYS_PATH = $s_msys_path;
}
if ($s_minmerge_path)
{
	$MINMERGE_PATH = $s_minmerge_path;
}
if ($s_msys_path || $s_minmerge_path)
{
	if (open($fh, "> $cfg_path"))
	{
		print $fh "minmerge_path = $MINMERGE_PATH\n";
		print $fh "msys_path = $MSYS_PATH\n";
		close($fh);
		print "Configuration writen, exiting.";
		exit 0;
	}
	else
	{
		print "Can't open \"$cfg_path\" for writing!\n";
		exit 1;
	}
}


if (!$MSYS_PATH || !$MINMERGE_PATH)
{
	print << 'EOF';
minmerge not configured. You must configure minmerge, for example,
./minmerge.pl --setmsys c:/msys/1.0 --setminmerge c:/msys/1.0/build/minmerge
 or 
./minmerge.pl --setmsys c:/msys/1.0 --setminmerge $PWD
EOF
	exit 1;
}

$SHELL = $MSYS_PATH . '/bin/sh.exe';
$SHELL = $MSYS_PATH . '/usr/bin/sh.exe' if ! -f $SHELL;
$XBUILD = $MINMERGE_PATH . '/xbld.pl';

require "$MINMERGE_PATH/lib/pkg_version.pm";
import pkg_version;
require "$MINMERGE_PATH/lib/shellscript.pm";
import shellscript;
require "$MINMERGE_PATH/lib/msyspathmap.pm";
import msyspathmap;
require "$MINMERGE_PATH/lib/my_chomp.pm";
import my_chomp;
require "$MINMERGE_PATH/lib/pkgdb.pm";
import pkgdb;
require "$MINMERGE_PATH/lib/xbuild.pm";
import xbuild;
	
shellscript::setshell($SHELL);
$MINMERGE_PATH = posix2w32path($MINMERGE_PATH);
xbuild::set_minmerge($MINMERGE_PATH);

# main

my $prefix;
my $prefix_w32;
my $portdir;
my $portdir_w32;
my $pkgdbbase;
my %features;

my @pkg_atoms;
my $pkg_atom;
my @xbuilds;		# build scripts for specified atoms
my $xbuild;
my %xbuild_info;
my $xbuild_cmds;
my @all_xbuilds;	# build scripts for specified atoms & dependencies
my $all_dep_xbuilds;

$prefix = get_minmerge_configval("PREFIX");
$prefix_w32 = posix2w32path($prefix);
$pkgdbbase = $prefix_w32 . "/var/db/pkg";
$portdir = get_minmerge_configval("PORTDIR");
$portdir_w32 = posix2w32path($portdir);
# parse features
{
	my $str = get_minmerge_configval("FEATURES");
	$str =~ s/\s*(.*)\s*/$1/;
	$str =~ s/\s+/ /;
	foreach (split(/ /, $str))
	{
		$features{$_} = 1;
	}
}

if ($s_info)
{
	my $chost = get_minmerge_configval("CHOST");
	my $cbuild = get_minmerge_configval("CBUILD");
	my $cflags = get_minmerge_configval("CFLAGS");
	my $cxxflags = get_minmerge_configval("CXXFLAGS");
	my $makeopts = get_minmerge_configval("MAKEOPTS");
	my @distdir;
	my @distdir_w32;
	my $i;
	$distdir[0]= get_minmerge_configval("DISTDIR");
	$distdir_w32[0] = posix2w32path($distdir[0]);
	for ($i = 2; $i < 10; $i++)
	{
		$distdir[$i - 1] = get_minmerge_configval("DISTDIR$i");
		next if (!$distdir[$i - 1]);
		$distdir_w32[$i - 1] = posix2w32path($distdir[$i - 1]);
	}
	my $pkgdir = get_minmerge_configval("PKGDIR");
	my $pkgdir_w32 = posix2w32path($pkgdir);
	my $tmpdir = get_minmerge_configval("TMPDIR");
	my $tmpdir_w32 = posix2w32path($tmpdir);
	my $perl_path = get_minmerge_configval("PERL_PATH");
	my $perl_path_w32 = posix2w32path($perl_path);
	my $python_path = get_minmerge_configval("PYTHON_PATH");
	my $python_path_w32 = posix2w32path($python_path);

	print "version: " . MM_VERSION . "\n";
	print "minmerge path: $MINMERGE_PATH\n";
	print "msys path: $MSYS_PATH\n";
	print "\n";
	print "PREFIX: $prefix => $prefix_w32\n";
	print "CHOST: $chost\n";
	print "CBUILD: $cbuild\n";
	print "CFLAGS: $cflags\n";
	print "CXXFLAGS: $cxxflags\n";
	print "MAKEOPTS: $makeopts\n";
	print "PORTDIR: $portdir => $portdir_w32\n";
	print "DISTDIR: $distdir[0] => $distdir_w32[0]\n";
	for ($i = 2; $i < 10; $i++)
	{
		next if (!$distdir[$i-1]);
		print "DISTDIR$i: $distdir[$i-1] => $distdir_w32[$i-1]\n";
	}
	print "PKGDIR: $pkgdir => $pkgdir_w32\n";
	print "TMPDIR: $tmpdir => $tmpdir_w32\n";
	print "FEATURES: ";
	while (my ($_key, $_val) = each %features)
	{
		print $_key . " " if $_val;
	}
	print "\n";
	print "PERL_PATH: $perl_path => $perl_path_w32\n";
	print "PYTHON_PATH: $python_path => $python_path_w32\n";
	exit 0;
}

@pkg_atoms = @ARGV;

setportage_info({bldext => 'xbuild', prefix => $prefix_w32, portdir => $portdir_w32, metadata => $pkgdbbase});

if ($s_depclean)
{
	print "Sorry, depclean mode not implemented yet!";
	exit 1;
}
if ($s_usepkg)
{
	print "Sorry, installing from binary packages not implemented yet!";
	exit 1;
}

if ($s_unmerge != 0)
{
	$xbuild_cmds = "unmerge";
}
elsif ($s_fetchonly)
{
	$xbuild_cmds = "fetch";
}
else
{
	$xbuild_cmds = "merge clean";
	$xbuild_cmds .= " package" if $features{buildpkg};
}

# replace special names 'system' & 'world' to appropriate atoms set
my @set_list;
my $have_set = 0;
foreach (@pkg_atoms)
{
	if ($_ eq 'system')
	{
		push(@set_list, get_system_set());
		$have_set = 1;
	}
	elsif ($_ eq 'world')
	{
		push(@set_list, get_system_set());
		push(@set_list, get_world_set());
		$have_set = 1;
	}
	else
	{
		if ($have_set)
		{
			print "You can't specify any package atoms with named set together!";
			exit 1;
		}
	}
}
if ($have_set)
{
	if ($s_unmerge)
	{
		print "You can't delete this package set!\n";
		exit 1;
	}
	$s_oneshot = 1;
	@pkg_atoms = @set_list;
}

# perform atoms: find appropriate xbuilds
foreach $pkg_atom (@pkg_atoms)
{
	if ($s_unmerge)
	{
		$xbuild = find_installed_xbuild($pkg_atom);
		if (defined($xbuild))
		{
			push(@xbuilds, $xbuild);
		}
		else
		{
			print "package for this atom \"$pkg_atom\" not installed!\n";
		}
	}
	else
	{
		$xbuild = find_xbuild($pkg_atom);
		if (defined($xbuild))
		{
			push(@xbuilds, $xbuild);
		}
		else
		{
			print "for atom $pkg_atom xbuild not found!\n";
		}
	}
}

# calculate dependencies
if (!$s_nodeps and !$s_unmerge)
{
	#  calc dependencies
	my @dep_xbuilds;
	my @all_dep_xbuilds;
	foreach $xbuild (@xbuilds)
	{
		@dep_xbuilds = calc_deps($xbuild, $s_update, $s_deep, $s_emptytree);
		push(@all_dep_xbuilds, @dep_xbuilds) if @dep_xbuilds;
	}
	push(@all_xbuilds, @all_dep_xbuilds) if @all_dep_xbuilds;
}
push(@all_xbuilds, @xbuilds);
@all_xbuilds = remove_duplicates(@all_xbuilds);
check_conflicted_deps(@all_xbuilds);

my $pkg_stat;
my $xbuild_inst;
my %inst_pkg_info;
my %new_ver;
my %exs_ver;
my $exs_ver_line;
my $cmp_res;

# Remove from $all_xbuilds xbuilds from $xbuilds which
# don't need to update and flag $s_update != 0.
if ($s_update && !$s_emptytree)
{
	my $found;
	my @tmplist;
	foreach $xbuild (@all_xbuilds)
	{
		$found = 0;
		foreach (@xbuilds)
		{
			if ($xbuild eq $_)
			{
				$found = 1;
				last;
			}
		}
		if ($found)
		{
			%xbuild_info = xbuild_info($xbuild);
			$xbuild_inst = find_installed_xbuild($xbuild_info{cat} . '/' . $xbuild_info{pn});
			if ($xbuild_inst)
			{
				%inst_pkg_info = xbuild_info($xbuild_inst);
				if ($xbuild_info{pvr} ne $inst_pkg_info{pvr})
				{
					push(@tmplist, $xbuild);
				}
			}
			else
			{
				push(@tmplist, $xbuild);
			}
		}
		else
		{
			push(@tmplist, $xbuild);
		}
	}
	@all_xbuilds = @tmplist;
}

# Show information about affected packages
if (($s_pretend || $s_verbose) && !$s_unmerge)
{
	foreach $xbuild (@all_xbuilds)
	{
		$pkg_stat = '[';
		# add label for world status of package
		if (is_in_world($xbuild))
		{
			$pkg_stat .= 'W';
		}
		else
		{
			$pkg_stat .= ' ';
		}
		%xbuild_info = xbuild_info($xbuild);
		%new_ver = parse_version($xbuild_info{pvr});
		if (!defined($xbuild_info{pn}))
		{
			print "Invalid build script: $xbuild\n";
			next;
		}
		$xbuild_inst = find_installed_xbuild($xbuild_info{cat} . '/' . $xbuild_info{pn});
		if ($xbuild_inst)
		{
			%inst_pkg_info = xbuild_info($xbuild_inst);
			%exs_ver = parse_version($inst_pkg_info{pvr});
			$cmp_res = version_compare(\%new_ver, \%exs_ver);
			if ($cmp_res == 0)
			{
				$pkg_stat .= ' R  ';
				$exs_ver_line = '';
			}
			elsif ($cmp_res > 0)
			{
				$pkg_stat .= '  U ';
				$exs_ver_line = '[' . $inst_pkg_info{pvr} . ']';
			}
			else
			{
				$pkg_stat .= '  UD';
				$exs_ver_line = '[' . $inst_pkg_info{pvr} . ']';
			}
		}
		else
		{
			$pkg_stat .= 'N   ';
			$exs_ver_line = '';
		}
		$pkg_stat .= ']';
		print $pkg_stat . " " . $xbuild_info{cat} . '/' . $xbuild_info{pf} . ' ' . $exs_ver_line . "\n";
	}
}
exit 0 if $s_pretend;

# call $XBUILD with arguments
print "\n";
my $current = 0;
foreach $xbuild (@all_xbuilds)
{
	$current++;
	%xbuild_info = xbuild_info($xbuild);
	if (!$s_unmerge)
	{
		print ">>> Emerging ($current of " . ($#all_xbuilds + 1) .") $xbuild_info{cat}/$xbuild_info{pf}\n";
	}
	system($^X, $XBUILD, $xbuild, $xbuild_cmds);
	if ($?)
	{
		print "Failed at $xbuild\n";
		exit 1;
	}
	else
	{
		if (!$s_unmerge)
		{
			if (!$s_oneshot  && !$s_fetchonly)
			{
				foreach (@xbuilds)
				{
					if ($_ eq $xbuild)
					{
						if (!is_in_world($xbuild))
						{
							print("Register in world: $xbuild_info{cat}/$xbuild_info{pn}\n");
							add_to_world($xbuild);
						}
					}
				}
			}
		}
		else
		{
			foreach (@xbuilds)
			{
				if ($_ eq $xbuild)
				{
					if (is_in_world($xbuild))
					{
						print("Unregister in world: $xbuild_info{cat}/$xbuild_info{pn}\n");
						remove_from_world($xbuild);
					}
				}
			}
		}
	}
}




# functions

# Calculate dependencies for specified build script.
# return list of build scripts for noninstalled dependents packages.
my @_xbuilds_stack;
sub calc_deps_private($$$$);
sub calc_deps($;$$$)
{
	my ($xbuild, $update, $deep, $empty) = @_;
	@_xbuilds_stack = ();
	return remove_duplicates(reverse(calc_deps_private($xbuild, $update, $deep, $empty)));
}

sub calc_deps_private($$$$)
{
	my ($xbuild, $update, $deep, $empty) = @_;

	my @dep_atoms;
	my $dep_atom;
	my $dep_xbuild;
	my $_xbuild;
	my @all_dep_xbuilds;
	my @dep_dep_xbuilds;
	my (%info1, %info2);

	push(@_xbuilds_stack, $xbuild);
	@dep_atoms = get_depends($xbuild);

	# special value '||' interprets as exclusively OR for left & right atoms.
	my @tmp_deps;
	my $left_atom;
	my $right_atom;
	my $count = 0;
	my $or_pos = -1;
	foreach (@dep_atoms)
	{
		$right_atom = $_;
		$count++;
		if ($or_pos > 0 && $count > 2)
		{
			$dep_xbuild = find_installed_xbuild($left_atom);
			$_xbuild = find_installed_xbuild($right_atom);
			if ($dep_xbuild && $_xbuild)
			{
				print "Only one may be installed: $left_atom || $right_atom!\n";
				exit 1;
			}
			elsif ($dep_xbuild)
			{
				push(@tmp_deps, $left_atom);
			}
			elsif ($_xbuild)
			{
				push(@tmp_deps, $right_atom);
			}
			else
			{
				push(@tmp_deps, $left_atom);
			}
			$or_pos = -1;
			next;
		}
		if ($right_atom eq '||')
		{
			$or_pos = $count - 1;
			die "Invalid usage of operator '||'!\n" if $or_pos == 0;
			pop(@tmp_deps);
		}
		else
		{
			$left_atom = $right_atom;
			push(@tmp_deps, $right_atom);
		}
		
	}
	if ($right_atom && $right_atom eq '||')
	{
		die "Invalid usage of operator '||'!\n";
	}
	@dep_atoms = @tmp_deps;

	foreach $dep_atom (@dep_atoms)
	{
		if (substr($dep_atom, 0, 1) eq '!')
		{
			$dep_atom = substr($dep_atom, 1);
			$dep_xbuild = find_installed_xbuild($dep_atom);
			die "$xbuild: Found installed package that blocks me: $dep_atom\n" if $dep_xbuild;
			next;
		}
		if ($empty)
		{
			$dep_xbuild = find_xbuild($dep_atom);
			die "Package not found for this atom: $dep_atom\n" if !$dep_xbuild;
			# before we going into recursion check circular dependencies...
			foreach (@_xbuilds_stack)
			{
				die "Circular dependencies detected: $_ => $xbuild\n" if $dep_xbuild eq $_;
			}
			push(@all_dep_xbuilds, $dep_xbuild);
			@dep_dep_xbuilds = calc_deps_private($dep_xbuild, $update, $deep, $empty);
			push(@all_dep_xbuilds, @dep_dep_xbuilds) if @dep_dep_xbuilds;
		}
		else
		{
			$dep_xbuild = find_installed_xbuild($dep_atom);
			if (!$dep_xbuild)
			{
				$_xbuild = find_xbuild($dep_atom);
				die "Package not found for this atom: $dep_atom\n" if !$_xbuild;
				# before we going to recurse check circular dependencies...
				foreach (@_xbuilds_stack)
				{
					die "Circular dependencies detected: $_ => $xbuild\n" if $_xbuild eq $_;
				}
				push(@all_dep_xbuilds, $_xbuild);
				@dep_dep_xbuilds = calc_deps_private($_xbuild, $update, $deep, $empty);
				push(@all_dep_xbuilds, @dep_dep_xbuilds) if @dep_dep_xbuilds;
			}
			else
			{
				if ($update || $deep)
				{
					$_xbuild = find_xbuild($dep_atom);
					die "Package not found for this atom: $dep_atom\n" if !$_xbuild;
				}
				if ($update)
				{
					%info1 = xbuild_info($dep_xbuild);
					%info2 = xbuild_info($_xbuild);
					push(@all_dep_xbuilds, $_xbuild) if $info2{pvr} ne $info1{pvr};
				}
				if ($deep)
				{
					# before we going into recursion check circular dependencies...
					foreach (@_xbuilds_stack)
					{
						die "Circular dependencies detected: $_ => $xbuild\n" if $_xbuild eq $_;
					}
					@dep_dep_xbuilds = calc_deps_private($_xbuild, $update, $deep, $empty);
					push(@all_dep_xbuilds, @dep_dep_xbuilds) if @dep_dep_xbuilds;
				}
			}
		}
	}
	pop(@_xbuilds_stack);
	return @all_dep_xbuilds;
}

sub remove_duplicates(@)
{
	my @new_list;
	my $item;
	my $found;
	foreach $item (@_)
	{
		$found = 0;
		foreach (@new_list)
		{
			if ($item eq $_)
			{
				$found = 1;
				last;
			}
		}
		push(@new_list, $item) if !$found;
	}
	return @new_list;
}

# check for duplicated packages with various versions (same {pn} but differs {pvr}).
sub check_conflicted_deps(@)
{
	my @cp = @_;			# just a copy
	my ($item1, $item2);
	foreach $item1 (@_)
	{
		foreach $item2 (@cp)
		{
			next if $item1 eq $item2;
			%info1 = xbuild_info($item1);
			%info2 = xbuild_info($item2);
			if ($info1{pn} eq $info2{pn} and $info1{pvr} ne $info2{pvr})
			{
				print "Found conflicted dependencies for $xbuild:\n";
				print "  $item1\n";
				print "  $item2\n";
				exit 1;
			}
		}
	}
}
