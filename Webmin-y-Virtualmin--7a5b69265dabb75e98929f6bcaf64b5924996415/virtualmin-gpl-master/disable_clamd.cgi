#!/usr/local/bin/perl
# Shut down clamd

require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'sv_ecannot'});
&ui_print_unbuffered_header(undef, $text{'sv_title2'}, "");

print $text{'sv_disabling'},"<br>\n";
&$indent_print();
$ok = &disable_clamd();
if ($ok) {
	($scanner) = &get_global_virus_scanner();
	if ($scanner eq "clamdscan") {
		&$first_print("<b>".$text{'sv_warning'}."</b>");
		}
	&webmin_log("disable", "clamd");
	}
&$outdent_print();

&run_post_actions();
&ui_print_footer("edit_newsv.cgi", $text{'sv_return'});



