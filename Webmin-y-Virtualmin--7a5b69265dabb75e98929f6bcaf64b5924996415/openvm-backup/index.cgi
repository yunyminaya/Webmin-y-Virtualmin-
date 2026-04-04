#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-backup-lib.pl';
&ReadParse();

ovmb_require_access();
my $summary = ovmb_summary();
my $d = ovmb_current_domain();
my $dom_args = $d ? '?dom='.&urlize($d->{'dom'}) : '';

&ui_print_header(undef, 'OpenVM Backup Operations', '', 'index');
print "<p>Open backup operations over the GPL runtime with schedule inventory, key inventory and restore preparation.</p>\n";

if ($d) {
	print &ui_table_start('Current domain context', 'width=100%', 2);
	print &ui_table_row('Domain', &html_escape($d->{'dom'}));
	print &ui_table_row('User', &html_escape($d->{'user'} || '-'));
	print &ui_table_end();
	}

print &ui_table_start('Backup summary', 'width=100%', 2);
print &ui_table_row('Visible domains', $summary->{'domains'} || 0);
print &ui_table_row('Scheduled backups', $summary->{'schedules'} || 0);
print &ui_table_row('Backup keys', $summary->{'keys'} || 0);
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('schedules.cgi', 'Scheduled backups', 'Inspect backup schedules, destinations and purge policies.');
print &ui_buttons_row('keys.cgi', 'Backup keys', 'Inspect backup encryption keys through GPL helpers or local GPG fallback.');
print &ui_buttons_row('restore.cgi'.$dom_args, 'Restore preparation', 'Review domains, schedules and key inventory before a restore operation.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
