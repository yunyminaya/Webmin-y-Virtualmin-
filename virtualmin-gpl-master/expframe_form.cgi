#!/usr/local/bin/perl
# expframe_form.cgi
# Display frame-forwarding HTML

require './virtual-server-lib.pl';
&ReadParse();
$d = &get_domain($in{'dom'});
&can_edit_domain($d) && &can_edit_forward() || &error($text{'edit_ecannot'});
&ui_print_header(&domain_in($d), $text{'expframe_title'}, "");

$ff = &framefwd_file($d);
print &text('expframe_desc', "<tt>$ff</tt>"),"<p>\n";

print &ui_form_start("save_expframe.cgi", "form-data");
print &ui_hidden("dom", $in{'dom'}),"\n";
print &ui_table_start(undef, undef, 2);
print &ui_table_row(undef,
	&ui_textarea("text",
		&read_file_contents_as_domain_user($d, $ff), 20, 80,
		undef, 0, "style='width:100%"), 2);
print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer(&domain_footer_link($d),
	"", $text{'index_return'});

