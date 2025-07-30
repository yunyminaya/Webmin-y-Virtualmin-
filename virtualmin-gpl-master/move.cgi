#!/usr/local/bin/perl
# Actually move a virtual server under a new owner

require './virtual-server-lib.pl';
&ReadParse();
&error_setup($text{'move_err'});
$d = &get_domain($in{'dom'});
&can_move_domain($d) || &error($text{'move_ecannot'});
$oldd = { %$d };

if ($in{'parent'}) {
	# Get the selected parent domain object
	$parent = &get_domain($in{'parent'});
	if ($d->{'parent'}) {
		$parent->{'id'} == $d->{'parent'} && &error($text{'move_esame'});
		}
	else {
		$parent->{'id'} == $d->{'id'} && &error($text{'move_eparent'});
		}
	&can_config_domain($parent) || &error($text{'move_ecannot2'});

	# Check if parent has MySQL feature enabled too
	&error($text{'setup_edepmysql'})
        if ($d->{'mysql'} && !$parent->{'mysql'});
	# Check if parent has PostgreSQL feature enabled too
	&error($text{'setup_edepmysqlsub'})
        if ($d->{'postgres'} && !$parent->{'postgres'});
	}
else {
	# Turning into a parent domain - check the username for clashes
	$in{'newuser'} =~ /^[^\t :]+$/ || &error($text{'setup_euser2'});
	$newd = { %$d };
	$newd->{'unix'} = 1;
	$newd->{'webmin'} = 1;
	$newd->{'user'} = $in{'newuser'};
	$newd->{'group'} = $in{'newuser'};
	$derr = &virtual_server_clashes($newd, undef, 'user') ||
		&virtual_server_clashes($newd, undef, 'group');
	&error($derr) if ($derr);

	# Check if the domain already has a user with that name
	@dusers = &list_domain_users($d, 0, 1, 1, 1);
	($clash) = grep { $_->{'user'} eq $in{'newuser'} ||
		  &remove_userdom($_->{'user'}, $d) eq $in{'newuser'} } @dusers;
	$clash && &error(&text('move_euserclash', $in{'newuser'}));

	# Check if a user with that name exists anywhere
	defined(getpwnam($in{'newuser'})) &&
		&error(&text('move_euserclash2', $in{'newuser'}));
	}

&ui_print_unbuffered_header(&domain_in($d), $text{'move_title'}, "");
if ($parent) {
	&$first_print(&text('move_doing', "<tt>$d->{'dom'}</tt>",
			  "<tt>$parent->{'dom'}</tt>"));
	}
else {
	&$first_print(&text('move_doing2', "<tt>$d->{'dom'}</tt>"));
	}
&$indent_print();
# Do the move
if ($in{'parent'}) {
	$ok = &move_virtual_server($d, $parent);
	}
else {
	$ok = &reparent_virtual_server($d, $in{'newuser'}, $in{'newpass'});
	}
&$outdent_print();
if ($ok) {
	&$second_print($text{'setup_done'});
	}
else {
	&$second_print($text{'move_failed'});
	}

&run_post_actions();
&webmin_log("move", "domain", $d->{'dom'}, $d);

# Call any theme post command
if (defined(&theme_post_save_domain)) {
        &theme_post_save_domain($d, 'modify');
        }

&ui_print_footer(&domain_footer_link($d),
        "", $text{'index_return'});


