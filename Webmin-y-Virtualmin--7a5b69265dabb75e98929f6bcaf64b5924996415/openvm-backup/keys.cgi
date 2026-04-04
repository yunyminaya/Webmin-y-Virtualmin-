#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-backup-lib.pl';
&ReadParse();

ovmb_require_access();
my $keys = ovmb_backup_keys();

&ui_print_header(undef, 'OpenVM Backup Keys', '', 'keys');
print "<p>Open inventory of backup encryption keys using GPL helpers or local GPG fallback.</p>\n";

if (@$keys) {
	print &ui_columns_start([
		'Key ID',
		'Description',
		'Owner',
		'Created'
	]);
	foreach my $key (@$keys) {
		print &ui_columns_row([
			&html_escape($key->{'id'} || 'unknown'),
			&html_escape($key->{'desc'} || ''),
			&html_escape($key->{'owner'} || 'root'),
			$key->{'created'} ? &make_date($key->{'created'}) : '-'
		]);
	}
	print &ui_columns_end();
	}
else {
	print defined(&ui_message)
		? &ui_message('No backup encryption keys are currently available')
		: "<p>No backup encryption keys are currently available</p>\n";
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
