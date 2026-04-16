#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './virtual-server-lib.pl';

my $prefix = &get_webprefix_safe();
&redirect($prefix.'/openvm-admin/resellers.cgi');
