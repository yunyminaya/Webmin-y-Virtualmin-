#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $module_name, $base_remote_user);
our $OVMNT_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# JSON helpers — lightweight, no external deps
# ---------------------------------------------------------------------------

sub ovmnt_json_escape
{
my ($str) = @_;
return '' unless defined $str;
$str =~ s/\\/\\\\/g;
$str =~ s/"/\\"/g;
$str =~ s/\n/\\n/g;
$str =~ s/\r/\\r/g;
$str =~ s/\t/\\t/g;
$str =~ s/([^\x20-\x7e])/sprintf("\\u%04x",ord($1))/ge;
return $str;
}

sub ovmnt_to_json
{
my ($data) = @_;
return 'null' unless defined $data;
my $ref = ref($data);
if ($ref eq 'HASH') {
	my @pairs;
	foreach my $k (sort keys %$data) {
		push @pairs, '"'.ovmnt_json_escape($k).'":'.ovmnt_to_json($data->{$k});
		}
	return '{'.join(',', @pairs).'}';
	}
elsif ($ref eq 'ARRAY') {
	my @items;
	foreach my $v (@$data) {
		push @items, ovmnt_to_json($v);
		}
	return '['.join(',', @items).']';
	}
elsif ($ref eq 'JSON::PP::Boolean' || $ref eq 'boolean') {
	return $data ? 'true' : 'false';
	}
elsif (!defined $data) {
	return 'null';
	}
elsif ($data =~ /^-?\d+(?:\.\d+)?$/ && $data !~ /^0\d/) {
	return $data;
	}
else {
	return '"'.ovmnt_json_escape($data).'"';
	}
}

sub ovmnt_from_json
{
my ($json) = @_;
return undef unless defined $json && $json ne '';
$json =~ s/^\s+//;
$json =~ s/\s+$//;

if ($json eq 'null') {
	return undef;
	}
elsif ($json eq 'true') {
	return 1;
	}
elsif ($json eq 'false') {
	return 0;
	}
elsif ($json =~ /^"(.*)"$/s) {
	my $s = $1;
	$s =~ s/\\"/"/g;
	$s =~ s/\\\\/\\/g;
	$s =~ s/\\n/\n/g;
	$s =~ s/\\r/\r/g;
	$s =~ s/\\t/\t/g;
	$s =~ s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
	return $s;
	}
elsif ($json =~ /^-?\d+(?:\.\d+)?$/) {
	return 0 + $json;
	}
elsif ($json =~ /^\[/) {
	$json =~ s/^\[//;
	$json =~ s/\]$//;
	my @items;
	my $depth = 0;
	my $current = '';
	my $in_string = 0;
	my $escape = 0;
	for my $ch (split //, $json) {
		if ($escape) {
			$current .= $ch;
			$escape = 0;
			next;
			}
		if ($ch eq '\\') {
			$current .= $ch;
			$escape = 1;
			next;
			}
		if ($ch eq '"') {
			$in_string = !$in_string;
			$current .= $ch;
			next;
			}
		if (!$in_string) {
			if ($ch eq '[' || $ch eq '{') {
				$depth++;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ']' || $ch eq '}') {
				$depth--;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ',' && $depth == 0) {
				$current =~ s/^\s+//;
				$current =~ s/\s+$//;
				push @items, ovmnt_from_json($current) if $current ne '';
				$current = '';
				next;
				}
			}
		$current .= $ch;
		}
	$current =~ s/^\s+//;
	$current =~ s/\s+$//;
	push @items, ovmnt_from_json($current) if $current ne '';
	return \@items;
	}
elsif ($json =~ /^\{/) {
	$json =~ s/^\{//;
	$json =~ s/\}$//;
	my %hash;
	my $depth = 0;
	my $current = '';
	my $in_string = 0;
	my $escape = 0;
	my @parts;
	for my $ch (split //, $json) {
		if ($escape) {
			$current .= $ch;
			$escape = 0;
			next;
			}
		if ($ch eq '\\') {
			$current .= $ch;
			$escape = 1;
			next;
			}
		if ($ch eq '"') {
			$in_string = !$in_string;
			$current .= $ch;
			next;
			}
		if (!$in_string) {
			if ($ch eq '[' || $ch eq '{') {
				$depth++;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ']' || $ch eq '}') {
				$depth--;
				$current .= $ch;
				next;
				}
			elsif ($ch eq ',' && $depth == 0) {
				$current =~ s/^\s+//;
				$current =~ s/\s+$//;
				push @parts, $current if $current ne '';
				$current = '';
				next;
				}
			}
		$current .= $ch;
		}
	$current =~ s/^\s+//;
	$current =~ s/\s+$//;
	push @parts, $current if $current ne '';
	foreach my $pair (@parts) {
		if ($pair =~ /^"([^"]*)"\s*:\s*(.*)$/s) {
			my $k = $1;
			my $v = $2;
			$hash{$k} = ovmnt_from_json($v);
			}
		elsif ($pair =~ /^(\w+)\s*:\s*(.*)$/s) {
			$hash{$1} = ovmnt_from_json($2);
			}
		}
	return \%hash;
	}
return $json;
}

