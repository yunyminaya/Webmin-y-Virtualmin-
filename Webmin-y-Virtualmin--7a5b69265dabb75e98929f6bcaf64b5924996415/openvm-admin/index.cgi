#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-admin-lib.pl';
&ReadParse();

ovma_require_module_access();
my $summary = ovma_summary();
my $d = $summary->{'domain'};
my $dom_args = $d ? '?dom='.&urlize($d->{'dom'}) : '';

&ui_print_header(undef, 'OpenVM Administration', '', 'index');
print "<p>Open administration layer for delegated access, extra admins, reseller inventory and operational audit.</p>\n";

if ($d) {
	print &ui_table_start('Domain context', 'width=100%', 2);
	print &ui_table_row('Domain', &html_escape($d->{'dom'}));
	print &ui_table_row('User', &html_escape($d->{'user'} || '-'));
	print &ui_table_row('Extra admins detected', $summary->{'admins'} || 0);
	print &ui_table_end();
	}

print &ui_table_start('Administration summary', 'width=100%', 2);
print &ui_table_row('Webmin users', $summary->{'users'} || 0);
print &ui_table_row('Resellers', $summary->{'resellers'} || 0);
print &ui_table_row('Recent audit events', $summary->{'audits'} || 0);
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('admins.cgi'.$dom_args, 'Extra admins', 'Inspect extra administrators linked to the selected virtual server.');
print &ui_buttons_row('resellers.cgi', 'Reseller inventory', 'Inspect reseller accounts exposed by the current GPL runtime.');
print &ui_buttons_row('audit.cgi', 'Audit log', 'Review recent administrative actions and delegated access changes.');
print &ui_buttons_end();

ovma_log_action('view', 'openvm-admin', 'Viewed administration dashboard');
&ui_print_footer('/', $text{'index_return'} || 'Return');
