#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-lib.pl';
&ReadParse();
ovm_load_virtualmin();

if (defined(&can_backup_keys)) {
	&can_backup_keys() ||
		&error($text{'backup_ekeycannot'} || 'You cannot manage backup encryption keys');
	}
elsif (defined(&master_admin)) {
	&master_admin() ||
		&error($text{'backup_ekeycannot'} || 'Only the master administrator can view backup encryption keys');
	}

my $keys = ovm_backup_keys();

&ui_print_header(undef, 'OpenVM Backup Encryption Keys', '', 'bkeys');
print "<p>Open inventory of backup encryption keys using GPL helpers when available and local GPG fallback otherwise.</p>\n";

print &ui_columns_start([
	$text{'backup_key'} || 'Key ID',
	$text{'desc'} || 'Description',
	$text{'owner'} || 'Owner',
	$text{'created'} || 'Created'
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

if (!@$keys) {
	print defined(&ui_message)
		? &ui_message('No backup encryption keys are currently available')
		: "<p>No backup encryption keys are currently available</p>\n";
}

print "<p><tt>virtualmin list-backup-keys --multiline</tt></p>\n";
&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
