#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_MAIL_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmm_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmm_module_config
{
my %config = (
	'feature_filters'   => 1,
	'feature_cleanup'   => 1,
	'feature_quotas'    => 1,
	'cleanup_days_old'  => 90,
	'cleanup_trash_days'=> 14,
	'quota_warning_pct' => 85,
	);
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || die "Cannot read $config_file: $!";
	while (my $line = <$fh>) {
		chomp $line;
		next if $line =~ /^\s*#/ || $line !~ /=/;
		my ($k, $v) = split(/=/, $line, 2);
		next unless defined $k && $k ne '';
		$config{$k} = $v;
		}
	close($fh);
	}
return \%config;
}

sub ovmm_load_virtualmin
{
return 1 if $OPENVM_MAIL_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_MAIL_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmm_require_access
{
ovmm_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_edit_spam) && &can_edit_spam();
return 1 if defined(&can_edit_mail) && &can_edit_mail();
&error(ovmm_text('mail_ecannot', 'You cannot manage mail from OpenVM Mail'));
}

sub ovmm_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovmm_load_virtualmin();
my $id  = defined($hint->{'id'})   ? $hint->{'id'}   : $in{'id'};
my $dom = defined($hint->{'dom'})  ? $hint->{'dom'}   : $in{'dom'};
my $usr = defined($hint->{'user'}) ? $hint->{'user'}  : $base_remote_user;
my $d;
$d  = &get_domain($id)               if defined($id)  && $id ne '';
$d ||= &get_domain_by('dom', $dom)   if defined($dom) && $dom ne '';
$d ||= &get_domain_by('user', $usr)  if defined($usr) && $usr ne '';
return $d;
}

sub ovmm_visible_domains
{
ovmm_load_virtualmin();
my @doms = defined(&list_visible_domains) ? &list_visible_domains()
	 : defined(&list_domains)         ? &list_domains()
	 : ();
return [ grep { $_->{'mail'} } @doms ];
}

# ---------------------------------------------------------------------------
# Mail filters — wraps GPL procmail/sieve helpers
# ---------------------------------------------------------------------------

