#!/usr/local/bin/perl
# Save the defaults for new users in this virtual server

require './virtual-server-lib.pl';
&ReadParse();
&licence_status();
$d = &get_domain($in{'dom'});
&error_setup($text{'defaults_err'});
&can_edit_domain($d) || &error($text{'users_ecannot'});
&can_edit_users() || &error($text{'users_ecannot'});
$user = &create_initial_user($d, 1);

# Save disk quotas
if (&has_home_quotas()) {
	if ($in{'quota_def'} == 1) {
		$user->{'quota'} = 0;
		}
	elsif ($in{'quota_def'} == 2) {
		$user->{'quota'} = "none";
		}
	else {
		$in{'quota'} =~ /^[0-9\.]+$/ ||
			&error($text{'defaults_equota'});
		$user->{'quota'} = &quota_parse("quota", "home");
		}
	}
if (&has_mail_quotas()) {
	if ($in{'mquota_def'} == 1) {
		$user->{'mquota'} = 0;
		}
	elsif ($in{'mquota_def'} == 2) {
		$user->{'mquota'} = "none";
		}
	else {
		$in{'mquota'} =~ /^[0-9\.]+$/ ||
			&error($text{'defaults_emquota'});
		$user->{'mquota'} = &quota_parse("mquota", "mail");
		}
	}

# Save default shell
if (&can_mailbox_ftp()) {
	&check_available_shell($in{'shell'}, 'mailbox', $user->{'shell'}) ||
		&error($text{'user_eshell'});
	$user->{'shell'} = $in{'shell'};
	}

# Save mail forwarding
if ($in{'aliases_def'}) {
	delete($user->{'to'});
	}
else {
	@values = &parse_alias(undef, "NEWUSER", [ ], "user", $d);
	$user->{'to'} = \@values;
	}

# Save databases
foreach $db (split(/\r?\n/, $in{'dbs'})) {
	local ($type, $name) = split(/_/, $db, 2);
	push(@dbs, { 'type' => $type, 'name' => $name });
	}
$user->{'dbs'} = \@dbs;

# Save secondary groups
%cangroups = map { $_, 1 } (&allowed_secondary_groups($d),
			    @{$user->{'secs'}});
@secs = split(/\0/, $in{'groups'});
foreach my $g (@secs) {
	$cangroups{$g} || &error(&text('user_egroup', $g));
	}
$user->{'secs'} = [ @secs ];

# Primary address is not done yet
delete($user->{'email'});

# Save plugin defaults
foreach $f (&list_mail_plugins()) {
	&plugin_call($f, "mailbox_defaults_parse", $user, $d, \%in);
	}

&save_initial_user($user, $d);
&run_post_actions_silently();
&webmin_log("initial", "domain", $d->{'dom'});
&redirect("list_users.cgi?dom=$in{'dom'}");
