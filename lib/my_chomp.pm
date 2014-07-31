# Copyright 2014 Chernov A.A. <valexlin@gmail.com>
# This is a part of mingw-portage project: 
# http://sourceforge.net/projects/mingwportage/
# Distributed under the terms of the GNU General Public License v3

package my_chomp;

use 5.006;
use strict;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(my_chomp);

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
