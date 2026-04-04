#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-admin-lib.pl';
&ReadParse();

my $d = ovma_require_domain_access(ovma_current_domain(), 'You cannot inspect extra admins for this virtual server');
my $admins = ovma_list_domain_admins($d);

&ui_print_header(undef, 'OpenVM Extra Admins', '', 'admins');
print "<p>Open inventory of extra administrators for the selected virtual server.</p>\n";

if (@$admins) {
	print &ui_columns_start([
		'Login',
		'Description',
		'Assigned domains'
	]);
	foreach my $admin (sort { $a->{'name'} cmp $b->{'name'} } @$admins) {
		print &ui_columns_row([
			&html_escape($admin->{'name'} || '-'),
			&html_escape($admin->{'desc'} || ''),
			&html_escape(ovma_render_domains_desc($admin))
		]);
	}
	print &ui_columns_end();
	}
else {
	print defined(&ui_message)
		? &ui_message('No extra administrators were found for this virtual server')
		: "<p>No extra administrators were found for this virtual server</p>\n";
	}

ovma_log_action('view', 'openvm-admin', "Viewed extra admins for $d->{'dom'}");
&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
