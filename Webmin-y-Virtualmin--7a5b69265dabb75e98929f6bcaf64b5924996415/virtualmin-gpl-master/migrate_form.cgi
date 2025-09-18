#!/usr/local/bin/perl
# Show a form for importing a backup from some other control panel

require './virtual-server-lib.pl';
&require_migration();
$can = &can_migrate_servers();
$can || &error($text{'migrate_ecannot'});
if ($can == 3) {
	$parent = &get_domain_by_user($base_remote_user);
	$parent && &can_edit_domain($parent) || &error($text{'edit_ecannot'});
	}

&ui_print_header(undef, $text{'migrate_title'}, "");

print "$text{'migrate_desc'}<p>\n";

print &ui_form_start("migrate.cgi", "form-data");
print &ui_table_start($text{'migrate_header'}, "width=100%", 2, [ "width=30%"]);

# Source file
print &ui_table_row($text{'migrate_file'},
	&show_backup_destination("src", undef, $can > 1, undef, 1, 0));

# Source type (plesk, cpanel, etc..)
print &ui_table_row($text{'migrate_type'},
		    &ui_select("type", undef,
			[ map { [ $_, $text{'migrate_'.$_} ] }
			      @migration_types ]));

if ($can < 3) {
	# Username, if needed
	print &ui_table_row($text{'migrate_user'},
		    &ui_opt_textbox("user", undef, 20, $text{'migrate_auto2'},
				    undef, 0, undef, 0, "autocomplete=off"));

	# Password, if needed
	print &ui_table_row($text{'migrate_pass'},
		    &ui_opt_textbox("pass", undef, 20, $text{'migrate_auto2'},
				    undef, 0, undef, 0,
				    "autocomplete=new-password", 'password'));

	# Create Webmin user?
	print &ui_table_row($text{'migrate_webmin'},
		    &ui_yesno_radio("webmin", 1));
	}

# Template to use
foreach $t (&list_available_templates($parent)) {
	push(@tmpls, $t);
	}
print &ui_table_row($text{'migrate_template'},
		    &ui_select("template", &get_init_template(0), 
			[ map { [ $_->{'id'}, $_->{'name'} ] } @tmpls ]));

# Plan to use
@availplans = sort { $a->{'name'} cmp $b->{'name'} } &list_available_plans();
$defplan = &get_default_plan();
print &ui_table_row($text{'migrate_plan'},
	&ui_select("plan", $defplan ? $defplan->{'id'} : undef,
		   [ map { [ $_->{'id'}, $_->{'name'} ] } @availplans ]));

# IP to assign
print &ui_table_row($text{'migrate_ip'}, &virtual_ip_input(\@tmpls));

# IPv6 address to assign
if (&supports_ip6()) {
	print &ui_table_row($text{'migrate_ip6'},
		&virtual_ip6_input(\@tmpls, undef, 0, $config{'ip6enabled'} ? 0 : -2));
	}

# Parent user
@doms = sort { $a->{'user'} cmp $b->{'user'} }
	     grep { $_->{'unix'} && &can_config_domain($_) } &list_visible_domains();
if (@doms && $can < 3) {
	print &ui_table_row($text{'migrate_parent'},
			    &ui_radio("parent_def", 1,
				      [ [ 1, $text{'migrate_parent1'} ],
					[ 0, $text{'migrate_parent0'} ] ])."\n".
			    &ui_select("parent", undef,
				       [ map { [ $_->{'user'} ] } @doms ]));
	}
else {
	print &ui_hidden("parent_def", 1);
	}

# Domain prefix
print &ui_table_row($text{'migrate_prefix'},
		   &ui_opt_textbox("prefix", undef, 20, $text{'migrate_auto'}));

# Contact email
print &ui_table_row($text{'migrate_email'},
	    &ui_opt_textbox("email", undef, 40, $text{'form_email_def'}));

print &ui_table_end();
print &ui_form_end([ [ "migrate", $text{'migrate_show'} ] ]);

&ui_print_footer("", $text{'index_return'});

