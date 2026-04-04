#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-lib.pl';
&ReadParse();
ovm_load_virtualmin();

if (defined(&can_edit_templates)) {
	&can_edit_templates() || &error($text{'remotedns_title'} || 'Remote DNS Servers');
	}
elsif (defined(&master_admin)) {
	&master_admin() || &error($text{'remotedns_title'} || 'Remote DNS Servers');
	}

my $inventory = ovm_remote_dns_inventory();

&ui_print_header(undef, $text{'remotedns_title'} || 'OpenVM Remote DNS Servers', '', 'remotedns');
print "<p>Open inventory of remote DNS servers and associated domains without relying on commercial licensing state.</p>\n";

if (@$inventory) {
	print &ui_columns_start([
		$text{'host'} || 'Host',
		$text{'type'} || 'Type',
		'Domains using it',
		'Count'
	]);
	foreach my $row (@$inventory) {
		my $domains = @{$row->{'domains'} || []}
			? join("<br>", map { &html_escape($_) } @{$row->{'domains'}})
			: '-';
		print &ui_columns_row([
			&html_escape($row->{'host'} || '-'),
			&html_escape($row->{'type'} || 'Remote'),
			$domains,
			$row->{'domain_count'} || 0,
		]);
	}
	print &ui_columns_end();
}
else {
	print defined(&ui_message)
		? &ui_message('No remote DNS assignments were detected')
		: "<p>No remote DNS assignments were detected</p>\n";
}

&ui_print_footer('index.cgi', $text{'index_return'} || 'Return');
