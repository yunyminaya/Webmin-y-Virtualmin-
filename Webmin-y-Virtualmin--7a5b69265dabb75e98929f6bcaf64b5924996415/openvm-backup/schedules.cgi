#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-backup-lib.pl';
&ReadParse();

ovmb_require_access();
my $rows = ovmb_scheduled_backups();

&ui_print_header(undef, 'OpenVM Scheduled Backups', '', 'schedules');
print "<p>Open inventory of scheduled backups, destinations and purge policies.</p>\n";

if (@$rows) {
	print &ui_columns_start([
		'ID',
		'Description',
		'Owner',
		'Targets',
		'Destinations',
		'Purge',
		'Status'
	]);
	foreach my $row (@$rows) {
		my $dests = @{$row->{'dests'} || []} ? join('<br>', map { &html_escape($_) } @{$row->{'dests'}}) : '-';
		my $purges = @{$row->{'purges'} || []} ? join(', ', map { defined($_) && $_ ne '' ? $_ : 'none' } @{$row->{'purges'}}) : 'none';
		print &ui_columns_row([
			$row->{'id'},
			&html_escape($row->{'desc'} || ''),
			&html_escape($row->{'owner'} || '-'),
			&html_escape($row->{'targets'} || '-'),
			$dests,
			&html_escape($purges),
			$row->{'enabled'} ? 'Enabled' : 'Disabled'
		]);
	}
	print &ui_columns_end();
	}
else {
	print defined(&ui_message)
		? &ui_message('No scheduled backups were found')
		: "<p>No scheduled backups were found</p>\n";
	}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
