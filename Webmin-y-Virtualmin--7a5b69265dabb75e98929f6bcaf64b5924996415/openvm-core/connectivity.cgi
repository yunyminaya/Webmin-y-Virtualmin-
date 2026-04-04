#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-lib.pl';
&ReadParse();

my $d = ovm_require_domain_access(ovm_current_domain(), 'You cannot validate this virtual server with OpenVM Core');
my $checks = ovm_connectivity_checks($d);

&ui_print_header(undef, 'OpenVM Connectivity Checks', '', 'connectivity');
print "<p>Open diagnostics for DNS, website, mail and SSL reachability without any dependency on commercial licensing state.</p>\n";

print &ui_table_start('Connectivity checks', undef, 2);
foreach my $check (@$checks) {
	my $status = $check->{'ok'}
		? '<span style="color: green">OK</span>'
		: '<span style="color: red">FAIL</span>';
	print &ui_table_row($check->{'name'}, $status."<br>".&html_escape($check->{'message'} || ''));
	}
print &ui_table_end();

&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
