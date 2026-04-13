#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();

my $prefix = defined(&get_webprefix_safe) ? &get_webprefix_safe() : '';
print &redirect($prefix.'/stats.cgi');
exit;
