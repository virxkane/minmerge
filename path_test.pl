#!/usr/bin/perl

# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

BEGIN {
	$XMERGE_PATH = "d:/msys_4_64/build/minmerge";
	$MSYS_PATH = "d:/msys_4_64";

	require "$XMERGE_PATH/lib/shellscript.pm";
	import shellscript;
	require "$XMERGE_PATH/lib/msyspathmap.pm";
	import msyspathmap;
}

# test posix2w32path()
print "Test posix2w32path():\n";

my $path = "/mingw";
my $conv_path = posix2w32path($path);
print "$path => $conv_path\n";

my $path = "/mingw/bin/mingw32-make.exe";
my $conv_path = posix2w32path($path);
print "$path => $conv_path\n";

my $path = "/mingw64";
my $conv_path = posix2w32path($path);
print "$path => $conv_path\n";

my $path = "/usr";
my $conv_path = posix2w32path($path);
print "$path => $conv_path\n";

my $path = "/usr/local/bin";
my $conv_path = posix2w32path($path);
print "$path => $conv_path\n";

my $path = "/d/Program Files/eclipse";
my $conv_path = posix2w32path($path);
print "$path => $conv_path\n";

# test w32path2posix()
print "\nTest w32path2posix():\n";

my $path = "c:";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "c:/";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "c:\\";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "d:/Program Files/eclipse";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "d:/mingw64";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "d:/mingw64/bin/libz.dll";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "d:/mingw";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "d:/msys_4_64";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

my $path = "d:/msys_4_64/build";
my $conv_path = w32path2posix($path);
print "$path => $conv_path\n";

