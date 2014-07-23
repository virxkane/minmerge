#!/usr/bin/perl

# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

use 5.006;

if (scalar(@ARGV) < 2)
{
	print "Too less arguments!\n";
	exit 1;
}

my $bldscript;
my $cmds;
my @commands;
my $cmd;

$bldscript = shift;
while ($cmd = shift)
{
	$cmds .= ' ' . $cmd;
}

# trim
$cmds =~ s/^\s*(.*)\s*$/$1/;
# simplify whitespaces
$cmds =~ s/\s+/ /g;
@commands = split(/ /, $cmds);

print "script: $bldscript\n";
print "commands: @commands\n";
