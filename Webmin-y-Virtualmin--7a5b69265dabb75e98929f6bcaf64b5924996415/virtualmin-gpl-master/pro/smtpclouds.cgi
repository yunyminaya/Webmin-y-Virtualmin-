#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './virtual-server-lib.pl';

&ui_print_header(undef,
	$text{'smtpclouds_title'} || 'Cloud Mail Delivery Providers',
	'',
	'smtpclouds');

print "<p>Open inventory of cloud mail delivery providers available from the current runtime.</p>\n";

if (defined(&list_smtp_clouds)) {
	my @clouds = &list_smtp_clouds();
	if (@clouds) {
		print &ui_columns_start([
			$text{'mail_smtp_cloud'} || 'Provider',
			$text{'edit_desc'} || 'Description',
			$text{'setup_status'} || 'Status'
		]);
		foreach my $cloud (@clouds) {
			my $state = 'Available';
			my $sfunc = "smtpcloud_".$cloud->{'name'}."_get_state";
			if (defined(&$sfunc)) {
				my $st = eval { &$sfunc() };
				$state = defined($st) && $st ne '' ? $st : 'Available';
			}
			print &ui_columns_row([
				&html_escape($cloud->{'desc'} || $cloud->{'name'} || '-'),
				&html_escape($cloud->{'help'} || $cloud->{'name'} || '-'),
				&html_escape($state),
			]);
		}
		print &ui_columns_end();
	}
	else {
		print defined(&ui_message)
			? &ui_message('No cloud mail delivery providers are currently exposed by the active runtime')
			: "<p>No cloud mail delivery providers are currently exposed by the active runtime</p>\n";
	}
}
else {
	print defined(&ui_message)
		? &ui_message('Cloud mail delivery helpers are not available in the current GPL/OpenVM runtime')
		: "<p>Cloud mail delivery helpers are not available in the current GPL/OpenVM runtime</p>\n";
}

print "<p>Per-domain configuration remains available from ".
	&ui_link('edit_mail.cgi', $text{'edit_mailopts'} || 'Email settings').".</p>\n";

&ui_print_footer('edit_mail.cgi', $text{'index_return'} || 'Return');
