#!/usr/bin/perl

use strict;
use warnings;
use POSIX qw(strftime);

our (%in, %text, $module_config_directory, $base_remote_user);
our $OPENVM_MON_VIRTUALMIN_LOADED = 0;

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

sub ovmon_text
{
my ($key, $fallback) = @_;
return exists($text{$key}) && defined($text{$key}) && $text{$key} ne ''
	? $text{$key}
	: $fallback;
}

sub ovmon_module_config
{
my %config = (
	'feature_cpu'       => 1,
	'feature_memory'    => 1,
	'feature_disk'      => 1,
	'feature_bandwidth' => 1,
	'feature_processes' => 1,
	'rrd_dir'           => '/var/lib/collectd/rrd',
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

sub ovmon_load_virtualmin
{
return 1 if $OPENVM_MON_VIRTUALMIN_LOADED;
&foreign_require("virtual-server", "virtual-server-lib.pl");
$OPENVM_MON_VIRTUALMIN_LOADED = 1;
return 1;
}

sub ovmon_require_access
{
ovmon_load_virtualmin();
return 1 if defined(&master_admin) && &master_admin();
return 1 if defined(&can_view_bandwidth) && &can_view_bandwidth();
return 1 if defined(&can_edit_templates) && &can_edit_templates();
&error(ovmon_text('mon_ecannot', 'You cannot access OpenVM Monitoring'));
}

# ---------------------------------------------------------------------------
# System resource snapshot (read from /proc, no external deps)
# ---------------------------------------------------------------------------

sub ovmon_cpu_info
{
my %cpu = ('cores' => 0, 'load1' => 0, 'load5' => 0, 'load15' => 0, 'idle_pct' => 0);

# /proc/cpuinfo
if (open(my $fh, '<', '/proc/cpuinfo')) {
	while (<$fh>) { $cpu{'cores'}++ if /^processor\s*:/; }
	close($fh);
	}

# /proc/stat for CPU usage
if (open(my $fh, '<', '/proc/stat')) {
	my $line = <$fh>;
	close($fh);
	if ($line && $line =~ /^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
		my ($user, $nice, $sys, $idle) = ($1, $2, $3, $4);
		my $total = $user + $nice + $sys + $idle;
		$cpu{'idle_pct'}  = $total ? int($idle * 100 / $total) : 0;
		$cpu{'usage_pct'} = 100 - $cpu{'idle_pct'};
		}
	}

# load average
if (open(my $fh, '<', '/proc/loadavg')) {
	my $line = <$fh>;
	close($fh);
	if ($line && $line =~ /^([\d.]+)\s+([\d.]+)\s+([\d.]+)/) {
		$cpu{'load1'}  = $1;
		$cpu{'load5'}  = $2;
		$cpu{'load15'} = $3;
		}
	}

return \%cpu;
}

sub ovmon_memory_info
{
my %mem = ('total_kb' => 0, 'free_kb' => 0, 'available_kb' => 0,
	   'used_kb' => 0, 'swap_total_kb' => 0, 'swap_free_kb' => 0);

if (open(my $fh, '<', '/proc/meminfo')) {
	while (my $line = <$fh>) {
		$mem{'total_kb'}     = $1 if $line =~ /^MemTotal:\s+(\d+)/;
		$mem{'free_kb'}      = $1 if $line =~ /^MemFree:\s+(\d+)/;
		$mem{'available_kb'} = $1 if $line =~ /^MemAvailable:\s+(\d+)/;
		$mem{'swap_total_kb'}= $1 if $line =~ /^SwapTotal:\s+(\d+)/;
		$mem{'swap_free_kb'} = $1 if $line =~ /^SwapFree:\s+(\d+)/;
		}
	close($fh);
	}

$mem{'used_kb'}      = $mem{'total_kb'} - ($mem{'available_kb'} || $mem{'free_kb'});
$mem{'usage_pct'}    = $mem{'total_kb'}
	? int($mem{'used_kb'} * 100 / $mem{'total_kb'})
	: 0;
$mem{'swap_used_kb'} = $mem{'swap_total_kb'} - $mem{'swap_free_kb'};
return \%mem;
}

sub ovmon_disk_info
{
my @mounts;
my $raw = `df -k --output=source,size,used,avail,pcent,target 2>/dev/null` ||
	  `df -k 2>/dev/null`;
return \@mounts unless $raw;

my @lines = split /\n/, $raw;
shift @lines;  # header
foreach my $line (@lines) {
	$line =~ s/^\s+//;
	my @f = split /\s+/, $line;
	next unless @f >= 6;
	next if $f[0] =~ /^(tmpfs|devtmpfs|udev|overlay)$/;
	push @mounts, {
		'source'   => $f[0],
		'size_kb'  => $f[1] || 0,
		'used_kb'  => $f[2] || 0,
		'avail_kb' => $f[3] || 0,
		'pct'      => do { (my $p = $f[4] || '0') =~ s/%//; int($p) },
		'mount'    => $f[5] || '-',
		};
	}
return \@mounts;
}

sub ovmon_bandwidth_per_domain
{
ovmon_load_virtualmin();
my @doms = defined(&list_visible_domains) ? &list_visible_domains()
	 : defined(&list_domains)         ? &list_domains()
	 : ();

my @result;
foreach my $d (@doms) {
	next unless $d->{'web'};
	my $used  = 0;
	my $quota = $d->{'bw_limit'} || 0;

	# GPL bandwidth helper
	if (defined(&get_domain_bandwidth)) {
		my $bwinfo = eval { &get_domain_bandwidth($d) };
		$used = $bwinfo->{'total'} || 0 if $bwinfo && !$@;
		}
	elsif (defined(&get_bandwidth)) {
		my $bwinfo = eval { &get_bandwidth($d) };
		$used = $bwinfo || 0 if !$@;
		}

	push @result, {
		'dom'      => $d->{'dom'},
		'used_mb'  => int($used / (1024*1024)),
		'quota_mb' => $quota ? int($quota / (1024*1024)) : 0,
		'pct'      => ($quota && $quota > 0) ? int($used * 100 / $quota) : 0,
		};
	}
return \@result;
}

sub ovmon_top_processes
{
my ($limit) = @_;
$limit ||= 15;
my @procs;
my $raw = `ps aux --sort=-%cpu 2>/dev/null | head -n \Q$limit\E`;
return \@procs unless $raw;
my @lines = split /\n/, $raw;
shift @lines;  # header
foreach my $line (@lines) {
	$line =~ s/^\s+//;
	my @f = split /\s+/, $line, 11;
	next unless @f >= 11;
	push @procs, {
		'user'    => $f[0],
		'pid'     => $f[1],
		'cpu_pct' => $f[2],
		'mem_pct' => $f[3],
		'command' => $f[10],
		};
	}
return \@procs;
}

sub ovmon_rrd_available
{
my $cfg = ovmon_module_config();
return -d $cfg->{'rrd_dir'} && `which rrdtool 2>/dev/null` ? 1 : 0;
}

1;
