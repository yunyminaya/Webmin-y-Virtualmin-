#!/usr/bin/perl
use FindBin;
chdir($FindBin::Bin);
require './virtual-server-lib.pl';
&ReadParse();
&can_edit_templates() || &error($text{'remotedns_title'} || 'Remote DNS Servers');

&ui_print_header(undef, $text{'remotedns_title'} || 'Remote DNS Servers', '', 'remotedns');

if (!defined(&list_remote_dns)) {
	print &ui_message($text{'remotedns_desc'} || 'Remote DNS assignments detected from current domain configuration.');
	my @doms = grep { $_->{'dns_remote'} } &list_domains();
	if (@doms) {
		print &ui_columns_start([ 'Domain', 'Remote DNS host' ]);
		foreach my $d (@doms) {
			print &ui_columns_row([
				&html_escape($d->{'dom'}),
				&html_escape($d->{'dns_remote'})
			]);
		}
		print &ui_columns_end();
	}
	&ui_print_footer('', $text{'index_return'} || 'Return');
	exit;
}

my @remote = &list_remote_dns();
my @doms = &list_domains();
print &ui_columns_start([
	$text{'host'} || 'Host',
	$text{'type'} || 'Type',
	$text{'users'} || 'Domains using it'
]);
foreach my $r (@remote) {
	my @uses = grep { $_->{'dns_remote'} && $_->{'dns_remote'} eq $r->{'host'} } @doms;
	print &ui_columns_row([
		&html_escape($r->{'host'}),
		$r->{'slave'} ? 'Slave' : 'Master',
		scalar(@uses)
	]);
}
print &ui_columns_end();

&ui_print_footer('', $text{'index_return'} || 'Return');
