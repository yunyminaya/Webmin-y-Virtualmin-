#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-lib.pl';
&ReadParse();

my $config = ovm_module_config();
my $d = ovm_current_domain();
my $features = ovm_feature_matrix();
my $dom_args = $d ? '?dom='.&urlize($d->{'dom'}) : '';

&ui_print_header(undef, 'OpenVM Core', '', 'index');
print "<p>OpenVM Core expone utilidades abiertas para Virtualmin/Webmin sin depender de licencias comerciales oficiales.</p>\n";

if ($d) {
	print &ui_table_start('Virtual server context', 'width=100%', 2);
	print &ui_table_row('Domain', &html_escape($d->{'dom'}));
	print &ui_table_row('User', &html_escape($d->{'user'} || '-'));
	print &ui_table_row('Public HTML', &html_escape(ovm_public_html_dir($d) || 'Unavailable'));
	print &ui_table_row('Preview', &ui_link(ovm_preview_url($d, ''), ovm_preview_url($d, ''), undef, 'target=_blank'));
	print &ui_table_end();
	}
else {
	print defined(&ui_message)
		? &ui_message('No virtual server was auto-detected. Open feature pages with ?dom=example.com or ?id=123.')
		: "<p>No virtual server was auto-detected. Open feature pages with ?dom=example.com or ?id=123.</p>\n";
	}

print &ui_table_start('Feature matrix', 'width=100%', 2);
foreach my $feature (@$features) {
	my $status = $feature->{'enabled'} ? '<span style="color: green">ENABLED</span>' : '<span style="color: #999">DISABLED</span>';
	print &ui_table_row($feature->{'name'}, $status."<br>".&html_escape($feature->{'note'}));
	}
print &ui_table_end();

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row('edit_html.cgi'.$dom_args, 'Open HTML editor', 'Create and modify public web files using OpenVM Core.');
print &ui_buttons_row('connectivity.cgi'.$dom_args, 'Run connectivity checks', 'Validate DNS, website, mail and SSL exposure for the selected virtual server.');
print &ui_buttons_row('maillog.cgi'.$dom_args, 'Search mail logs', 'Inspect mail activity for the selected virtual server using an open log viewer.');
print &ui_buttons_row('list_bkeys.cgi', 'List backup keys', 'Review backup encryption keys using helpers from the GPL stack or local GPG fallback.');
print &ui_buttons_row('remotedns.cgi', 'Remote DNS inventory', 'Inspect remote DNS hosts and domains associated with them.');
print &ui_buttons_end();

&ui_print_footer('/', $text{'index_return'} || 'Return');
