#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-backup-lib.pl';
&ReadParse();

ovmb_require_access();
my $inventory = ovmb_restore_inventory();
my $d = ovmb_current_domain();

&ui_print_header(undef, 'OpenVM Restore Preparation', '', 'restore');
print "<p>Open restore preparation workflow showing eligible domains, available keys and schedules before invoking runtime restore operations.</p>\n";

if ($d) {
	print &ui_table_start('Selected domain', 'width=100%', 2);
	print &ui_table_row('Domain', &html_escape($d->{'dom'}));
	print &ui_table_row('User', &html_escape($d->{'user'} || '-'));
	print &ui_table_end();
	print &ui_hr();
	}

print &ui_table_start('Restore checklist', 'width=100%', 2);
print &ui_table_row('Domains visible', $inventory->{'total_domains'} || 0);
print &ui_table_row('Scheduled backups available', scalar(@{$inventory->{'schedules'} || []}));
print &ui_table_row('Backup keys available', scalar(@{$inventory->{'keys'} || []}));
print &ui_table_end();

print &ui_hr();
print &ui_table_start('Visible domains for restore', 'width=100%', 2);
if (@{$inventory->{'domains'} || []}) {
	foreach my $dom (@{$inventory->{'domains'}}) {
		print &ui_table_row(
			&html_escape($dom->{'dom'} || $dom->{'id'}),
			&html_escape($dom->{'user'} || '-')
		);
	}
	}
else {
	print &ui_table_row('Domains', 'No visible domains were detected');
	}
print &ui_table_end();

print "<p>Use this inventory to validate scope, key availability and scheduling before executing production restore operations through the GPL runtime.</p>\n";
&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
