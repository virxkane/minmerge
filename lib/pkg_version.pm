# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

=head1 NAME

pkg_version - Methods for parse and compare packages version string.

=head1 SYNOPSIS

    require "<custom libs path>/pkg_version.pm";
	import pkg_version;
	
	$vv1 = "1.1";
	%vvv1 = parse_version($vv1);
	$vv2 = "1.2_pre20140405";
	%vvv2 = parse_version($vv2);
	$cmp_res = version_compare(\%vvv1, \%vvv2);
	print "version_compare($vv1, $vv2) return $cmp_res\n";

	$ver = "1.2.3";
	%ver = parse_version($ver);
	$pat = "1.2.6";
	$cond = '>';
	$cmp_res = version_test($cond, $pat, \%ver);
	print "version_test($cond, $pat, $ver) return $cmp_res\n";


=head1 DESCRIPTION

These routines allow you to run various script or shell commands.
But this scripts/commands must be non interactive, i.e. output only!


=cut

package pkg_version;

use 5.006;
use strict;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(parse_version is_valid_version version2string version_test version_compare);

=over 4

=item C<parse_version>
X<parse_version> 

Parse version string to hash
keys: major, minor, patch, ts, st_w, stage, stage_num, subrel
      ts - timestamp, st_w - weight of stage
for 1.2.8:           major=>1, minor=>2, patch=>8, ts=>undef, st_w=>0, stage=>undef, stage_num=>undef, subrel=>undef
for 1.2.8-r5:        major=>1, minor=>2, patch=>8, ts=>undef, st_w=>0, stage=>undef, stage_num=>undef, subrel=>5
for 1.2.8_rc4:       major=>1, minor=>2, patch=>8, ts=>undef, st_w=>-1, stage=>rc,    stage_num=>4, subrel=>undef
for 1.2.8_alpha5-r6: major=>1, minor=>2, patch=>8, ts=>undef, st_w=>-10, stage=>alpha, stage_num=>5, subrel=>6
for 1.2.8_beta:      major=>1, minor=>2, patch=>8, ts=>undef, st_w=>-8, stage=>beta,  stage_num=>0, subrel=>undef
for 1.2:             major=>1, minor=>2, patch=>undef, ts=>undef, st_w=>0, stage=>undef, stage_num=>undef, subrel=>undef
for 6b:              major=>6.02, minor=>undef, patch=>undef, ts=>undef, st_w=>0, stage=>undef, stage_num=>undef, subrel=>undef
for 2014a:           major=>2014.01, minor=>undef, patch=>undef, ts=>undef, st_w=>0, stage=>undef, stage_num=>undef, subrel=>undef
for 1.0.1h-r1:       major=>1, minor=>0, patch=>1.08, ts=>undef, st_w=>0, stage=>undef, stage_num=>undef, subrel=>1

=cut

sub parse_version($;$)
{
	my ($ver, $is_pattern) = @_;
	my %res;
	my %empty_hash;
	my $idx;
	my $tstr;
	my $c;
	my $stage;
	my $val;
	my $val_frac;
	my @vparts;
	my $key;
	my $broken = 0;
	my $m;

	if (defined($is_pattern) && $is_pattern == 0)
	{
		undef($is_pattern);
	}

	# check sub release
	$idx = index($ver, '-');
	if ($idx > 0)
	{
		if ($idx < length($ver) - 2)
		{
			$tstr = substr($ver, $idx + 1);
			if ($tstr =~ m/^r(\d+)/)
			{
				$val = $1;
				$res{subrel} = $val;
				$ver = substr($ver, 0, $idx);
			}
			else
			{
				$broken = 1;
			}
		}
		else
		{
			$broken = 1;
		}
	}
	return %empty_hash if $broken;

	# check stage name & stage number
	$idx = index($ver, '_');
	if ($idx > 0 && $idx < length($ver) - 1)
	{
		$tstr = substr($ver, $idx + 1);
		if ($tstr =~ m/^([alphbetrc]+)(\d*|\*)$/)
		{
			$stage = $1;
			$val = $2;
			if ($val eq '*' && !$is_pattern)
			{
				$broken = 1;
			}
			else
			{
				if ($stage eq $tstr && ($stage eq 'p' || $stage eq 'pre'))
				{
					$broken = 1;
				}
				else
				{
					if ($stage eq $tstr)
					{
						$val = 0;
					}
					if ($stage eq 'rc' || $stage eq 'beta' || $stage eq 'alpha' || $stage eq 'pre' || $stage eq 'p')
					{
						$res{stage} = $stage;
						$res{stage_num} = $val;
						$ver = substr($ver, 0, $idx);
					}
					else
					{
						$broken = 1;
					}
				}
			}
		}
		else
		{
			$broken = 1;
		}
	}
	return %empty_hash if $broken;
	# assign stage weight
	if ($res{stage} eq "alpha")
	{
		$res{st_w} = -10;
	}
	elsif ($res{stage} eq "beta")
	{
		$res{st_w} = -8;
	}
	elsif ($res{stage} eq "pre")
	{
		$res{st_w} = -6;
	}
	elsif ($res{stage} eq "rc")
	{
		$res{st_w} = -4;
	}
	elsif ($res{stage} eq "p")
	{
		# TODO: clear up weight of stage 'p' (patch), may be real weight less then 0;
		$res{st_w} = 2;
	}
	else
	{
		$res{st_w} = 0;
	}

	# extract major, minor, patch & timestamp(ts) numbers
	@vparts = split(/\./, $ver, 4);
	my @keys = ('ts', 'patch', 'minor', 'major');
	foreach $tstr (@vparts)
	{
		if ($tstr =~ m/^(\d+)([a-z]*)|(\*)$/)
		{
			$val = $1;
			$key = pop @keys;
			if ($3)
			{
				if ($is_pattern)
				{
					$val = $3;
				}
				else
				{
					$broken = 1;
					last;
				}
			}
			else
			{
				if (length($2) > 0)
				{
					$tstr = $2;
					$m = 0.01;
					while ($tstr)
					{
						$c = substr($tstr, 0, 1);
						$val += $m*(ord($c) - ord('a') + 1);
						$tstr = substr($tstr, 1);
						$m *= 0.01;
					}
				}
			}
			$res{$key} = $val;
		}
		else
		{
			$broken = 1;
			last;
		}
	}
	return %empty_hash if $broken;

	return %res;
}

