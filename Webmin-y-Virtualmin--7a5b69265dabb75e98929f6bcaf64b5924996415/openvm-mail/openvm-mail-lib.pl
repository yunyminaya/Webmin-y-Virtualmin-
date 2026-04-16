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

1;
