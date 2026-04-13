#!/usr/bin/perl

use FindBin;
chdir("$FindBin::Bin/..");
require './pro/openvm-compat-lib.pl';

&ReadParse();
&error_setup($text{'user_err'} || 'Failed to save web user');

my $d = compat_current_domain();
$d || &error($text{'user_edoesntexist'} || 'No virtual server selected');
&can_edit_domain($d) || &error($text{'users_ecannot'} || 'You cannot edit this virtual server');
&can_edit_users() || &error($text{'users_ecannot'} || 'You cannot manage users for this virtual server');

my $new = $in{'new'} ? 1 : 0;
my $old = $new ? undef :
	(&get_extra_web_user($d, $in{'olduser'}) ||
	 &get_extra_web_user($d, compat_user_name($in{'olduser'}, $d)));
!$new && !$old && &error($text{'user_edoesntexist'} || 'The web user does not exist');

my $short = compat_trim($in{'webuser'});
$short || &error($text{'user_eclash2'} || 'Missing web username');
my $full = compat_user_name($short, $d);

my $user = $new ? &create_initial_user($d, undef, 1) : { %{$old} };
$user->{'extra'} = 1;
$user->{'type'} = 'web';
$user->{'user'} = $full;
$user->{'olduser'} = $old->{'user'} if ($old);

my $pass = compat_trim($in{'webpass'});
if ($new) {
	$pass ne '' || &error($text{'user_epasswebnotset'} || 'Web password is required');
	$user->{'pass'} = $pass;
	}
elsif (!$in{'webpass_def'} && $pass ne '') {
	$user->{'pass'} = $pass;
	}

my $clash = &check_extra_user_clash($d, $user->{'user'}, 'web');
if ($clash && (!$old || $old->{'user'} ne $user->{'user'})) {
	&error($clash);
	}
if (my $lerr = &too_long($user->{'user'})) {
	&error($lerr);
	}

my $dirs = $in{'virtualmin_htpasswd'};
$dirs = join("\n", &list_webserver_user_dirs($d, $old)) if (!$dirs && $old);

&modify_webserver_user($user, $new ? undef : $old, $d,
	{ 'virtualmin_htpasswd' => $dirs || '' });
	
&webmin_log($new ? 'create' : 'modify', 'extra-web-user', $user->{'user'}, $user)
	if (defined(&webmin_log));
print &redirect('../list_users.cgi?dom='.&urlize($d->{'id'}));
exit;
