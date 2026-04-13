#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();

my @doms = compat_selected_domains();
@doms || &error('No virtual servers selected');

my $prefix = defined(&get_webprefix_safe) ? &get_webprefix_safe() : '';

&ui_print_header(undef, 'Batch Virtual Server Actions', '', 'cmass');
print "<p>Open batch dashboard for selected virtual servers using GPL and OpenVM-compatible actions.</p>\n";

print &ui_form_start('mass_disable.cgi', 'post');
foreach my $d (@doms) {
	print &ui_hidden('d', $d->{'id'}),"\n";
	}
print &ui_form_end([ [ 'go', 'Disable selected' ] ]);

print &ui_form_start('mass_enable.cgi', 'post');
foreach my $d (@doms) {
	print &ui_hidden('d', $d->{'id'}),"\n";
	}
print &ui_form_end([ [ 'go', 'Enable selected' ] ]);

print &ui_form_start('mass_delete_domains.cgi', 'post');
foreach my $d (@doms) {
	print &ui_hidden('d', $d->{'id'}),"\n";
	}
print &ui_form_end([ [ 'go', 'Delete selected' ] ]);

print &ui_table_start('Selected virtual servers', 'width=100%', 2);
foreach my $d (@doms) {
	my $actions = join(' | ',
		&ui_link('../edit_domain.cgi?dom='.&urlize($d->{'id'}), 'Edit'),
		&ui_link('../cert_form.cgi?dom='.&urlize($d->{'id'}), 'SSL'),
		&ui_link('../list_users.cgi?dom='.&urlize($d->{'id'}), 'Users'),
		&ui_link('../edit_limits.cgi?dom='.&urlize($d->{'id'}), 'Limits'),
		&ui_link('edit_res.cgi?dom='.&urlize($d->{'id'}), 'Resource limits'),
		&ui_link($prefix.'/openvm-core/index.cgi?dom='.&urlize($d->{'dom'}), 'OpenVM Core'));
	print &ui_table_row(
		&html_escape($d->{'dom'}),
		$actions);
	}
print &ui_table_end();

&ui_print_footer('/'.$module_name.'/', $text{'index_return'} || 'Return');
