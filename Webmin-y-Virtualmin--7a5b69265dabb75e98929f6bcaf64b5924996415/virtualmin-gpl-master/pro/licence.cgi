#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();

my $prefix = defined(&get_webprefix_safe) ? &get_webprefix_safe() : '';

&ui_print_header(undef, 'OpenVM / GPL Runtime', '', 'openvm_suite');
print "<p>This installation exposes GPL and OpenVM-compatible functionality already present in the repository.</p>\n";
print "<p>OpenVM modules do not require a commercial Virtualmin Pro license. Official commercial features continue to depend on an official license if you choose to use them separately.</p>\n";
print '<p>', &ui_link($prefix.'/openvm-suite/index.cgi', 'Open OpenVM Suite'), '</p>', "\n";
&ui_print_footer('/'.$module_name.'/', $text{'index_return'} || 'Return');
