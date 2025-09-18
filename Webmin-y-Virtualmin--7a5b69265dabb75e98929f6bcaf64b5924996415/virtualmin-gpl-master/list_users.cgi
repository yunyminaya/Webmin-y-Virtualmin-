#!/usr/local/bin/perl
# list_users.cgi
# List mailbox users in some domain

$trust_unknown_referers = 1;
require './virtual-server-lib.pl';
&ReadParse();
$d = &get_domain($in{'dom'});
$d || &error($text{'edit_egone'});
&can_edit_domain($d) && &can_edit_users() || &error($text{'users_ecannot'});
@users = &list_domain_users($d, 0, 0, 0, 0, 1);
$utotal = scalar(@users);
if (!$d->{'parent'}) {
	# Sum up users from all sub-domains
	foreach my $sd (&get_domain_by("parent", $d->{'id'})) {
		local @susers = &list_domain_users($sd, 0, 1, 1, 1, 1);
		$utotal += scalar(@susers);
		}
	}
if ($utotal != scalar(@users)) {
	$msg = &text('users_indomsub', scalar(@users),
		     "<tt>".&show_domain_name($d)."</tt>", $utotal);
	}
else {
	$msg = &text('users_indom', scalar(@users),
		     "<tt>".&show_domain_name($d)."</tt>");
	}
&ui_print_header($msg, $text{'edit_users'}, "");

# Create select / add links
($mleft, $mreason, $mmax, $mhide) = &count_feature("mailboxes");
if ($mleft != 0) {
	push(@links, [ "edit_user.cgi?new=1&dom=$in{'dom'}",
		       $text{'users_add'} ]);
	# Only available for master admin
	if (&can_mailbox_ssh()) {
		push(@links, [ "edit_user.cgi?new=1&type=ssh&dom=$in{'dom'}",
					$text{'users_add_ssh'} ]);
		}
	my $webinit = &create_initial_user($d, undef, 1);
	if ($webinit->{'webowner'} && !$d->{'aliasmail'}) {
		push(@links, [ "edit_user.cgi?new=1&type=ftp&dom=$in{'dom'}",
				$text{'users_add_ftp'} ]);
		}
	if ($d->{'mail'}) {
		push(@links, [ "edit_user.cgi?new=1&type=mail&dom=$in{'dom'}",
			$text{'users_add_mail'} ]);
		}
	if (($d->{'mysql'} || $d->{'postgres'}) &&
	     ($virtualmin_pro || &should_show_pro_tip('extra_db_users', 1))) {
		push(@links, [ "edit_user.cgi?new=1&type=db&dom=$in{'dom'}",
			$text{'users_add_db'} ]);
		}
	if (&domain_has_website($d) && !$d->{'aliasmail'} &&
	    ($virtualmin_pro || &should_show_pro_tip('extra_web_users', 1))) {
		if (&indexof('virtualmin-htpasswd', @plugins) >= 0) {
			push(@links, [ "edit_user.cgi?new=1&type=web&dom=$in{'dom'}",
				$text{'users_add_web'} ]);
			}
		}
	}
push(@links, [ "mass_ucreate_form.cgi?dom=$in{'dom'}",
	       $text{'users_batch2'}, "right" ]);

# Show message about why cannot
if ($mleft != 0 && $mleft != -1 && !$mhide) {
	print "<b>",&text('users_canadd'.$mreason, $mleft),"</b><p>\n";
	}
elsif ($mleft == 0) {
	print "<b>",&text('users_noadd'.$mreason, $mmax),"</b><p>\n";
	}

# Generate the table
&users_table(\@users, $d, "change_users.cgi", 
	     [ [ "delete", $text{'users_delete'} ],
	       $virtualmin_pro ? ( [ "mass", $text{'users_mass'} ] ) : ( ) ],
	     \@links, $text{'users_none'});

print &ui_hr();
print &ui_buttons_start();

# Button to set user defaults
print &ui_buttons_row("edit_defaults.cgi",
      $text{'users_defaults'}, $text{'users_defaultsdesc'},
      &ui_hidden("dom", $in{'dom'}));

if ($d->{'mail'}) {
	# Button to email all users
	print &ui_buttons_row("edit_mailusers.cgi",
	      $text{'users_mail'}, $text{'users_maildesc'},
	      &ui_hidden("dom", $in{'dom'}));

	# Button to show mail client settings
	print &ui_buttons_row("mailclient.cgi",
	      $text{'users_mailclient'}, $text{'users_mailclientdesc'},
	      &ui_hidden("dom", $in{'dom'}));
	}

print &ui_buttons_end();

# Make sure the left menu is showing this domain
if (defined(&theme_select_domain)) {
	&theme_select_domain($d);
	}

if ($single_domain_mode) {
	&ui_print_footer(&domain_footer_link($d),
			 "", $text{'index_return2'});
	}
else {
	&ui_print_footer(&domain_footer_link($d),
		"", $text{'index_return'});
	}

