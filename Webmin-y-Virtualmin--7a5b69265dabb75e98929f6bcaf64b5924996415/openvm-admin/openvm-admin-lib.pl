#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $base_remote_user, $module_config_directory);
our $OPENVM_ADMIN_VIRTUALMIN_LOADED = 0;

sub ovma_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovma_module_config
{
my %config = (
	'feature_admins' => 1,
	'feature_resellers' => 1,
	'feature_audit' => 1,
	'default_audit_limit' => 100,
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

sub ovma_load_virtualmin
{
return 1 if ($OPENVM_ADMIN_VIRTUALMIN_LOADED);
&foreign_require("virtual-server", "virtual-server-lib.pl");
eval { &foreign_require("virtual-server", "admins-lib.pl"); };
eval { &foreign_require("virtual-server", "rbac-lib.pl"); };
eval { &foreign_require("virtual-server", "audit-lib.pl"); };
$OPENVM_ADMIN_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovma_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovma_load_virtualmin();
my $id = defined($hint->{'id'}) ? $hint->{'id'} : $in{'id'};
my $dom = defined($hint->{'dom'}) ? $hint->{'dom'} : $in{'dom'};
my $user = defined($hint->{'user'}) ? $hint->{'user'} : $base_remote_user;
my $d;
$d = &get_domain($id) if (defined($id) && $id ne '');
$d ||= &get_domain_by('dom', $dom) if (defined($dom) && $dom ne '');
$d ||= &get_domain_by('user', $user) if (defined($user) && $user ne '');
return $d;
}

sub ovma_require_domain_access
{
my ($d, $deny_message) = @_;
$d ||= ovma_current_domain();
$d || &error(ovma_text('edit_egone', 'No virtual server selected'));
&can_edit_domain($d) || &error($deny_message || ovma_text('edit_ecannot', 'You cannot manage this virtual server'));
return $d;
}

sub ovma_can_access_admin_module
{
ovma_load_virtualmin();
return 1 if (defined(&master_admin) && &master_admin());
return 1 if (defined(&can_edit_templates) && &can_edit_templates());
return 1 if (defined(&check_permission) && eval { &check_permission('rbac', 'admin') });
return 1 if (defined(&check_permission) && eval { &check_permission('virtualmin', 'read') });
return 0;
}

sub ovma_require_module_access
{
ovma_can_access_admin_module() || &error('Access denied to OpenVM Administration');
return 1;
}

sub ovma_list_domain_admins
{
my ($d) = @_;
ovma_load_virtualmin();
return [] if (!defined(&list_extra_admins));
my @admins = &list_extra_admins($d);
return \@admins;
}

sub ovma_list_resellers
{
ovma_load_virtualmin();
return [] if (!defined(&list_resellers));
my @resellers = &list_resellers();
return \@resellers;
}

sub ovma_list_webmin_users
{
ovma_load_virtualmin();
&require_acl() if (defined(&require_acl));
my @users = eval { &acl::list_users() };
return \@users;
}

sub ovma_audit_logs
{
my ($limit) = @_;
$limit ||= ovma_module_config()->{'default_audit_limit'} || 100;
ovma_load_virtualmin();

if (defined(&get_audit_logs)) {
	my $logs = &get_audit_logs($limit);
	return $logs || [];
	}

my $local_log = $module_config_directory ? "$module_config_directory/openvm-admin.audit.log" : undef;
return [] if (!$local_log || !-r $local_log);

open(my $fh, '<', $local_log) || return [];
my @lines = <$fh>;
close($fh);
@lines = reverse @lines;
splice(@lines, $limit) if (@lines > $limit);

my @logs;
foreach my $line (@lines) {
	chomp($line);
	my ($timestamp, $user, $action, $module, $details) = split(/\|/, $line, 5);
	push(@logs, {
		'timestamp' => $timestamp,
		'user' => $user,
		'action' => $action,
		'module' => $module,
		'details' => $details,
		});
	}
return \@logs;
}

sub ovma_log_action
{
my ($action, $module, $details) = @_;
my $user = $base_remote_user || 'unknown';
my $timestamp = time();
ovma_load_virtualmin();

if (defined(&log_action)) {
	&log_action($user, $action, $module, $details);
	return 1;
	}

my $local_log = $module_config_directory ? "$module_config_directory/openvm-admin.audit.log" : undef;
return 0 if (!$local_log);
open(my $fh, '>>', $local_log) || return 0;
print $fh "$timestamp|$user|$action|$module|$details\n";
close($fh);
return 1;
}

sub ovma_render_domains_desc
{
my ($admin) = @_;
return 'All assigned domains' if (!$admin->{'doms'});
my @doms = grep { $_ } map { &get_domain($_) } split(/\s+/, $admin->{'doms'});
my @names = map { $_->{'dom'} || $_->{'id'} } @doms;
return join(', ', @names) if (@names);
return $admin->{'doms'};
}

sub ovma_summary
{
my $d = ovma_current_domain();
my $admins = $d ? scalar(@{ovma_list_domain_admins($d)}) : 0;
my $resellers = scalar(@{ovma_list_resellers()});
my $users = scalar(@{ovma_list_webmin_users()});
my $logs = ovma_audit_logs(10);
return {
	'domain' => $d,
	'admins' => $admins,
	'resellers' => $resellers,
	'users' => $users,
	'audits' => scalar(@$logs),
	};
}

1;