sub ovmm_list_filters
{
my ($d) = @_;
return [] unless $d && $d->{'mail'};
ovmm_load_virtualmin();

if (defined(&list_domain_filters)) {
	my @filters = &list_domain_filters($d);
	return \@filters;
	}

# Fallback: read .procmailrc
my $home    = $d->{'home'} || '';
my $procmailrc = "$home/.procmailrc";
return [] unless -r $procmailrc;

my @filters;
open(my $fh, '<', $procmailrc) or return [];
my %current;
while (my $line = <$fh>) {
	chomp $line;
	if ($line =~ /^:0/) {
		push @filters, {%current} if %current;
		%current = ('type' => 'procmail', 'cond' => '', 'action' => '');
		}
	elsif ($line =~ /^\*\s*(.+)/) {
		$current{'cond'} .= ($current{'cond'} ? ', ' : '') . $1;
		}
	elsif ($line =~ /^([^#\s].+)$/ && exists $current{'action'}) {
		$current{'action'} = $1 unless $current{'action'};
		}
	}
push @filters, {%current} if %current && $current{'action'};
close($fh);
return \@filters;
}

# ---------------------------------------------------------------------------
# Mailbox quota inventory
# ---------------------------------------------------------------------------

sub ovmm_mailbox_quotas
{
my ($d) = @_;
return [] unless $d && $d->{'mail'};
ovmm_load_virtualmin();

if (defined(&list_domain_users)) {
	my @users = &list_domain_users($d);
	my @result;
	foreach my $u (@users) {
		next unless defined $u->{'email'};
		my $used  = $u->{'mailsize'}  // 0;
		my $quota = $u->{'mailquota'} // 0;
		my $pct   = ($quota && $quota > 0) ? int($used * 100 / $quota) : 0;
		push @result, {
			'user'    => $u->{'user'} || $u->{'name'} || '-',
			'email'   => $u->{'email'},
			'used_kb' => int($used / 1024),
			'quota_kb'=> int($quota / 1024),
			'pct'     => $pct,
			'warning' => ($quota > 0 && $pct >= (ovmm_module_config()->{'quota_warning_pct'} || 85)) ? 1 : 0,
			};
		}
	return \@result;
	}

return [];
}

# ---------------------------------------------------------------------------
# Mailbox cleanup policy — describe what would be cleaned
# ---------------------------------------------------------------------------

sub ovmm_cleanup_policy
{
my $cfg = ovmm_module_config();
return {
	'old_messages_days'  => $cfg->{'cleanup_days_old'}   || 90,
	'trash_days'         => $cfg->{'cleanup_trash_days'} || 14,
	'quota_warning_pct'  => $cfg->{'quota_warning_pct'}  || 85,
	'description'        => "Mensajes mayores a ".$cfg->{'cleanup_days_old'}." días en Trash y Spam se eliminan periódicamente. "
	                      . "Trash vacío al pasar ".$cfg->{'cleanup_trash_days'}." días.",
	};
}

# ---------------------------------------------------------------------------
# Domain mail summary
# ---------------------------------------------------------------------------

sub ovmm_domain_summary
{
my ($d) = @_;
return {} unless $d;
ovmm_load_virtualmin();
my $filters = ovmm_list_filters($d);
my $quotas  = ovmm_mailbox_quotas($d);
my $policy  = ovmm_cleanup_policy();
my @warnings = grep { $_->{'warning'} } @$quotas;
return {
	'filters'  => scalar @$filters,
	'mailboxes'=> scalar @$quotas,
	'warnings' => scalar @warnings,
	'policy'   => $policy,
	};
}

# ===========================================================================
# NEW FUNCTIONS — Enhanced mail management
# ===========================================================================

# ---------------------------------------------------------------------------
# Mailbox management
# ---------------------------------------------------------------------------

sub ovmm_list_mailboxes
{
my ($domain) = @_;
return [] unless defined $domain && $domain ne '';
ovmm_load_virtualmin();

my $d = ref($domain) ? $domain : &get_domain_by('dom', $domain);
return [] unless $d && $d->{'mail'};

if (defined(&list_domain_users)) {
	my @users = &list_domain_users($d);
	my @result;
	foreach my $u (@users) {
		push @result, {
			'user'     => $u->{'user'} || $u->{'name'} || '-',
			'email'    => $u->{'email'} || '',
			'realname' => $u->{'real'} || $u->{'fullname'} || '',
			'quota'    => $u->{'mailquota'} || 0,
			'used'     => $u->{'mailsize'}  || 0,
			'home'     => $u->{'home'} || '',
			};
		}
	return \@result;
	}

# Fallback: read from system
my @result;
my $maildir = "/var/mail";
if (-d "$maildir/$domain") {
	opendir(my $dh, "$maildir/$domain") || return [];
	while (my $f = readdir($dh)) {
		next if $f =~ /^\./;
		push @result, {
			'user'     => $f,
			'email'    => "$f\@$domain",
			'realname' => '',
			'quota'    => 0,
			'used'     => 0,
			'home'     => "$maildir/$domain/$f",
			};
		}
	closedir($dh);
	}
return \@result;
}

sub ovmm_create_mailbox
{
my ($domain, $user, $password, $quota) = @_;
return 0 unless defined $domain && $domain ne '';
return 0 unless defined $user && $user ne '';
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return 0 unless $d;

if (defined(&create_user)) {
	my %uinfo = (
		'name'     => $user,
		'pass'     => $password,
		'quota'    => $quota || 0,
		'email'    => "$user\@$domain",
		);
	&create_user($d, \%uinfo);
	return 1;
	}

# Fallback: system command
my $cmd = "useradd -m -s /usr/sbin/nologin '$user' 2>/dev/null";
system($cmd);
if ($password) {
	system("echo '$user:$password' | chpasswd 2>/dev/null");
	}
return 1;
}

sub ovmm_delete_mailbox
{
my ($domain, $user) = @_;
return 0 unless defined $domain && defined $user;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return 0 unless $d;

if (defined(&delete_user)) {
	my @users = &list_domain_users($d);
	foreach my $u (@users) {
		if (($u->{'user'} || $u->{'name'} || '') eq $user) {
			&delete_user($d, $u);
			return 1;
			}
		}
	return 0;
	}

# Fallback
system("userdel -r '$user' 2>/dev/null");
return 1;
}

sub ovmm_change_password
{
my ($domain, $user, $new_pass) = @_;
return 0 unless defined $domain && defined $user && defined $new_pass;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
if ($d && defined(&modify_user)) {
	my @users = &list_domain_users($d);
	foreach my $u (@users) {
		if (($u->{'user'} || $u->{'name'} || '') eq $user) {
			$u->{'pass'} = $new_pass;
			&modify_user($d, $u);
			return 1;
			}
		}
	return 0;
	}

# Fallback
system("echo '$user:$new_pass' | chpasswd 2>/dev/null");
return 1;
}

sub ovmm_set_quota
{
my ($domain, $user, $quota) = @_;
return 0 unless defined $domain && defined $user;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
if ($d && defined(&modify_user)) {
	my @users = &list_domain_users($d);
	foreach my $u (@users) {
		if (($u->{'user'} || $u->{'name'} || '') eq $user) {
			$u->{'mailquota'} = $quota;
			&modify_user($d, $u);
			return 1;
			}
		}
	return 0;
	}

# Fallback: setquota
if ($quota && $quota > 0) {
	system("setquota -u '$user' 0 $quota 0 0 -a 2>/dev/null");
	}
return 1;
}

sub ovmm_get_quota_usage
{
my ($domain, $user) = @_;
return { 'used' => 0, 'quota' => 0, 'pct' => 0 } unless defined $domain && defined $user;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
if ($d && defined(&list_domain_users)) {
	my @users = &list_domain_users($d);
	foreach my $u (@users) {
		if (($u->{'user'} || $u->{'name'} || '') eq $user) {
			my $used  = $u->{'mailsize'}  || 0;
			my $quota = $u->{'mailquota'} || 0;
			my $pct   = ($quota > 0) ? int($used * 100 / $quota) : 0;
			return { 'used' => $used, 'quota' => $quota, 'pct' => $pct };
			}
		}
	}

return { 'used' => 0, 'quota' => 0, 'pct' => 0 };
}

# ---------------------------------------------------------------------------
# Alias management
# ---------------------------------------------------------------------------

sub ovmm_list_aliases
{
my ($domain) = @_;
return [] unless defined $domain && $domain ne '';
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return [] unless $d;

if (defined(&list_domain_aliases)) {
	my @aliases = &list_domain_aliases($d);
	return \@aliases;
	}

# Fallback: read /etc/postfix/virtual or aliases
my @result;
my $home = $d->{'home'} || '';
if (-r "$home/.aliases") {
	open(my $fh, '<', "$home/.aliases") || return [];
	while (my $line = <$fh>) {
		chomp $line;
		next if $line =~ /^\s*#/ || $line !~ /=/;
		my ($from, $to) = split(/\s*=\s*/, $line, 2);
		next unless $from && $to;
		push @result, {
			'from' => $from,
			'to'   => $to,
			'type' => 'alias',
			};
		}
	close($fh);
	}
return \@result;
}

sub ovmm_create_alias
{
my ($domain, $from, $to) = @_;
return 0 unless defined $domain && defined $from && defined $to;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return 0 unless $d;

if (defined(&create_alias)) {
	&create_alias($d, $from, $to);
	return 1;
	}

# Fallback: append to aliases file
my $home = $d->{'home'} || '';
if ($home && -d $home) {
	open(my $fh, '>>', "$home/.aliases") || return 0;
	print $fh "$from = $to\n";
	close($fh);
	}
return 1;
}

sub ovmm_delete_alias
{
my ($domain, $from) = @_;
return 0 unless defined $domain && defined $from;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return 0 unless $d;

if (defined(&delete_alias)) {
	&delete_alias($d, $from);
	return 1;
	}

# Fallback
my $home = $d->{'home'} || '';
if (-r "$home/.aliases") {
	my @kept;
	open(my $fh, '<', "$home/.aliases") || return 0;
	while (my $line = <$fh>) {
		chomp $line;
		if ($line =~ /^(\S+)\s*=/) {
			next if $1 eq $from;
			}
		push @kept, $line;
		}
	close($fh);
	open(my $wh, '>', "$home/.aliases") || return 0;
	print $wh join("\n", @kept) . "\n";
	close($wh);
	}
return 1;
}

# ---------------------------------------------------------------------------
# Forwarder management
# ---------------------------------------------------------------------------

sub ovmm_list_forwarders
{
my ($domain) = @_;
return [] unless defined $domain && $domain ne '';
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return [] unless $d;

if (defined(&list_domain_forwarders)) {
	my @fwds = &list_domain_forwarders($d);
	return \@fwds;
	}

# Fallback: read .forward files from mailboxes
my @result;
my $mailboxes = ovmm_list_mailboxes($domain);
foreach my $mb (@$mailboxes) {
	my $home = $mb->{'home'} || '';
	if (-r "$home/.forward") {
		open(my $fh, '<', "$home/.forward") || next;
		while (my $line = <$fh>) {
			chomp $line;
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			next unless $line;
			push @result, {
				'from' => $mb->{'email'},
				'to'   => $line,
				'type' => 'forwarder',
				};
			}
		close($fh);
		}
	}
return \@result;
}

sub ovmm_create_forwarder
{
my ($domain, $from, $to) = @_;
return 0 unless defined $domain && defined $from && defined $to;
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
if ($d && defined(&create_forward)) {
	&create_forward($d, $from, $to);
	return 1;
	}

# Fallback: write .forward
my $mailboxes = ovmm_list_mailboxes($domain);
foreach my $mb (@$mailboxes) {
	if ($mb->{'email'} eq $from || $mb->{'user'} eq $from) {
		my $home = $mb->{'home'} || '';
		if ($home && -d $home) {
			open(my $fh, '>', "$home/.forward") || return 0;
			print $fh "$to\n";
			close($fh);
			return 1;
			}
		}
	}
return 0;
}

sub ovmm_delete_forwarder
{
my ($domain, $from) = @_;
return 0 unless defined $domain && defined $from;

my $mailboxes = ovmm_list_mailboxes($domain);
foreach my $mb (@$mailboxes) {
	if ($mb->{'email'} eq $from || $mb->{'user'} eq $from) {
		my $home = $mb->{'home'} || '';
		if ($home && -f "$home/.forward") {
			unlink("$home/.forward");
			return 1;
			}
		}
	}
return 0;
}

# ---------------------------------------------------------------------------
# Mail statistics
# ---------------------------------------------------------------------------

sub ovmm_get_mail_stats
{
my ($domain) = @_;
my %stats = (
	'total_mailboxes' => 0,
	'total_aliases'   => 0,
	'total_forwarders'=> 0,
	'queue_count'     => 0,
	'spam_score'      => 0,
	);

if (defined $domain && $domain ne '') {
	my $mailboxes  = ovmm_list_mailboxes($domain);
	$stats{'total_mailboxes'} = scalar @$mailboxes;

	my $aliases    = ovmm_list_aliases($domain);
	$stats{'total_aliases'} = scalar @$aliases;

	my $forwarders = ovmm_list_forwarders($domain);
	$stats{'total_forwarders'} = scalar @$forwarders;
	}

# Queue count
my $queue = ovmm_get_mail_queue();
$stats{'queue_count'} = scalar @$queue;

# Spam score from SpamAssassin
$stats{'spam_score'} = ovmm_check_spamassassin();

return \%stats;
}

# ---------------------------------------------------------------------------
# Mail queue
# ---------------------------------------------------------------------------

sub ovmm_get_mail_queue
{
my @queue;
my $output = `mailq 2>/dev/null`;
return [] unless defined $output && $output ne '';

my @lines = split /\n/, $output;
my $current_id;
foreach my $line (@lines) {
	if ($line =~ /^([A-F0-9]+)\s+/) {
		$current_id = $1;
		my $rest = $';
		if ($rest =~ /(\d+)\s+(\w+)\s+(\w+)\s+\((.+?)\)/) {
			push @queue, {
				'id'      => $current_id,
				'size'    => $1,
				'date'    => $2,
				'sender'  => $3,
				'status'  => $4,
				'recipients' => '',
				};
			}
		elsif ($rest =~ /(\S+)/) {
			push @queue, {
				'id'      => $current_id,
				'size'    => 0,
				'date'    => '',
				'sender'  => $1,
				'status'  => 'queued',
				'recipients' => '',
				};
			}
		}
	elsif ($current_id && $line =~ /^\s+\((.+?)\)/) {
		# Recipient line
		}
	}
return \@queue;
}

sub ovmm_flush_queue
{
my $output = `postfix flush 2>/dev/null || sendmail -q 2>/dev/null`;
return defined $output ? 1 : 0;
}

sub ovmm_delete_from_queue
{
my ($id) = @_;
return 0 unless defined $id && $id ne '';
my $output = `postsuper -d '$id' 2>/dev/null`;
return defined $output ? 1 : 0;
}

# ---------------------------------------------------------------------------
# Autoresponders
# ---------------------------------------------------------------------------

sub ovmm_get_autoresponders
{
my ($domain) = @_;
return [] unless defined $domain && $domain ne '';
my @result;

my $mailboxes = ovmm_list_mailboxes($domain);
foreach my $mb (@$mailboxes) {
	my $home = $mb->{'home'} || '';
	if (-r "$home/.autorespond") {
		open(my $fh, '<', "$home/.autorespond") || next;
		my $content = do { local $/; <$fh> };
		close($fh);
		my ($subject) = $content =~ /^Subject:\s*(.+?)$/m;
		my ($body)    = $content =~ /\n\n(.+)$/s;
		push @result, {
			'user'    => $mb->{'user'},
			'email'   => $mb->{'email'},
			'subject' => $subject || 'Auto Reply',
			'body'    => $body    || '',
			'enabled' => 1,
			};
		}
	elsif (-r "$home/vacation.msg") {
		open(my $fh, '<', "$home/vacation.msg") || next;
		my $content = do { local $/; <$fh> };
		close($fh);
		my ($subject) = $content =~ /^Subject:\s*(.+?)$/m;
		my ($body)    = $content =~ /\n\n(.+)$/s;
		push @result, {
			'user'    => $mb->{'user'},
			'email'   => $mb->{'email'},
			'subject' => $subject || 'Vacation',
			'body'    => $body    || '',
			'enabled' => 1,
			};
		}
	}
return \@result;
}

sub ovmm_set_autoresponder
{
my ($domain, $user, $subject, $body) = @_;
return 0 unless defined $domain && defined $user;
$subject ||= 'Auto Reply';
$body    ||= '';

my $mailboxes = ovmm_list_mailboxes($domain);
foreach my $mb (@$mailboxes) {
	if ($mb->{'user'} eq $user) {
		my $home = $mb->{'home'} || '';
		if ($home && -d $home) {
			open(my $fh, '>', "$home/.autorespond") || return 0;
			print $fh "Subject: $subject\n\n$body\n";
			close($fh);
			return 1;
			}
		}
	}
return 0;
}

sub ovmm_remove_autoresponder
{
my ($domain, $user) = @_;
return 0 unless defined $domain && defined $user;

my $mailboxes = ovmm_list_mailboxes($domain);
foreach my $mb (@$mailboxes) {
	if ($mb->{'user'} eq $user) {
		my $home = $mb->{'home'} || '';
		unlink("$home/.autorespond") if $home;
		unlink("$home/vacation.msg") if $home;
		return 1;
		}
	}
return 0;
}

# ---------------------------------------------------------------------------
# Mail log
# ---------------------------------------------------------------------------

sub ovmm_get_maillog
{
my ($lines) = @_;
$lines ||= 100;
my @entries;

# Try journalctl first, then /var/log/mail.log
my $log_output;
if (-x '/bin/journalctl') {
	$log_output = `journalctl -u postfix -u dovecot --no-pager -n $lines 2>/dev/null`;
	}
if (!$log_output && -r '/var/log/mail.log') {
	$log_output = `tail -n $lines /var/log/mail.log 2>/dev/null`;
	}
if (!$log_output && -r '/var/log/maillog') {
	$log_output = `tail -n $lines /var/log/maillog 2>/dev/null`;
	}

return [] unless defined $log_output && $log_output ne '';

my @log_lines = split /\n/, $log_output;
foreach my $line (reverse @log_lines) {
	next unless defined $line && $line ne '';
	my $type = 'info';
	$type = 'error'   if $line =~ /error|fail|bounce/i;
	$type = 'warning' if $line =~ /warning|deferred/i;
	$type = 'spam'    if $line =~ /spam|SPAM/i;
	$type = 'sent'    if $line =~ /sent|delivered/i;

	my ($date, $from, $to, $status);
	if ($line =~ /^(\w+\s+\d+\s+[\d:]+)\s+/) {
		$date = $1;
		}
	if ($line =~ /from[=<](.+?)[>,]/) {
		$from = $1;
		}
	if ($line =~ /to[=<](.+?)[>,]/) {
		$to = $1;
		}
	if ($line =~ /status=(\w+)/) {
		$status = $1;
		}

	push @entries, {
		'line'   => $line,
		'date'   => $date   || '',
		'from'   => $from   || '',
		'to'     => $to     || '',
		'status' => $status || '',
		'type'   => $type,
		};
	}
return \@entries;
}

# ---------------------------------------------------------------------------
# SpamAssassin check
# ---------------------------------------------------------------------------

sub ovmm_check_spamassassin
{
my $score = 0;
if (-x '/usr/bin/spamassassin') {
	$score = 1;
	}
if (-d '/etc/spamassassin') {
	$score = 2;
	}
if (-r '/etc/default/spamassassin') {
	open(my $fh, '<', '/etc/default/spamassassin') || return $score;
	while (my $line = <$fh>) {
		if ($line =~ /ENABLED\s*=\s*1/) {
			$score = 3;
			last;
			}
		}
	close($fh);
	}
if (-x '/usr/sbin/spamd') {
	$score = 4;
	}
return $score;
}

# ---------------------------------------------------------------------------
# Domain mail config
# ---------------------------------------------------------------------------

sub ovmm_get_domain_mail_config
{
my ($domain) = @_;
return {} unless defined $domain && $domain ne '';
ovmm_load_virtualmin();

my $d = &get_domain_by('dom', $domain);
return {} unless $d;

my %config = (
	'domain'       => $domain,
	'mail_enabled' => $d->{'mail'} || 0,
	'mail_server'  => 'postfix',
	'imap_server'  => 'dovecot',
	'spam'         => $d->{'spam'} || 0,
	'virus'        => $d->{'virus'} || 0,
	);

if ($d->{'home'} && -d $d->{'home'}) {
	$config{'home'} = $d->{'home'};
	}

return \%config;
}

1;
