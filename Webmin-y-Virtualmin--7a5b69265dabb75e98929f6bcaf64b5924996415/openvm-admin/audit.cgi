#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-admin-lib.pl';
&ReadParse();

ovma_require_module_access();
my $limit = $in{'limit'} =~ /^\d+$/ ? $in{'limit'} : ovma_module_config()->{'default_audit_limit'} || 100;
$limit = 1000 if ($limit > 1000);
$limit = 1 if ($limit < 1);
my $logs = ovma_audit_logs($limit);

&ui_print_header(undef, 'OpenVM Audit Log', '', 'audit');
print "<p>Operational audit log for delegated administration and module access.</p>\n";

print &ui_form_start('audit.cgi', 'get');
print &ui_table_start('Audit query', undef, 2);
print &ui_table_row('Max results', &ui_textbox('limit', $limit, 8));
print &ui_table_end();
print &ui_form_end([ [ 'refresh', 'Refresh' ] ]);

if (@$logs) {
	print &ui_columns_start([
		'Timestamp',
		'User',
		'Action',
		'Module',
		'Details'
	]);
	foreach my $log (@$logs) {
		print &ui_columns_row([
			scalar(localtime($log->{'timestamp'} || time())),
			&html_escape($log->{'user'} || '-'),
			&html_escape($log->{'action'} || '-'),
			&html_escape($log->{'module'} || '-'),
			&html_escape($log->{'details'} || '')
		]);
	}
	print &ui_columns_end();
	}
else {
	print defined(&ui_message)
		? &ui_message('No audit events are available')
		: "<p>No audit events are available</p>\n";
	}

ovma_log_action('view', 'openvm-admin', 'Viewed audit log');
&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
