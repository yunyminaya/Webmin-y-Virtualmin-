#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './virtual-server-lib.pl';
&ReadParse();
&can_edit_templates() || &error($text{'newreseller_ecannot'} || 'You are not allowed to edit the new reseller email template');

my $template_file = 'reseller-template';
my $body = -r $template_file ? &cat_file($template_file)
	: "Hello \${RESELLER_NAME},\n\nYour reseller account has been created successfully.\n\nLogin email: \${RESELLER_EMAIL}\n\nRegards,\nVirtualmin\n";

&ui_print_header(undef, $text{'newreseller_title'} || 'New Reseller Email', '', 'newreseller');
print &ui_hidden_start($text{'newuser_docs'} || 'Documentation', 'docs', 0);
print ($text{'newreseller_desc2'} || 'Edit the email template that can be sent to a new reseller account after it is created.'),"<p>\n";
&print_subs_table('RESELLER_NAME', 'RESELLER_DESC', 'RESELLER_EMAIL');
print &ui_hidden_end(),"<p>\n";

print &ui_form_start('save_newreseller.cgi', 'post');
print &ui_table_start($text{'newreseller_header'} || 'New reseller email message details', undef, 2);
print &ui_table_row($text{'newnotify_subject'} || 'Message subject',
	&ui_textbox('subject', $config{'newreseller_subject'} || ($text{'newreseller_title'} || 'New Reseller Email'), 60));
print &ui_table_row($text{'newnotify_from'} || 'From address',
	&ui_textbox('from', $config{'resel_from'} || &get_global_from_address(), 50));
print &ui_table_row($text{'newnotify_body'} || 'Message body',
	&ui_textarea('body', $body, 15, 70));
print &ui_table_end();
print &ui_form_end([ [ 'ok', $text{'save'} || 'Save' ] ]);

&ui_print_footer('', $text{'index_return'} || 'Return');
