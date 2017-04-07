#######################################################################
#  Copyright 2017 Chernov A.A. <valexlin@gmail.com>                   #
#  This is a part of mingw-portage project:                           #
#  http://sourceforge.net/projects/mingwportage/                      #
#  Distributed under the terms of the GNU General Public License v3   #
#######################################################################

=head1 NAME

con_title - functions to manage console emulator's title.

=head1 SYNOPSIS

	require "<custom libs path>/con_title.pm";
	import con_title;

	con_settitle('some title');


=head1 DESCRIPTION

These routines allow you setting custom title in console emulator.


=cut

package con_title;

use 5.006;
use strict;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(con_settitle);

sub con_settitle($)
{
	my ($title) = @_;
	my $term = $ENV{'TERM'};
	if ($term =~ m/^xterm.*$/)
	{
		print "\x1b]0;${title}\x07";
	}
}

1;
