#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './virtual-server-lib.pl';
&ReadParse();

sub current_domain
{
my $d;
$d = &get_domain($in{'id'}) if ($in{'id'});
$d ||= &get_domain_by('dom', $in{'dom'}) if ($in{'dom'});
$d ||= &get_domain_by('user', $base_remote_user);
return $d;
}

my $d = &current_domain();
$d || &error($text{'edit_html'} || 'No virtual server selected');
&can_edit_domain($d) || &error($text{'edit_html'} || 'You cannot edit this virtual server');
my $can_html = defined(&can_edit_html) ? &can_edit_html() : &can_edit_domain($d);
$can_html || &error($text{'edit_html'} || 'You are not allowed to use the web page editor');

my $phd = &public_html_dir($d);
my $rel = $in{'file'} || 'index.html';
$rel =~ s/^\///;
$rel =~ s/\.\.//g;
$rel =~ s/[^A-Za-z0-9_\.\-\/]//g;
$rel ||= 'index.html';
my $full = "$phd/$rel";

if ($in{'save'}) {
	my $dir = $full;
	$dir =~ s/\/[^\/]+$//;
	mkdir($dir, 0755) if ($dir && !-d $dir);
	&uncat_file($full, $in{'html'});
	&webmin_log('edit_html', $full, $d->{'dom'});
	print &redirect("edit_html.cgi?dom=".&urlize($d->{'dom'})."&file=".&urlize($rel)."&saved=1");
	exit;
}

my $html = -r $full ? &cat_file($full) : "<html>\n<head><title>$d->{'dom'}</title></head>\n<body>\n<h1>$d->{'dom'}</h1>\n<p>Edit this page.</p>\n</body>\n</html>\n";
my $baseurl = ($d->{'ssl'} ? 'https' : 'http')."://$d->{'dom'}/";

&ui_print_header(undef, $text{'edit_html'} || 'Edit web pages', '', 'edit_html');
print ($text{'edit_htmldesc'} || 'Create and edit HTML web pages for this virtual server.'),"<p>\n";
print &ui_message('Changes saved successfully') if ($in{'saved'});

print &ui_form_start('edit_html.cgi', 'post');
print &ui_hidden('dom', $d->{'dom'}),"\n";
print &ui_table_start($text{'edit_html'} || 'Edit web pages', undef, 2);
print &ui_table_row($text{'saveas_path'} || 'Relative file',
	&ui_textbox('file', $rel, 50));
my $editor = defined(&virtualmin_ui_show_html_editor)
	? &virtualmin_ui_show_html_editor('html', $html, $baseurl)
	: &ui_textarea('html', $html, 25, 80);
print &ui_table_row($text{'edit_html'} || 'HTML',
	$editor);
print &ui_table_end();
print &ui_form_end([ [ 'save', $text{'save'} || 'Save' ] ]);

print "<p>", &ui_link($baseurl.$rel, $text{'view'} || 'Preview', undef, 'target=_blank'), "</p>\n";
&ui_print_footer('', $text{'index_return'} || 'Return');
