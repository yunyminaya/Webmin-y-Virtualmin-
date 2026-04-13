#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();

my @doms = compat_selected_domains();
@doms || &error('No virtual servers selected');

if ($in{'confirm'}) {
	&ui_print_unbuffered_header(undef, 'Delete Virtual Servers', '', undef, undef, 1);
	foreach my $d (@doms) {
		if (!&can_delete_domain($d)) {
			print "<div>Skipped ".&html_escape($d->{'dom'})." : permission denied</div>\n";
			next;
			}
		&push_all_print();
		&set_all_null_print();
		my $err = &delete_virtual_server($d, 0, 0, $in{'preserve'});
		&pop_all_print();
		print "<div>".($err ? "Failed ".&html_escape($d->{'dom'})." : $err" : "Deleted ".&html_escape($d->{'dom'}))."</div>\n";
		}
	&ui_print_footer('/'.$module_name.'/', $text{'index_return'} || 'Return');
	exit;
	}

&ui_print_header(undef, 'Delete Virtual Servers', '', 'delete_domain');
print "<p>This GPL/OpenVM-compatible action will delete the selected virtual servers using the existing GPL runtime.</p>\n";
print &ui_form_start('mass_delete_domains.cgi', 'post');
foreach my $d (@doms) {
	print &ui_hidden('d', $d->{'id'}),"\n";
	}
print &ui_table_start('Selected virtual servers', 'width=100%', 2);
foreach my $d (@doms) {
	print &ui_table_row('Domain', &html_escape($d->{'dom'}));
	}
print &ui_table_end();
print &ui_form_end([ [ 'confirm', 'Delete selected' ] ]);
&ui_print_footer('/'.$module_name.'/', $text{'index_return'} || 'Return');
