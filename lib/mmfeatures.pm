#######################################################################
#  Copyright 2015 Chernov A.A. <valexlin@gmail.com>                   #
#  This is a part of mingw-portage project:                           #
#  http://sourceforge.net/projects/mingwportage/                      #
#  Distributed under the terms of the GNU General Public License v3   #
#######################################################################

=head1 NAME

mmfeatures - functions to parse minmerge features.

=head1 SYNOPSIS

	require "<custom libs path>/mmfeatures.pm";
	import mmfeatures;

	%features = parse_features($string);


=head1 DESCRIPTION

These routines allow you to parse features in string form into allowed predefined features.


=cut

package mmfeatures;

use 5.006;
use strict;

require Exporter;

our $FEATURE_BUILDPKG = "buildpkg";
our $FEATURE_SAVELOG = "savelog";
our $FEATURE_COLLISION_PROTECT = "collision-protect";

our @ISA = qw(Exporter);
our @EXPORT = qw(parse_features);
our @EXPORT_OK = qw($FEATURE_BUILDPKG $FEATURE_SAVELOG $FEATURE_COLLISION_PROTECT);

my @feature_list = ($mmfeatures::FEATURE_BUILDPKG, $mmfeatures::FEATURE_SAVELOG, $mmfeatures::FEATURE_COLLISION_PROTECT);

=over 4

=item C<parse_features>
X<parse_features>

Parse string to features hash.

=cut
sub parse_features($)
{
	my ($str) = @_;
	my $feature;
	my %features;
	my ($key, $val);

	$str =~ s/\s*(.*)\s*/$1/;
	$str =~ s/\s+/ /;
	foreach (split(/ /, $str))
	{
		if (m/^-(.*)$/)
		{
			$key = $1;
			$val = 0;
		}
		elsif (m/^\+(.*)$/)
		{
			$key = $1;
			$val = 1;
		}
		else
		{
			$key = $_;
			$val = 1;
		}
		foreach $feature (@feature_list)
		{
			if ($key eq $feature)
			{
				$features{$key} = $val;
			}
		}
	}
	return %features;
}

1;
