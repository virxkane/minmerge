#######################################################################
#  Copyright 2015 Chernov A.A. <valexlin@gmail.com>                   #
#  This is a part of mingw-portage project:                           #
#  http://sourceforge.net/projects/mingwportage/                      #
#  Distributed under the terms of the GNU General Public License v3   #
#######################################################################

=head1 NAME

infodir - functions to regenerate infodir index file.

=head1 SYNOPSIS

	require "<custom libs path>/infodir.pm";
	import infodir;

	%features = regenerate_infodir($prefix . "/share/info/");


=head1 DESCRIPTION

These routines allow you to regenerate infodir index file.


=cut

package infodir;

use 5.006;
use strict;
use POSIX;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(regenerate_infodir);

=over 4

=item C<regenerate_infodir>
X<regenerate_infodir>

Regenerate infodir index file.
arguments:
0: path to shell binary;
1: path where placed info-files (msys path).

=cut
sub regenerate_infodir($$)
{
	my ($shell, $path) = @_;
	my $dirfile = "${path}/dir";

	my $dh;
	my $entry;
	my $fname;
	my @_st;
	my @flist;
	my $ret;
	my $res = 0;

	opendir($dh, $path) || die "Can't open directory $path!";
	while ($entry = readdir($dh))
	{
		next if ($entry eq '..' || $entry eq '.');
		$fname = $path . '/' . $entry;
		@_st = stat($fname);
		if (@_st)
		{
			push(@flist, $fname) if ($entry =~ m/^.*\.info$/ && S_ISREG($_st[2]));
		}
	}
	closedir($dh);
	print "Found " . scalar(@flist) . " info files.\n";

	$ret = 1;
	$ret = unlink($dirfile) if (-f $dirfile);
	if (!$ret)
	{
		print "Can't delete $dirfile!\n";
		return 0;
	}
	foreach $fname (@flist)
	{
		# call <install-info> with args...
		$ret = system($shell,  "--login", "-c", "install-info --dir-file=$dirfile \"$fname\"");
		if ($ret == 0)
		{
			$res++;
		}
		else
		{
			print "Failed to install info $fname!\n";
		}
	}
	return $res;
}

1;