# ---------------------------------------------------------------------------
# Config helpers
# ---------------------------------------------------------------------------

sub ovmnt_module_config
{
my %config = (
	'notify_email'      => 'admin@localhost',
	'notify_slack'      => 'no',
	'slack_webhook'     => '',
	'notify_webhook'    => 'no',
	'webhook_url'       => '',
	'notify_browser'    => 'yes',
	'digest_daily'      => 'yes',
	'digest_time'       => '08:00',
	'max_notifications' => 1000,
	);
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || return \%config;
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

sub ovmnt_save_config
{
my ($cfg) = @_;
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
return 0 unless $config_file;
open(my $fh, '>', $config_file) || return 0;
foreach my $k (sort keys %$cfg) {
	print $fh "$k=$cfg->{$k}\n";
	}
close($fh);
return 1;
}

# ---------------------------------------------------------------------------
# Notification storage (JSON file)
# ---------------------------------------------------------------------------

sub ovmnt_storage_file
{
return $module_config_directory
	? "$module_config_directory/notifications.json"
	: '/tmp/openvm-notifications.json';
}

sub ovmnt_load_notifications
{
my $file = ovmnt_storage_file();
return [] unless -r $file;
open(my $fh, '<', $file) || return [];
local $/;
my $content = <$fh>;
close($fh);
return [] unless defined $content && $content ne '';
my $data = ovmnt_from_json($content);
return ref($data) eq 'ARRAY' ? $data : [];
}

sub ovmnt_save_notifications
{
my ($notifications) = @_;
my $file = ovmnt_storage_file();
my $cfg = ovmnt_module_config();
my $max = $cfg->{'max_notifications'} || 1000;
if (scalar @$notifications > $max) {
	@$notifications = @{$notifications}[-$max .. -1];
	}
my $json = ovmnt_to_json($notifications);
open(my $fh, '>', $file) || return 0;
print $fh $json;
close($fh);
return 1;
}

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

sub ovmnt_init
{
my $file = ovmnt_storage_file();
unless (-e $file) {
	ovmnt_save_notifications([]);
	}
return 1;
}

sub ovmnt_add_notification
{
my ($type, $title, $message, $priority) = @_;
$type     ||= 'info';
$priority ||= 'medium';
my $notifications = ovmnt_load_notifications();
my $id = time() . '_' . int(rand(10000));
my $now = time();
push @$notifications, {
	'id'        => $id,
	'type'      => $type,
	'title'     => $title,
	'message'   => $message,
	'priority'  => $priority,
	'read'      => 0,
	'timestamp' => $now,
	'date'      => ovmnt_format_date($now),
	};
ovmnt_save_notifications($notifications);
return $id;
}

sub ovmnt_list_notifications
{
my ($filter_type, $limit) = @_;
$limit ||= 100;
my $notifications = ovmnt_load_notifications();
my @result;
my $count = 0;
foreach my $n (reverse @$notifications) {
	last if $count >= $limit;
	if (defined $filter_type && $filter_type ne '' && $filter_type ne 'all') {
		if ($filter_type eq 'unread') {
			next if $n->{'read'};
			}
		elsif ($filter_type eq 'critical') {
			next unless $n->{'priority'} eq 'critical';
			}
		else {
			next unless $n->{'type'} eq $filter_type;
			}
		}
	push @result, $n;
	$count++;
	}
return \@result;
}

sub ovmnt_mark_read
{
my ($id) = @_;
return 0 unless defined $id && $id ne '';
my $notifications = ovmnt_load_notifications();
foreach my $n (@$notifications) {
	if ($n->{'id'} eq $id) {
		$n->{'read'} = 1;
		ovmnt_save_notifications($notifications);
		return 1;
		}
	}
return 0;
}

sub ovmnt_mark_all_read
{
my $notifications = ovmnt_load_notifications();
foreach my $n (@$notifications) {
	$n->{'read'} = 1;
	}
ovmnt_save_notifications($notifications);
return 1;
}

sub ovmnt_delete_notification
{
my ($id) = @_;
return 0 unless defined $id && $id ne '';
my $notifications = ovmnt_load_notifications();
my @filtered = grep { $_->{'id'} ne $id } @$notifications;
ovmnt_save_notifications(\@filtered);
return 1;
}

sub ovmnt_clear_all
{
ovmnt_save_notifications([]);
return 1;
}

sub ovmnt_get_unread_count
{
my $notifications = ovmnt_load_notifications();
my $count = 0;
foreach my $n (@$notifications) {
	$count++ unless $n->{'read'};
	}
return $count;
}

# ---------------------------------------------------------------------------
# Notification channels
# ---------------------------------------------------------------------------

sub ovmnt_send_email
{
my ($to, $subject, $body) = @_;
return 0 unless defined $to && $to ne '';
return 0 unless defined $subject && $subject ne '';

if (defined(&foreign_require)) {
	&foreign_require("mailboxes", "mailboxes-lib.pl");
	if (defined(&send_text_mail)) {
		&send_text_mail("openvm\@localhost", $to, $subject, $body);
		return 1;
		}
	}

# Fallback: use sendmail
my $mail_cmd = '/usr/sbin/sendmail';
if (-x $mail_cmd) {
	open(my $pipe, '|-', "$mail_cmd -t") || return 0;
	print $pipe "To: $to\n";
	print $pipe "From: openvm\@localhost\n";
	print $pipe "Subject: $subject\n";
	print $pipe "Content-Type: text/plain; charset=UTF-8\n\n";
	print $pipe $body;
	close($pipe);
	return 1;
	}
return 0;
}

sub ovmnt_send_slack
{
my ($message) = @_;
my $cfg = ovmnt_module_config();
return 0 unless $cfg->{'notify_slack'} eq 'yes';
return 0 unless $cfg->{'slack_webhook'} && $cfg->{'slack_webhook'} ne '';

my $payload = ovmnt_to_json({ 'text' => $message });
my $webhook = $cfg->{'slack_webhook'};

# Try curl
my $result = `curl -s -X POST -H 'Content-Type: application/json' -d '$payload' '$webhook' 2>/dev/null`;
return defined $result ? 1 : 0;
}

sub ovmnt_send_webhook
{
my ($data) = @_;
my $cfg = ovmnt_module_config();
return 0 unless $cfg->{'notify_webhook'} eq 'yes';
return 0 unless $cfg->{'webhook_url'} && $cfg->{'webhook_url'} ne '';

my $payload = ref($data) ? ovmnt_to_json($data) : ovmnt_to_json({ 'message' => $data });
my $url = $cfg->{'webhook_url'};

my $result = `curl -s -X POST -H 'Content-Type: application/json' -d '$payload' '$url' 2>/dev/null`;
return defined $result ? 1 : 0;
}

sub ovmnt_notify_all
{
my ($type, $title, $message, $priority) = @_;
my $id = ovmnt_add_notification($type, $title, $message, $priority);

my $cfg = ovmnt_module_config();
my $full_msg = "[$type" . ($priority ? "/$priority" : "") . "] $title\n\n$message";

# Email
if ($cfg->{'notify_email'} && $cfg->{'notify_email'} ne '') {
	ovmnt_send_email($cfg->{'notify_email'}, "[OpenVM] $title", $full_msg);
	}

# Slack
if ($cfg->{'notify_slack'} eq 'yes') {
	ovmnt_send_slack($full_msg);
	}

# Webhook
if ($cfg->{'notify_webhook'} eq 'yes') {
	ovmnt_send_webhook({
		'type'     => $type,
		'title'    => $title,
		'message'  => $message,
		'priority' => $priority,
		'time'     => ovmnt_format_date(time()),
		});
	}

return $id;
}

sub ovmnt_get_notification_channels
{
my $cfg = ovmnt_module_config();
my @channels;
push @channels, { 'name' => 'email', 'enabled' => ($cfg->{'notify_email'} ? 1 : 0), 'target' => $cfg->{'notify_email'} };
push @channels, { 'name' => 'slack', 'enabled' => ($cfg->{'notify_slack'} eq 'yes' ? 1 : 0), 'target' => $cfg->{'slack_webhook'} };
push @channels, { 'name' => 'webhook', 'enabled' => ($cfg->{'notify_webhook'} eq 'yes' ? 1 : 0), 'target' => $cfg->{'webhook_url'} };
push @channels, { 'name' => 'browser', 'enabled' => ($cfg->{'notify_browser'} eq 'yes' ? 1 : 0), 'target' => '' };
return \@channels;
}

sub ovmnt_test_channel
{
my ($channel) = @_;
my $test_msg = "OpenVM Test Notification - " . ovmnt_format_date(time());
if ($channel eq 'email') {
	my $cfg = ovmnt_module_config();
	return ovmnt_send_email($cfg->{'notify_email'}, '[OpenVM] Test', $test_msg);
	}
elsif ($channel eq 'slack') {
	return ovmnt_send_slack($test_msg);
	}
elsif ($channel eq 'webhook') {
	return ovmnt_send_webhook({ 'test' => 1, 'message' => $test_msg });
	}
return 0;
}

# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------

sub ovmnt_get_stats
{
my $notifications = ovmnt_load_notifications();
my $now = time();
my $today_start = $now - ($now % 86400);
my $week_start  = $now - (7 * 86400);

my %stats = (
	'total'    => scalar @$notifications,
	'unread'   => 0,
	'today'    => 0,
	'week'     => 0,
	'info'     => 0,
	'warning'  => 0,
	'error'    => 0,
	'success'  => 0,
	'critical' => 0,
	'channels' => 0,
	);

my $channels = ovmnt_get_notification_channels();
foreach my $ch (@$channels) {
	$stats{'channels'}++ if $ch->{'enabled'};
	}

foreach my $n (@$notifications) {
	$stats{'unread'}++ unless $n->{'read'};
	$stats{'today'}++ if $n->{'timestamp'} >= $today_start;
	$stats{'week'}++  if $n->{'timestamp'} >= $week_start;
	my $t = $n->{'type'} || '';
	$stats{$t}++ if exists $stats{$t};
	$stats{'critical'}++ if ($n->{'priority'} || '') eq 'critical';
	}

return \%stats;
}

sub ovmnt_cleanup_old
{
my ($days) = @_;
$days ||= 30;
my $cutoff = time() - ($days * 86400);
my $notifications = ovmnt_load_notifications();
my @kept = grep { $_->{'timestamp'} >= $cutoff } @$notifications;
ovmnt_save_notifications(\@kept);
return scalar(@$notifications) - scalar(@kept);
}

# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

sub ovmnt_format_date
{
my ($ts) = @_;
return '-' unless defined $ts;
my @t = localtime($ts);
return sprintf("%04d-%02d-%02d %02d:%02d:%02d",
	$t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
}

sub ovmnt_format_priority
{
my ($priority) = @_;
my %colors = (
	'low'      => '#36b37e',
	'medium'   => '#0065ff',
	'high'     => '#ff991f',
	'critical' => '#de350b',
	);
my $color = $colors{$priority} || '#0065ff';
return '<span style="background:'.$color.';color:#fff;padding:2px 8px;border-radius:3px;font-size:11px;font-weight:bold;">'.
       &html_escape(uc($priority || 'MEDIUM')).'</span>';
}

sub ovmnt_format_type
{
my ($type) = @_;
my %colors = (
	'info'    => '#0065ff',
	'warning' => '#ff991f',
	'error'   => '#de350b',
	'success' => '#36b37e',
	);
my $color = $colors{$type} || '#0065ff';
return '<span style="background:'.$color.';color:#fff;padding:2px 8px;border-radius:3px;font-size:11px;font-weight:bold;">'.
       &html_escape(uc($type || 'INFO')).'</span>';
}

sub ovmnt_time_ago
{
my ($ts) = @_;
return '-' unless defined $ts;
my $diff = time() - $ts;
if ($diff < 60) {
	return $diff . ' seg';
	}
elsif ($diff < 3600) {
	return int($diff / 60) . ' min';
	}
elsif ($diff < 86400) {
	return int($diff / 3600) . 'h';
	}
else {
	return int($diff / 86400) . 'd';
	}
}

1;
