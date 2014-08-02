# Copyright 2010-2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

=head1 NAME

shellscript - Run shell script

=head1 SYNOPSIS

    require "<custom libs path>/shellscrip.pm";
	import shellscript;
	
    setshell("c:/msys/1.0/bin/sh.exe");
    @output = run_shellscript("any_script.sh");

    @output = run_shellcmd("id");
    @output = run_shellcmd("mount");


=head1 DESCRIPTION

These routines allow you to run various script or shell commands.
But this scripts/commands must be non interactive, i.e. output only!


=cut

package shellscript;

use 5.006;
use strict;

use IPC::Open2;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(setshell run_shellscript run_shellcmd);

my $shell = "sh";

sub setshell($)
{
	my ($sh) = @_;
	# TODO: check value in $sh
	$shell = $sh;
}

# Run shell script and return list of lines with script's output.
sub run_shellscript($)
{
	my ($script) = @_;
	my $ret;
	local *CHLD_OUT;
	local *CHLD_IN;
	my $pid;
	my @lines;
	# replace '\' to '/' in path
	$script =~ tr/\\/\//;
	
	$pid = IPC::Open2::open2(\*CHLD_OUT, \*CHLD_IN, $shell, "--login", "-c", "$script");
	#print CHLD_IN "Hello world!\n\n\n\n";
	while (<CHLD_OUT>)
	{
		chomp;
		push @lines, $_;
	}
	waitpid($pid, 0);
	$ret = $? >> 8;
	if ($ret != 0)
	{
		print "Fatal error: can't execute script/command: $script!\n";
		close(CHLD_OUT);
		close(CHLD_IN);
		return undef;
	}
	close(CHLD_OUT);
	close(CHLD_IN);
	return @lines;
}

sub run_shellcmd($)
{
	return run_shellscript($_[0]);
}

1;
