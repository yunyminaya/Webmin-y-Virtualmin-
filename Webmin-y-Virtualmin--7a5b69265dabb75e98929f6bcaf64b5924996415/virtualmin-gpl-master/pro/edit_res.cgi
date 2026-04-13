#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();

my $d = compat_current_domain();
$d || &error($text{'edit_res'} || 'No virtual server selected');
&can_edit_domain($d) || &error($text{'edit_resdesc'} || 'You cannot edit resource limits for this virtual server');
&can_edit_res($d) || &error($text{'edit_resdesc'} || 'Resource limits are not editable for this virtual server');
defined(&supports_resource_limits) && &supports_resource_limits() ||
	&error($text{'res_elinux'} || 'Resource limits are not supported on this system');
defined(&get_domain_resource_limits) && defined(&save_domain_resource_limits) ||
	&error($text{'res_err'} || 'Resource limits helper functions are not available');

if ($in{'save'}) {
	my $limits = compat_text_to_limits($in{'limits_kv'});
	eval { &save_domain_resource_limits($d, $limits, 1); };
	&error($@ || ($text{'res_err'} || 'Failed to save resource limits')) if ($@);
	print &redirect('edit_res.cgi?dom='.&urlize($d->{'id'}).'&saved=1');
	exit;
	}

my $limits = &get_domain_resource_limits($d);
$limits = {} if (ref($limits) ne 'HASH');

&ui_print_header(&domain_in($d), $text{'edit_res'} || 'Edit Resource Limits', '', 'edit_res');
print &ui_message($text{'setup_done'} || 'Resource limits saved successfully') if ($in{'saved'} && defined(&ui_message));
print "<p>OpenVM compatibility editor for resource limits using the GPL runtime. Enter one <tt>key=value</tt> pair per line.</p>\n";
print '<p>', &ui_link('../edit_limits.cgi?dom='.&urlize($d->{'id'}), $text{'edit_limits'} || 'Access control limits'), '</p>', "\n";

print &ui_form_start('edit_res.cgi', 'post');
print &ui_hidden('dom', $d->{'id'}),"\n";
print &ui_table_start($text{'edit_resdesc'} || 'Resource limits', undef, 2);
print &ui_table_row($text{'edit_res'} || 'Limits',
	&ui_textarea('limits_kv', compat_limits_to_text($limits), 18, 90));
print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} || 'Save' ] ]);

&ui_print_footer('../index.cgi?dom='.&urlize($d->{'id'}), $text{'index_return'} || 'Return');
