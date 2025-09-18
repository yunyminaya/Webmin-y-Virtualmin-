#!/usr/local/bin/perl
# Attempt to install email ratelimiting package

require './virtual-server-lib.pl';
&can_edit_templates() || &error($text{'ratelimit_ecannot'});

&ui_print_header(undef, $text{'ratelimit_title4'}, "");

$cfile = &get_ratelimit_config_file();
$before = -e $cfile;

print &text('ratelimit_installing'),"<br>\n";
&$indent_print();
$ok = &install_ratelimit_package();
&$outdent_print();
print $ok ? $text{'ratelimit_installed'}
	  : $text{'ratelimit_installfailed'},"<p>\n";

# If config didn't exist before, remove any list and racl lines
# to disable default greylisting
if (!$before && $ok) {
	print &text('ratelimit_clearing'),"<br>\n";
	&lock_file(&get_ratelimit_config_file());
	$conf = &get_ratelimit_config();
	@copy = @$conf;		# Make a copy because deleting changes $conf
	foreach my $c (@copy) {
		if ($c->{'name'} eq 'list' ||
		    $c->{'name'} eq 'racl' && $c->{'values'}->[1] ne 'default'||
		    $c->{'name'} eq 'acl' && $c->{'values'}->[1] ne 'default') {
			&save_ratelimit_directive($conf, $c, undef);
			}
		}
	($nospf) = grep { $_->{'name'} eq 'nospf' } @$conf;
	if (!$nospf) {
		&save_ratelimit_directive($conf, undef,
			{ 'name' => 'nospf',
			  'values' => [] });
		}
	($noauth) = grep { $_->{'name'} eq 'noauth' } @$conf;
	if (!$noauth) {
		&save_ratelimit_directive($conf, undef,
			{ 'name' => 'noauth',
			  'values' => [] });
		}
	&flush_file_lines();
	&unlock_file(&get_ratelimit_config_file());
	&$second_print($text{'setup_done'});
	}

&webmin_log("install", "ratelimit");
&ui_print_footer("ratelimit.cgi", $text{'ratelimit_return'});
