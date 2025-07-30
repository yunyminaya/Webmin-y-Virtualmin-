#!/usr/local/bin/perl
# Configure and start up clamd

require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'sv_ecannot'});
&ui_print_unbuffered_header(undef, $text{'sv_title3'}, "");

print $text{'sv_enabling'},"<br>\n";
&$indent_print();
$ok = &enable_clamd();
&$outdent_print();
if ($ok) {
	print $text{'sv_enabledok'},"<p>\n";
	&webmin_log("enable", "clamd");
	}
else {
	print "<b>",$text{'sv_notenabled'},"</b><p>\n";
	}
&run_post_actions();

&ui_print_footer("edit_newsv.cgi", $text{'sv_return'});