=item C<is_valid_version>
X<is_valid_version> 

Check version string for valid.

=cut

sub is_valid_version($)
{
	my %ver = parse_version(@_);
	return defined($ver{major});
}


=item C<version2string>
X<version2string> 

Convert version hash to string

=cut

sub version2string(%)
{
	my (%ver) = @_;
	return "undef" if !defined($ver{major});
	my $res = $ver{major};
	$res .= "." . $ver{minor} if defined($ver{minor});
	$res .= "." . $ver{patch} if defined($ver{patch});
	$res .= "." . $ver{ts} if defined($ver{ts});
	if (defined($ver{stage}))
	{
		$res .= "_" . $ver{stage};
		if (defined($ver{stage_num}) && $ver{stage_num} != 0)
		{
			$res .= $ver{stage_num};
		}
	}
	$res .= "-r" . $ver{subrel} if defined($ver{subrel});
	return $res;
}

=item C<version_test>
X<version_test> 

Test version obtained by function parse_version() and pattern
Usage:
  version_test(<condition>, <pattern>, <version reference>)
  version_test('=', 1.2.*', \%version)
  version_test('>', 1.2.6', \%version)

=cut

sub version_test($$$)
{
	my ($condition, $pattern, $verref) = @_;
	my $res = 0;
	my %ver = %$verref;		# it's a copy of argument
	my %ver_pat = parse_version($pattern, 1);
	my $cmp_res = pattern_version_compare(\%ver_pat, \%ver);
	if ($cmp_res == 0)
	{
		$res = 1 if $condition eq '=';
		$res = 0 if $condition eq '<';
		$res = 0 if $condition eq '>';
		$res = 1 if $condition eq '>=';
		$res = 1 if $condition eq '<=';
	}
	elsif ($cmp_res > 0)
	{
		$res = 0 if $condition eq '=';
		$res = 1 if $condition eq '<';
		$res = 0 if $condition eq '>';
		$res = 0 if $condition eq '>=';
		$res = 1 if $condition eq '<=';
	}
	else
	{
		$res = 0 if $condition eq '=';
		$res = 0 if $condition eq '<';
		$res = 1 if $condition eq '>';
		$res = 1 if $condition eq '>=';
		$res = 0 if $condition eq '<=';
	}
	;
	return $res;
}

=item C<version_compare>
X<version_compare> 

Compare two version hash
return 0 if arguments is equal,
return 1 if first argument biggest then second
return -1 if first argument less then second

=cut

sub version_compare($$)
{
	# TODO: interpret undefined values less then zero.
	# for example: "1.1" and "1.1.0"
	my ($v1ref, $v2ref) = @_;
	my %v1 = %$v1ref;
	my %v2 = %$v2ref;

	#print $v1{major} . ":" . $v2{major} . "\n";
	#print $v1{minor} . ":" . $v2{minor} . "\n";
	#print $v1{patch} . ":" . $v2{patch} . "\n";
	#print $v1{ts} . ":" . $v2{ts} . "\n";
	#print $v1{st_w} . ":" . $v2{st_w} . "\n";
	#print $v1{stage} . ":" . $v2{stage} . "\n";
	#print $v1{stage_num} . ":" . $v2{stage_num} . "\n";
	#print $v1{subrel} . ":" . $v2{subrel} . "\n";

	if ($v1{major} > $v2{major})
	{
		#print "major1 bigger\n";
		return 1;
	}
	elsif ($v1{major} < $v2{major})
	{
		#print "major2 bigger\n";
		return -1;
	}
	if ($v1{minor} > $v2{minor})
	{
		#print "minor1 bigger\n";
		return 1;
	}
	elsif ($v1{minor} < $v2{minor})
	{
		#print "minor2 bigger\n";
		return -1;
	}
	if ($v1{patch} > $v2{patch})
	{
		#print "patch1 bigger\n";
		return 1;
	}
	elsif ($v1{patch} < $v2{patch})
	{
		#print "patch2 bigger\n";
		return -1;
	}
	if ($v1{ts} > $v2{ts})
	{
		#print "ts1 bigger\n";
		return 1;
	}
	elsif ($v1{ts} < $v2{ts})
	{
		#print "ts2 bigger\n";
		return -1;
	}
	if ($v1{st_w} > $v2{st_w})
	{
		#print "st_w1 bigger\n";
		return 1;
	}
	elsif ($v1{st_w} < $v2{st_w})
	{
		#print "st_w2 bigger\n";
		return -1;
	}
	if ($v1{stage_num} > $v2{stage_num})
	{
		#print "stage_num1 bigger\n";
		return 1;
	}
	elsif ($v1{stage_num} < $v2{stage_num})
	{
		#print "stage_num2 bigger\n";
		return -1;
	}
	if ($v1{subrel} > $v2{subrel})
	{
		#print "subrel1 bigger\n";
		return 1;
	}
	elsif ($v1{subrel} < $v2{subrel})
	{
		#print "subrel2 bigger\n";
		return -1;
	}
	return 0;
}

=item C<pattern_version_compare>
X<pattern_version_compare> 

Compare two version hash
first patterned version, second regular version.
return 0 if arguments is equal,
return 1 if first argument biggest then second
return -1 if first argument less then second

=cut

sub pattern_version_compare($$)
{
	my ($v1ref, $v2ref) = @_;
	my %v1 = %$v1ref;
	my %v2 = %$v2ref;
	my ($vv1, $vv2);

	#print $v1{major} . ":" . $v2{major} . "\n";
	#print $v1{minor} . ":" . $v2{minor} . "\n";
	#print $v1{patch} . ":" . $v2{patch} . "\n";
	#print $v1{ts} . ":" . $v2{ts} . "\n";
	#print $v1{st_w} . ":" . $v2{st_w} . "\n";
	#print $v1{stage} . ":" . $v2{stage} . "\n";
	#print $v1{stage_num} . ":" . $v2{stage_num} . "\n";
	#print $v1{subrel} . ":" . $v2{subrel} . "\n";

	$vv1 = $v1{major};
	$vv2 = $v2{major};
	if ($vv1 ne '*')
	{
		if ($vv1 > $vv2)
		{
			#print "major1 bigger\n";
			return 1;
		}
		elsif ($vv1 < $vv2)
		{
			#print "major2 bigger\n";
			return -1;
		}
	}
	$vv1 = $v1{minor};
	$vv2 = $v2{minor};
	if (defined($vv1) && $vv1 ne '*')
	{
		if ($vv1 > $vv2)
		{
			#print "minor1 bigger\n";
			return 1;
		}
		elsif ($vv1 < $vv2)
		{
			#print "minor2 bigger\n";
			return -1;
		}
	}
	$vv1 = $v1{patch};
	$vv2 = $v2{patch};
	if (defined($vv1) && $vv1 ne '*')
	{
		if ($vv1 > $vv2)
		{
			#print "patch1 bigger\n";
			return 1;
		}
		elsif ($vv1 < $vv2)
		{
			#print "patch2 bigger\n";
			return -1;
		}
	}
	$vv1 = $v1{ts};
	$vv2 = $v2{ts};
	if (defined($vv1) && $vv1 ne '*')
	{
		if ($vv1 > $vv2)
		{
			#print "ts1 bigger\n";
			return 1;
		}
		elsif ($vv1 < $vv2)
		{
			#print "ts2 bigger\n";
			return -1;
		}
	}
	if ($v1{st_w} > $v2{st_w})
	{
		#print "st_w1 bigger\n";
		return 1;
	}
	elsif ($v1{st_w} < $v2{st_w})
	{
		#print "st_w2 bigger\n";
		return -1;
	}
	$vv1 = $v1{stage_num};
	$vv2 = $v2{stage_num};
	if (defined($vv1) && $vv1 ne '*')
	{
		if ($vv1 > $vv2)
		{
			#print "stage_num1 bigger\n";
			return 1;
		}
		elsif ($vv1 < $vv2)
		{
			#print "stage_num2 bigger\n";
			return -1;
		}
	}
	$vv1 = $v1{subrel};
	$vv2 = $v2{subrel};
	if (defined($vv1) && $vv1 ne '*')
	{
		if ($vv1 > $vv2)
		{
			#print "subrel1 bigger\n";
			return 1;
		}
		elsif ($vv1 < $vv2)
		{
			#print "subrel2 bigger\n";
			return -1;
		}
	}
	return 0;
}

1;
