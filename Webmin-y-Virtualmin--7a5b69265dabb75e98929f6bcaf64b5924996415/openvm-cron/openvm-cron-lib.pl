#!/usr/bin/perl

use strict;
use warnings;
use File::Temp qw(tempfile);

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_CRON_VIRTUALMIN_LOADED = 0;

###############################################################################
# ovmcr_sanitize_user - Validate and sanitize username for shell commands
# Only allows alphanumeric, underscore, hyphen, and dot (POSIX safe chars)
###############################################################################
sub ovmcr_sanitize_user
{
my ($user) = @_;
return undef unless (defined($user) && $user =~ /^[\w.\-]+$/);
return $user;
}

###############################################################################
# ovmcr_sanitize_shell - Escape shell metacharacters in a string
###############################################################################
sub ovmcr_sanitize_shell
{
my ($str) = @_;
return '' unless (defined($str));
$str =~ s/'/'\\''/g;
return $str;
}

###############################################################################
# ovmcr_text - Get text string with fallback
###############################################################################
sub ovmcr_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

###############################################################################
# ovmcr_module_config - Read module configuration
###############################################################################
sub ovmcr_module_config
{
my %config = (
	'cron_user' => 'root',
	'log_output' => 'yes',
	'max_log_size' => 1048576,
	'allow_user_cron' => 'yes',
	);
my $config_file = $module_config_directory ? "$module_config_directory/config" : undef;
if ($config_file && -r $config_file) {
	open(my $fh, '<', $config_file) || die "Failed to read $config_file : $!";
	while(my $line = <$fh>) {
		chomp($line);
		next if ($line =~ /^\s*#/ || $line !~ /=/);
		my ($key, $value) = split(/=/, $line, 2);
		next if (!defined($key) || $key eq '');
		$config{$key} = $value;
		}
	close($fh);
	}
return \%config;
}

###############################################################################
# ovmcr_init - Initialize module
###############################################################################
sub ovmcr_init
{
return ovmcr_module_config();
}

###############################################################################
# ovmcr_load_virtualmin - Load Virtualmin library
###############################################################################
sub ovmcr_load_virtualmin
{
return 1 if ($OPENVM_CRON_VIRTUALMIN_LOADED);
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_CRON_VIRTUALMIN_LOADED = 1;
return 1;
}

###############################################################################
# ovmcr_require_access - Check access permissions
###############################################################################
sub ovmcr_require_access
{
ovmcr_load_virtualmin();
return 1 if (defined(&master_admin) && &master_admin());
return 1 if (defined(&can_edit_domain) && &can_edit_domain());
&error(ovmcr_text('cron_ecannot', 'You cannot manage cron jobs from OpenVM Cron Manager'));
}

###############################################################################
# ovmcr_parse_cron_line - Parse a single crontab line
###############################################################################
sub ovmcr_parse_cron_line
{
my ($line) = @_;
return undef unless ($line);
chomp($line);
$line =~ s/^\s+//;
$line =~ s/\s+$//;
return undef if ($line eq '' || $line =~ /^#/);
if ($line =~ /^@(\w+)\s+(.+)$/) {
	return {
		'special' => $1,
		'cmd' => $2,
		'min' => '*', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		};
	}
if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/) {
	return {
		'min' => $1,
		'hour' => $2,
		'day' => $3,
		'month' => $4,
		'wday' => $5,
		'cmd' => $6,
		'special' => '',
		};
	}
return undef;
}

###############################################################################
# ovmcr_format_cron_line - Format a job hash into crontab line
###############################################################################
sub ovmcr_format_cron_line
{
my (%job) = @_;
if ($job{'special'} && $job{'special'} ne '') {
	return '@' . $job{'special'} . ' ' . $job{'cmd'};
	}
return join(' ', $job{'min'}, $job{'hour'}, $job{'day'}, $job{'month'}, $job{'wday'}, $job{'cmd'});
}

###############################################################################
# ovmcr_validate_schedule - Validate cron schedule fields
###############################################################################
sub ovmcr_validate_schedule
{
my ($min, $hour, $day, $month, $wday) = @_;
my @errors;
push(@errors, 'Invalid minute') unless (!defined($min) || $min eq '*' || $min =~ /^[\d,\-\/]+$/);
push(@errors, 'Invalid hour') unless (!defined($hour) || $hour eq '*' || $hour =~ /^[\d,\-\/]+$/);
push(@errors, 'Invalid day') unless (!defined($day) || $day eq '*' || $day =~ /^[\d,\-\/]+$/);
push(@errors, 'Invalid month') unless (!defined($month) || $month eq '*' || $month =~ /^[\d,\-\/]+$/);
push(@errors, 'Invalid weekday') unless (!defined($wday) || $wday eq '*' || $wday =~ /^[\d,\-\/\*]+$/);
return scalar(@errors) ? join(', ', @errors) : '';
}

###############################################################################
# ovmcr_list_jobs - List cron jobs for a user
###############################################################################
sub ovmcr_list_jobs
{
my ($user) = @_;
$user ||= 'root';
# SECURITY: Validate username to prevent command injection
if ($user ne 'root') {
	my $safe_user = ovmcr_sanitize_user($user);
	return [] unless ($safe_user);
	$user = $safe_user;
	}
my @jobs;
my $out;
if ($user eq 'root') {
	$out = `crontab -l 2>/dev/null`;
	}
else {
	$out = `crontab -u $user -l 2>/dev/null`;
	}
my $line_num = 0;
foreach my $line (split(/\n/, $out)) {
	$line_num++;
	my $job = ovmcr_parse_cron_line($line);
	next unless ($job);
	$job->{'line'} = $line_num;
	$job->{'raw'} = $line;
	$job->{'user'} = $user;
	$job->{'human'} = ovmcr_human_schedule($job->{'min'}, $job->{'hour'}, $job->{'day'}, $job->{'month'}, $job->{'wday'});
	push(@jobs, $job);
	}
return \@jobs;
}

###############################################################################
# ovmcr_add_job - Add a new cron job
###############################################################################
sub ovmcr_add_job
{
my ($user, $min, $hour, $day, $month, $wday, $cmd) = @_;
$user ||= 'root';
# SECURITY: Validate username to prevent command injection
if ($user ne 'root') {
	my $safe_user = ovmcr_sanitize_user($user);
	return { 'ok' => 0, 'error' => 'Invalid username' } unless ($safe_user);
	$user = $safe_user;
	}
return { 'ok' => 0, 'error' => 'No command specified' } unless ($cmd);
my $validation = ovmcr_validate_schedule($min, $hour, $day, $month, $wday);
return { 'ok' => 0, 'error' => "Invalid schedule: $validation" } if ($validation);
my %job = (
	'min' => $min || '*',
	'hour' => $hour || '*',
	'day' => $day || '*',
	'month' => $month || '*',
	'wday' => $wday || '*',
	'cmd' => $cmd,
	);
my $new_line = ovmcr_format_cron_line(%job);
my $existing = '';
if ($user eq 'root') {
	$existing = `crontab -l 2>/dev/null`;
	}
else {
	$existing = `crontab -u $user -l 2>/dev/null`;
	}
# SECURITY: Use File::Temp instead of predictable /tmp filename
my ($fh, $tmp) = tempfile(UNLINK => 1, SUFFIX => '.cron') || return { 'ok' => 0, 'error' => "Cannot write temp file: $!" };
print $fh $existing if ($existing);
print $fh $new_line . "\n";
close($fh);
my $result;
if ($user eq 'root') {
	$result = `crontab $tmp 2>&1`;
	}
else {
	$result = `crontab -u $user $tmp 2>&1`;
	}
unlink($tmp);
if ($?) {
	return { 'ok' => 0, 'error' => $result };
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmcr_delete_job - Delete a cron job by line number
###############################################################################
sub ovmcr_delete_job
{
my ($user, $line_num) = @_;
$user ||= 'root';
# SECURITY: Validate username to prevent command injection
if ($user ne 'root') {
	my $safe_user = ovmcr_sanitize_user($user);
	return { 'ok' => 0, 'error' => 'Invalid username' } unless ($safe_user);
	$user = $safe_user;
	}
return { 'ok' => 0, 'error' => 'No line number specified' } unless (defined($line_num));
my $existing = '';
if ($user eq 'root') {
	$existing = `crontab -l 2>/dev/null`;
	}
else {
	$existing = `crontab -u $user -l 2>/dev/null`;
	}
my @lines = split(/\n/, $existing);
# SECURITY: Use File::Temp instead of predictable /tmp filename
my ($fh, $tmp) = tempfile(UNLINK => 1, SUFFIX => '.cron') || return { 'ok' => 0, 'error' => "Cannot write temp file: $!" };
my $current = 0;
foreach my $line (@lines) {
	$current++;
	next if ($current == $line_num);
	print $fh $line . "\n";
	}
close($fh);
my $result;
if ($user eq 'root') {
	$result = `crontab $tmp 2>&1`;
	}
else {
	$result = `crontab -u $user $tmp 2>&1`;
	}
unlink($tmp);
if ($?) {
	return { 'ok' => 0, 'error' => $result };
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmcr_edit_job - Edit a cron job by line number
###############################################################################
sub ovmcr_edit_job
{
my ($user, $line_num, $min, $hour, $day, $month, $wday, $cmd) = @_;
$user ||= 'root';
# SECURITY: Validate username to prevent command injection
if ($user ne 'root') {
	my $safe_user = ovmcr_sanitize_user($user);
	return { 'ok' => 0, 'error' => 'Invalid username' } unless ($safe_user);
	$user = $safe_user;
	}
return { 'ok' => 0, 'error' => 'No line number specified' } unless (defined($line_num));
return { 'ok' => 0, 'error' => 'No command specified' } unless ($cmd);
my $validation = ovmcr_validate_schedule($min, $hour, $day, $month, $wday);
return { 'ok' => 0, 'error' => "Invalid schedule: $validation" } if ($validation);
my %job = (
	'min' => $min || '*',
	'hour' => $hour || '*',
	'day' => $day || '*',
	'month' => $month || '*',
	'wday' => $wday || '*',
	'cmd' => $cmd,
	);
my $new_line = ovmcr_format_cron_line(%job);
my $existing = '';
if ($user eq 'root') {
	$existing = `crontab -l 2>/dev/null`;
	}
else {
	$existing = `crontab -u $user -l 2>/dev/null`;
	}
my @lines = split(/\n/, $existing);
# SECURITY: Use File::Temp instead of predictable /tmp filename
my ($fh, $tmp) = tempfile(UNLINK => 1, SUFFIX => '.cron') || return { 'ok' => 0, 'error' => "Cannot write temp file: $!" };
my $current = 0;
foreach my $line (@lines) {
	$current++;
	if ($current == $line_num) {
		print $fh $new_line . "\n";
		}
	else {
		print $fh $line . "\n";
		}
	}
close($fh);
my $result;
if ($user eq 'root') {
	$result = `crontab $tmp 2>&1`;
	}
else {
	$result = `crontab -u $user $tmp 2>&1`;
	}
unlink($tmp);
if ($?) {
	return { 'ok' => 0, 'error' => $result };
	}
return { 'ok' => 1, 'error' => '' };
}

###############################################################################
# ovmcr_get_job_output - Get output of a cron job
###############################################################################
sub ovmcr_get_job_output
{
my ($user, $line_num) = @_;
$user ||= 'root';
# SECURITY: Validate username to prevent command injection
if ($user ne 'root') {
	my $safe_user = ovmcr_sanitize_user($user);
	return { 'ok' => 0, 'error' => 'Invalid username' } unless ($safe_user);
	$user = $safe_user;
	}
my $jobs = ovmcr_list_jobs($user);
my $job = $jobs->[$line_num - 1];
return { 'ok' => 0, 'error' => 'Job not found' } unless ($job);
my $cmd = $job->{'cmd'};
$cmd =~ s/\s+.*$//;
$cmd =~ s/.*\///;
# SECURITY: Sanitize extracted command name for use in file path
$cmd =~ s/[^a-zA-Z0-9_\-.]//g;
return { 'ok' => 0, 'error' => 'Invalid command name' } unless ($cmd && length($cmd) < 256);
my $log_file = "/var/log/cron_output_${cmd}.log";
if (-r $log_file) {
	open(my $fh, '<', $log_file) || return { 'ok' => 0, 'error' => "Cannot read $log_file" };
	my $content = do { local $/; <$fh> };
	close($fh);
	return { 'ok' => 1, 'error' => '', 'output' => $content };
	}
return { 'ok' => 0, 'error' => 'No output log found for this job' };
}

###############################################################################
# ovmcr_list_system_timers - List systemd timers
###############################################################################
sub ovmcr_list_system_timers
{
my @timers;
my $out = `systemctl list-timers --all --no-pager --no-legend 2>/dev/null`;
foreach my $line (split(/\n/, $out)) {
	next unless ($line =~ /\S/);
	my @f = split(/\s+/, $line);
	next if (scalar(@f) < 7);
	push(@timers, {
		'next_run' => "$f[0] $f[1] $f[2]",
		'left' => "$f[3] $f[4]",
		'unit' => $f[6] || 'unknown',
		'activates' => $f[7] || '',
		});
	}
return \@timers;
}

###############################################################################
# ovmcr_get_cron_log - Get cron log
###############################################################################
sub ovmcr_get_cron_log
{
my $config = ovmcr_module_config();
my $max = $config->{'max_log_size'} || 1048576;
my $log_content = '';
if (-r '/var/log/cron') {
	$log_content = `tail -c $max /var/log/cron 2>/dev/null`;
	}
elsif (-r '/var/log/syslog') {
	$log_content = `grep -i cron /var/log/syslog 2>/dev/null | tail -c $max`;
	}
else {
	$log_content = `journalctl -u cron --no-pager -n 500 2>/dev/null`;
	}
return $log_content;
}

###############################################################################
# ovmcr_human_schedule - Convert schedule to human readable
###############################################################################
sub ovmcr_human_schedule
{
my ($min, $hour, $day, $month, $wday) = @_;
$min //= '*'; $hour //= '*'; $day //= '*'; $month //= '*'; $wday //= '*';

# Common patterns
return 'Every minute' if ($min eq '*' && $hour eq '*' && $day eq '*' && $month eq '*' && $wday eq '*');
return 'Every hour' if ($min ne '*' && $hour eq '*' && $day eq '*' && $month eq '*' && $wday eq '*');
return "Every $min minutes" if ($min =~ /^\*\/(\d+)$/ && $hour eq '*' && $day eq '*' && $month eq '*' && $wday eq '*');
return "Hourly at minute $min" if ($min ne '*' && $hour eq '*' && $day eq '*' && $month eq '*' && $wday eq '*');

my @days = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');
my @months = ('','January','February','March','April','May','June','July','August','September','October','November','December');

my $desc = '';

if ($wday ne '*') {
	if ($wday =~ /^\d+$/) {
		$desc .= $days[$wday] . 's';
		}
	else {
		$desc .= "weekday $wday";
		}
	}
elsif ($day ne '*') {
	$desc .= "day $day of the month";
	}
else {
	$desc .= 'Daily' if ($hour ne '*' || $min ne '*');
	}

if ($month ne '*') {
	if ($month =~ /^\d+$/) {
		$desc .= ' in ' . $months[$month];
		}
	else {
		$desc .= " in month $month";
		}
	}

if ($hour ne '*' && $min ne '*') {
	$desc .= " at $hour:$min";
	}
elsif ($hour ne '*') {
	$desc .= " at hour $hour";
	}
elsif ($min ne '*' && $desc eq '') {
	$desc = "At minute $min";
	}

return $desc || 'Custom schedule';
}

###############################################################################
# ovmcr_common_templates - Return common cron templates
###############################################################################
sub ovmcr_common_templates
{
my @templates = (
	{
		'name' => 'Every minute',
		'desc' => 'Run every minute of every day',
		'min' => '*', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Every 5 minutes',
		'desc' => 'Run every 5 minutes',
		'min' => '*/5', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Every 15 minutes',
		'desc' => 'Run every 15 minutes',
		'min' => '*/15', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Every 30 minutes',
		'desc' => 'Run every 30 minutes',
		'min' => '*/30', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Every hour',
		'desc' => 'Run at the start of every hour',
		'min' => '0', 'hour' => '*', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Every 6 hours',
		'desc' => 'Run every 6 hours',
		'min' => '0', 'hour' => '*/6', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Daily at midnight',
		'desc' => 'Run once a day at 00:00',
		'min' => '0', 'hour' => '0', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Daily at 2:00 AM',
		'desc' => 'Run once a day at 02:00',
		'min' => '0', 'hour' => '2', 'day' => '*', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Weekly on Sunday',
		'desc' => 'Run every Sunday at midnight',
		'min' => '0', 'hour' => '0', 'day' => '*', 'month' => '*', 'wday' => '0',
		'cmd' => '/path/to/script.sh',
		},
	{
		'name' => 'Monthly on the 1st',
		'desc' => 'Run on the 1st of every month at midnight',
		'min' => '0', 'hour' => '0', 'day' => '1', 'month' => '*', 'wday' => '*',
		'cmd' => '/path/to/script.sh',
		},
	);
return \@templates;
}

1;
