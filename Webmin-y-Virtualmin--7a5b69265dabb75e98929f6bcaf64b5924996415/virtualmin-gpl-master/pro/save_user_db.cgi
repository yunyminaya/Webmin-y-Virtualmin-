#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();
&error_setup($text{'user_err'} || 'Failed to save database user');

my $d = compat_current_domain();
$d || &error($text{'user_edoesntexist'} || 'No virtual server selected');
&can_edit_domain($d) || &error($text{'users_ecannot'} || 'You cannot edit this virtual server');
&can_edit_users() || &error($text{'users_ecannot'} || 'You cannot manage users for this virtual server');

&obtain_lock_unix($d);
&obtain_lock_mail($d);

my $new = $in{'new'} ? 1 : 0;
my $old = $new ? undef :
	(&get_extra_db_user($d, $in{'olduser'}) ||
	 &get_extra_db_user($d, compat_user_name($in{'olduser'}, $d)));
!$new && !$old && &error($text{'user_edoesntexist'} || 'The database user does not exist');

my $short = compat_trim($in{'dbuser'});
$short || &error($text{'user_eclash2'} || 'Missing database username');
my $full = compat_user_name($short, $d);

my $user = $new ? &create_initial_user($d) : { %{$old} };
$user->{'extra'} = 1;
$user->{'type'} = 'db';
$user->{'user'} = $full;
$user->{'olduser'} = $old->{'user'} if ($old);

my @dbs;
foreach my $db (split(/\r?\n/, $in{'dbs'} || '')) {
	next if (!$db);
	my ($type, $name) = split(/_/, $db, 2);
	next if (!$type || !$name);
	push(@dbs, { 'type' => $type, 'name' => $name });
	}
$user->{'dbs'} = \@dbs;

my $pass = compat_trim($in{'dbpass'});
if ($new) {
	$pass ne '' || &error('Database password is required');
	$user->{'pass'} = $pass;
	}
elsif (!$in{'dbpass_def'} && $pass ne '') {
	$user->{'pass'} = $pass;
	}

my $clash = &check_extra_user_clash($d, $user->{'user'}, 'db');
if ($clash && (!$old || $old->{'user'} ne $user->{'user'})) {
	&error($clash);
	}
if (my $lerr = &too_long($user->{'user'})) {
	&error($lerr);
	}

if ($new) {
	my $err = &create_databases_user($d, $user);
	&error($err) if ($err);
	&update_extra_user($d, $user);
	&webmin_log('create', 'extra-db-user', $user->{'user'}, $user) if (defined(&webmin_log));
	}
else {
	&modify_database_user($user, $old, $d);
	&update_extra_user($d, $user, $old);
	&webmin_log('modify', 'extra-db-user', $user->{'user'}, $user) if (defined(&webmin_log));
	}

&release_lock_unix($d);
&release_lock_mail($d);
print &redirect('../list_users.cgi?dom='.&urlize($d->{'id'}));
exit;
