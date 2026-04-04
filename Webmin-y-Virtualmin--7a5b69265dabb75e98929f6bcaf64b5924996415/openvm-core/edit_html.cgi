#!/usr/bin/perl

use FindBin;
chdir($FindBin::Bin);
require './openvm-lib.pl';
&ReadParse();

my $d = ovm_require_domain_access(ovm_current_domain(), 'You cannot use the OpenVM HTML editor for this virtual server');
my $public_html = ovm_public_html_dir($d);
$public_html || &error('Public HTML directory could not be determined for this virtual server');

my $rel = ovm_safe_relative_path($in{'file'});
my $full = "$public_html/$rel";

if ($in{'save'}) {
	ovm_write_text_file($full, $in{'html'});
	&webmin_log('openvm_edit_html', $full, $d->{'dom'}) if (defined(&webmin_log));
	print &redirect('edit_html.cgi?dom='.&urlize($d->{'dom'}).'&file='.&urlize($rel).'&saved=1');
	exit;
	}

my $html = -r $full ? ovm_read_text_file($full) : ovm_default_html($d, $rel);
my $baseurl = ovm_preview_url($d, '');

&ui_print_header(undef, 'OpenVM HTML Editor', '', 'edit_html');
print "<p>Create and edit website files using an open implementation that relies on the GPL runtime and does not modify official licensing logic.</p>\n";
print &ui_message('Changes saved successfully') if ($in{'saved'} && defined(&ui_message));

print &ui_form_start('edit_html.cgi', 'post');
print &ui_hidden('dom', $d->{'dom'}),"\n";
print &ui_table_start('Website file editor', undef, 2);
print &ui_table_row('Domain', &html_escape($d->{'dom'}));
print &ui_table_row('Public HTML', &html_escape($public_html));
print &ui_table_row('Relative file', &ui_textbox('file', $rel, 60));
my $editor = defined(&virtualmin_ui_show_html_editor)
	? &virtualmin_ui_show_html_editor('html', $html, $baseurl)
	: &ui_textarea('html', $html, 25, 100);
print &ui_table_row('HTML', $editor);
print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} || 'Save' ] ]);

print '<p>', &ui_link(ovm_preview_url($d, $rel), $text{'view'} || 'Preview', undef, 'target=_blank'), '</p>', "\n";
&ui_print_footer('index.cgi?dom='.&urlize($d->{'dom'}), $text{'index_return'} || 'Return');
