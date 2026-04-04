#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_BACKUP_VIRTUALMIN_LOADED = 0;

sub ovmb_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmb_module_config
{
my %config = (
	'feature_schedules' => 1,
	'feature_keys' => 1,
	'feature_restore' => 1,
	'default_restore_domain_limit' => 25,
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

sub ovmb_load_virtualmin
{
return 1 if ($OPENVM_BACKUP_VIRTUALMIN_LOADED);
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_BACKUP_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmb_require_access
{
ovmb_load_virtualmin();
return 1 if (defined(&master_admin) && &master_admin());
return 1 if (defined(&can_backup_domain) && &can_backup_domain());
return 1 if (defined(&can_edit_resellers) && &can_edit_resellers());
&error(ovmb_text('backup_ecannot', 'You cannot manage backups from OpenVM Backup'));
}

sub ovmb_current_domain
{
my ($hint) = @_;
$hint ||= {};
ovmb_load_virtualmin();
my $id = defined($hint->{'id'}) ? $hint->{'id'} : $in{'id'};
my $dom = defined($hint->{'dom'}) ? $hint->{'dom'} : $in{'dom'};
my $user = defined($hint->{'user'}) ? $hint->{'user'} : $base_remote_user;
my $d;
$d = &get_domain($id) if (defined($id) && $id ne '');
$d ||= &get_domain_by('dom', $dom) if (defined($dom) && $dom ne '');
$d ||= &get_domain_by('user', $user) if (defined($user) && $user ne '');
return $d;
}

sub ovmb_visible_domains
{
ovmb_load_virtualmin();
my @doms = defined(&list_visible_domains) ? &list_visible_domains()
	: defined(&list_domains) ? &list_domains() : ();
return \@doms;
}

sub ovmb_backup_keys
{
ovmb_load_virtualmin();
my @keys;
if (defined(&list_backup_keys)) {
	@keys = &list_backup_keys();
	}
else {
	my $keyring = '/etc/webmin/virtual-server/bkeys';
	if (-d $keyring) {
		my $out = `gpg --homedir $keyring --list-keys --with-colons 2>/dev/null`;
		foreach my $line (split(/\n/, $out)) {
			my @f = split(/:/, $line);
			next if ($f[0] ne 'pub');
			push(@keys, {
				'id' => $f[4] || 'unknown',
				'desc' => 'GPG backup key',
				'owner' => 'root',
				'created' => $f[5] || undef,
				});
			}
		}
	}
return \@keys;
}

sub ovmb_scheduled_backups
{
ovmb_load_virtualmin();
my @scheds = defined(&list_scheduled_backups) ? &list_scheduled_backups() : ();
my @rows;

foreach my $sched (@scheds) {
	my @dests = defined(&get_scheduled_backup_dests) ? &get_scheduled_backup_dests($sched) : ();
	my @purges = defined(&get_scheduled_backup_purges) ? &get_scheduled_backup_purges($sched) : ();
	my $owner = '-';
	if ($sched->{'owner'}) {
		my $od = eval { &get_domain($sched->{'owner'}) };
		$owner = $od ? ($od->{'dom'} || $od->{'user'} || $sched->{'owner'}) : $sched->{'owner'};
		}
	my $targets = $sched->{'all'} ? 'All visible domains'
		: $sched->{'doms'} ? scalar(split(/\s+/, $sched->{'doms'})).' selected'
		: '-';
	push(@rows, {
		'id' => $sched->{'id'},
		'desc' => $sched->{'desc'} || 'Scheduled backup',
		'owner' => $owner,
		'targets' => $targets,
		'dests' => \@dests,
		'purges' => \@purges,
		'format' => $sched->{'fmt'},
		'enabled' => $sched->{'disabled'} ? 0 : 1,
		'raw' => $sched,
		});
	}

return \@rows;
}

sub ovmb_restore_inventory
{
my $config = ovmb_module_config();
my $limit = $config->{'default_restore_domain_limit'} || 25;
my $domains = ovmb_visible_domains();
my @subset = @$domains > $limit ? @$domains[0 .. $limit-1] : @$domains;
my $keys = ovmb_backup_keys();
my $scheds = ovmb_scheduled_backups();
return {
	'domains' => \@subset,
	'keys' => $keys,
	'schedules' => $scheds,
	'total_domains' => scalar(@$domains),
	};
}

sub ovmb_summary
{
my $domains = ovmb_visible_domains();
my $keys = ovmb_backup_keys();
my $scheds = ovmb_scheduled_backups();
return {
	'domains' => scalar(@$domains),
	'keys' => scalar(@$keys),
	'schedules' => scalar(@$scheds),
	};
}

1;
