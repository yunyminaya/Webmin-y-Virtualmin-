#!/usr/bin/perl

use strict;
use warnings;

our (%in, %text, %config, $base_remote_user, $module_config_directory);

# ---------------------------------------------------------------------------
# ovmd_init() - Load config, initialize module
# ---------------------------------------------------------------------------
sub ovmd_init
{
    my %defaults = (
        'refresh_interval'    => 30,
        'show_cpu_graph'      => 1,
        'show_memory_graph'   => 1,
        'show_disk_graph'     => 1,
        'show_bandwidth_graph'=> 1,
        'show_domain_list'    => 1,
        'max_domains_display' => 20,
        'chart_type'          => 'bar',
    );

    my $config_file = $module_config_directory
                    ? "$module_config_directory/config"
                    : undef;

    if ($config_file && -r $config_file) {
        open(my $fh, '<', $config_file) || return \%defaults;
        while (my $line = <$fh>) {
            chomp($line);
            next if ($line =~ /^\s*#/ || $line !~ /=/);
            my ($key, $value) = split(/=/, $line, 2);
            next if (!defined($key) || $key eq '');
            $defaults{$key} = $value;
        }
        close($fh);
    }
    return \%defaults;
}

# ---------------------------------------------------------------------------
# ovmd_system_metrics() - Return hash with system metrics
# ---------------------------------------------------------------------------
sub ovmd_system_metrics
{
    my %m;

    # Hostname
    chomp($m{'hostname'} = `hostname 2>/dev/null` || 'unknown');

    # Kernel
    chomp($m{'kernel'} = `uname -r 2>/dev/null` || 'unknown');

    # Uptime
    if (-r '/proc/uptime') {
        open(my $fh, '<', '/proc/uptime') && do {
            my $line = <$fh>;
            close($fh);
            my ($secs) = split(/\s+/, $line);
            $m{'uptime_seconds'} = int($secs || 0);
            $m{'uptime_human'}   = ovmd_format_uptime($m{'uptime_seconds'});
        };
    } else {
        my $up = `uptime 2>/dev/null`;
        $m{'uptime_human'}   = $up ? (split(/,/, $up))[0] : 'unknown';
        $m{'uptime_seconds'} = 0;
    }

    # CPU load average
    my $load = `cat /proc/loadavg 2>/dev/null`;
    if ($load) {
        my @lp = split(/\s+/, $load);
        $m{'load_1'}  = $lp[0] || 0;
        $m{'load_5'}  = $lp[1] || 0;
        $m{'load_15'} = $lp[2] || 0;
    } else {
        $m{'load_1'} = $m{'load_5'} = $m{'load_15'} = 0;
    }

    # CPU cores
    chomp(my $cores = `grep -c ^processor /proc/cpuinfo 2>/dev/null`);
    $m{'cpu_cores'} = $cores || 1;

    # CPU usage percent
    $m{'cpu_percent'} = ovmd_cpu_usage();

    # Memory
    my %mem = ovmd_memory_info();
    $m{'mem_total'}   = $mem{'total'};
    $m{'mem_used'}    = $mem{'used'};
    $m{'mem_free'}    = $mem{'free'};
    $m{'mem_cached'}  = $mem{'cached'};
    $m{'mem_percent'} = $mem{'percent'};

    # Swap
    $m{'swap_total'}   = $mem{'swap_total'};
    $m{'swap_used'}    = $mem{'swap_used'};
    $m{'swap_percent'} = $mem{'swap_percent'};

    # Disk
    $m{'partitions'} = ovmd_disk_info();

    return \%m;
}

# ---------------------------------------------------------------------------
# ovmd_cpu_usage() - Calculate CPU usage percentage
# ---------------------------------------------------------------------------
sub ovmd_cpu_usage
{
    my $cpu_info = `grep '^cpu ' /proc/stat 2>/dev/null`;
    return 0 unless $cpu_info;

    my @v1 = split(/\s+/, $cpu_info);
    shift @v1; # remove 'cpu' label
    my $idle1  = $v1[3] || 0;
    my $total1 = 0;
    $total1 += ($_ || 0) for @v1;

    # Wait 200ms
    select(undef, undef, undef, 0.2);

    $cpu_info = `grep '^cpu ' /proc/stat 2>/dev/null`;
    return 0 unless $cpu_info;

    my @v2 = split(/\s+/, $cpu_info);
    shift @v2;
    my $idle2  = $v2[3] || 0;
    my $total2 = 0;
    $total2 += ($_ || 0) for @v2;

    my $diff_idle  = $idle2 - $idle1;
    my $diff_total = $total2 - $total1;
    return 0 if $diff_total == 0;

    return int((1 - ($diff_idle / $diff_total)) * 100);
}

# ---------------------------------------------------------------------------
# ovmd_memory_info() - Parse /proc/meminfo
# ---------------------------------------------------------------------------
sub ovmd_memory_info
{
    my %m = (
        'total'   => 0, 'used' => 0, 'free' => 0,
        'cached'  => 0, 'percent' => 0,
        'swap_total' => 0, 'swap_used' => 0, 'swap_percent' => 0,
    );

    if (-r '/proc/meminfo') {
        open(my $fh, '<', '/proc/meminfo') || return \%m;
        my %raw;
        while (my $line = <$fh>) {
            if ($line =~ /^(\w+):\s+(\d+)/) {
                $raw{$1} = $2;
            }
        }
        close($fh);

        my $total  = $raw{'MemTotal'}  || 0;
        my $free   = $raw{'MemFree'}   || 0;
        my $cached = ($raw{'Cached'} || 0) + ($raw{'Buffers'} || 0);
        my $used   = $total - $free - $cached;

        $m{'total'}   = $total;
        $m{'used'}    = $used > 0 ? $used : 0;
        $m{'free'}    = $free;
        $m{'cached'}  = $cached;
        $m{'percent'} = $total > 0 ? int(($used / $total) * 100) : 0;

        my $st = $raw{'SwapTotal'} || 0;
        my $sf = $raw{'SwapFree'}  || 0;
        $m{'swap_total'}   = $st;
        $m{'swap_used'}    = $st - $sf;
        $m{'swap_percent'} = $st > 0 ? int((($st - $sf) / $st) * 100) : 0;
    }
    return %m;
}

# ---------------------------------------------------------------------------
# ovmd_disk_info() - Disk usage per partition
# ---------------------------------------------------------------------------
sub ovmd_disk_info
{
    my @parts;
    my $df = `df -k -x tmpfs -x devtmpfs -x squashfs 2>/dev/null`;
    return \@parts unless $df;

    foreach my $line (split(/\n/, $df)) {
        next if $line =~ /^Filesystem/;
        my @f = split(/\s+/, $line);
        next if scalar(@f) < 6;

        my $total = $f[1] || 0;
        my $used  = $f[2] || 0;
        my $avail = $f[3] || 0;
        my $pct   = $f[4] || '0%';
        $pct =~ s/%//;

        push @parts, {
            'mount'   => $f[5],
            'total'   => $total,
            'used'    => $used,
            'free'    => $avail,
            'percent' => int($pct),
        };
    }
    return \@parts;
}

# ---------------------------------------------------------------------------
# ovmd_format_uptime() - Format seconds into human-readable string
# ---------------------------------------------------------------------------
sub ovmd_format_uptime
{
    my ($secs) = @_;
    $secs ||= 0;
    my $d = int($secs / 86400);
    my $h = int(($secs % 86400) / 3600);
    my $m = int(($secs % 3600) / 60);
    return "${d}d ${h}h ${m}m";
}

# ---------------------------------------------------------------------------
# ovmd_domain_summary() - Return array of domain info hashes
# ---------------------------------------------------------------------------
sub ovmd_domain_summary
{
    my @domains;

    eval {
        &foreign_require("virtual-server", "virtual-server-lib.pl");
        my @all = &list_domains();

        for my $d (@all) {
            my $q_used  = $d->{'quota'} || 0;
            my $q_total = $d->{'quota_limit'} || 0;
            my $bw_used = $d->{'bw_usage'} || 0;
            my $bw_total= $d->{'bw_limit'} || 0;

            push @domains, {
                'dom'            => $d->{'dom'}           || '',
                'user'           => $d->{'user'}          || '',
                'web'            => ($d->{'web'}          ? 1 : 0),
                'mail'           => ($d->{'mail'}         ? 1 : 0),
                'ssl'            => ($d->{'ssl'}          ? 1 : 0),
                'dns'            => ($d->{'dns'}          ? 1 : 0),
                'quota_used'     => $q_used,
                'quota_total'    => $q_total,
                'bandwidth_used' => $bw_used,
                'bandwidth_total'=> $bw_total,
                'status'         => ($d->{'disabled'}     ? 'disabled' : 'active'),
            };
        }
    };

    if ($@) {
        # Fallback: try virtualmin list-domains CLI
        eval {
            my $out = `virtualmin list-domains --name-only --status 2>/dev/null`;
            return \@domains unless $out;
            for my $line (split(/\n/, $out)) {
                chomp($line);
                next unless $line;
                my ($name, $status) = split(/\s+/, $line, 2);
                push @domains, {
                    'dom'    => $name,
                    'user'   => '',
                    'web'    => 0, 'mail' => 0,
                    'ssl'    => 0, 'dns'  => 0,
                    'quota_used' => 0, 'quota_total' => 0,
                    'bandwidth_used' => 0, 'bandwidth_total' => 0,
                    'status' => ($status && $status =~ /disabled/i) ? 'disabled' : 'active',
                };
            }
        };
    }

    return \@domains;
}

# ---------------------------------------------------------------------------
# ovmd_service_status() - Check status of common services
# ---------------------------------------------------------------------------
sub ovmd_service_status
{
    my @services = (
        { 'name' => 'Apache/Nginx', 'check' => 'httpd',  'alt' => 'nginx',  'port' => 80  },
        { 'name' => 'Postfix',       'check' => 'postfix', 'alt' => undef,   'port' => 25  },
        { 'name' => 'Dovecot',       'check' => 'dovecot', 'alt' => undef,   'port' => 993 },
        { 'name' => 'MySQL/PG',      'check' => 'mysqld',  'alt' => 'postgresql', 'port' => 3306 },
        { 'name' => 'Named/BIND',    'check' => 'named',   'alt' => 'bind9', 'port' => 53  },
        { 'name' => 'SSHD',          'check' => 'sshd',    'alt' => undef,   'port' => 22  },
        { 'name' => 'Firewall',      'check' => 'firewalld','alt' => 'ufw',  'port' => 0   },
    );

    my @result;
    for my $svc (@services) {
        my $running = ovmd_check_service($svc->{'check'}, $svc->{'alt'});
        push @result, {
            'name'   => $svc->{'name'},
            'status' => $running ? 'running' : 'stopped',
            'port'   => $svc->{'port'},
        };
    }
    return \@result;
}

# ---------------------------------------------------------------------------
# ovmd_check_service() - Check if a service is running
# ---------------------------------------------------------------------------
sub ovmd_check_service
{
    my ($primary, $alt) = @_;

    # Try systemctl
    for my $name ($primary, ($alt ? $alt : ())) {
        my $out = `systemctl is-active $name 2>/dev/null`;
        chomp($out);
        return 1 if $out eq 'active';
    }

    # Try pgrep as fallback
    for my $name ($primary, ($alt ? $alt : ())) {
        my $pid = `pgrep -x $name 2>/dev/null`;
        return 1 if $pid && $pid =~ /^\d+/;
    }

    return 0;
}

# ---------------------------------------------------------------------------
# ovmd_recent_events($limit) - Get last N events from logs
# ---------------------------------------------------------------------------
sub ovmd_recent_events
{
    my ($limit) = @_;
    $limit ||= 20;
    my @events;

    # Try Webmin actions log
    my $webmin_var = $ENV{'WEBMIN_VAR'} || '/var/webmin';
    my $logfile = "$webmin_var/webmin.log";

    if (!-r $logfile) {
        # Try common alternate locations
        for my $alt (
            '/var/log/webmin/webmin.log',
            '/usr/local/webmin/var/webmin.log',
            '/opt/webmin/var/webmin.log',
        ) {
            if (-r $alt) {
                $logfile = $alt;
                last;
            }
        }
    }

    if (-r $logfile) {
        my $cmd = "tail -n $limit " . quotemeta($logfile) . " 2>/dev/null";
        my $out = `$cmd`;
        for my $line (split(/\n/, $out)) {
            chomp($line);
            # webmin.log format: timestamp user action object module ip
            my @f = split(/\s+/, $line, 6);
            next if scalar(@f) < 3;
            push @events, {
                'time'   => "$f[0] $f[1]",
                'user'   => $f[2] || '',
                'action' => $f[3] || '',
                'object' => $f[4] || '',
                'detail' => $f[5] || '',
            };
        }
    }

    # If no events found, try /var/log/auth.log or secure
    if (scalar(@events) == 0) {
        for my $alog ('/var/log/auth.log', '/var/log/secure') {
            if (-r $alog) {
                my $out = `tail -n $limit $alog 2>/dev/null`;
                for my $line (split(/\n/, $out)) {
                    chomp($line);
                    push @events, {
                        'time'   => substr($line, 0, 15),
                        'user'   => '',
                        'action' => 'auth',
                        'object' => '',
                        'detail' => substr($line, 16),
                    };
                }
                last;
            }
        }
    }

    return \@events;
}

# ---------------------------------------------------------------------------
# ovmd_quick_stats() - Return summary statistics
# ---------------------------------------------------------------------------
sub ovmd_quick_stats
{
    my %stats = (
        'total_domains'      => 0,
        'active_domains'     => 0,
        'disabled_domains'   => 0,
        'total_users'        => 0,
        'total_databases'    => 0,
        'ssl_expiring_soon'  => 0,
    );

    eval {
        &foreign_require("virtual-server", "virtual-server-lib.pl");
        my @doms = &list_domains();
        $stats{'total_domains'} = scalar(@doms);

        for my $d (@doms) {
            if ($d->{'disabled'}) {
                $stats{'disabled_domains'}++;
            } else {
                $stats{'active_domains'}++;
            }

            # Count users (owner + sub-users)
            $stats{'total_users'}++ if $d->{'user'};

            # Count databases
            if ($d->{'mysql'} || $d->{'postgres'}) {
                $stats{'total_databases'}++;
            }

            # SSL expiring within 30 days
            if ($d->{'ssl'} && $d->{'ssl_expiry'}) {
                my $exp = $d->{'ssl_expiry'};
                my $days_left = ($exp - time()) / 86400;
                $stats{'ssl_expiring_soon'}++ if $days_left > 0 && $days_left <= 30;
            }
        }
    };

    if ($@) {
        # Fallback: try CLI
        my $out = `virtualmin list-domains --name-only 2>/dev/null`;
        if ($out) {
            my @lines = grep { $_ ne '' } split(/\n/, $out);
            $stats{'total_domains'}  = scalar(@lines);
            $stats{'active_domains'} = scalar(@lines);
        }
    }

    return \%stats;
}

# ---------------------------------------------------------------------------
# ovmd_bandwidth_data($period) - Bandwidth data per domain
# ---------------------------------------------------------------------------
sub ovmd_bandwidth_data
{
    my ($period) = @_;
    $period ||= 'month';
    my @data;

    eval {
        &foreign_require("virtual-server", "virtual-server-lib.pl");
        my @doms = &list_domains();

        for my $d (@doms) {
            my $bw = $d->{'bw_usage'} || 0;
            push @data, {
                'domain'    => $d->{'dom'},
                'bandwidth' => $bw,
                'period'    => $period,
            };
        }
    };

    if ($@) {
        # Fallback: empty data
        push @data, {
            'domain'    => 'no data',
            'bandwidth' => 0,
            'period'    => $period,
        };
    }

    return \@data;
}

# ---------------------------------------------------------------------------
# ovmd_disk_usage_by_domain() - Disk usage per domain
# ---------------------------------------------------------------------------
sub ovmd_disk_usage_by_domain
{
    my @data;

    eval {
        &foreign_require("virtual-server", "virtual-server-lib.pl");
        my @doms = &list_domains();

        for my $d (@doms) {
            my $home = $d->{'home'} || "/home/$d->{'user'}";
            my $size = 0;

            if ($home && -d $home) {
                my $out = `du -sb \Q$home\E 2>/dev/null`;
                ($size) = split(/\s+/, $out);
                $size ||= 0;
            }

            push @data, {
                'domain' => $d->{'dom'},
                'user'   => $d->{'user'},
                'home'   => $home,
                'bytes'  => $size,
            };
        }
    };

    if ($@) {
        # Fallback: try virtualmin CLI
        my $out = `virtualmin list-domains --name-only 2>/dev/null`;
        if ($out) {
            for my $name (split(/\n/, $out)) {
                chomp($name);
                next unless $name;
                push @data, {
                    'domain' => $name,
                    'user'   => '',
                    'home'   => '',
                    'bytes'  => 0,
                };
            }
        }
    }

    return \@data;
}

# ---------------------------------------------------------------------------
# ovmd_chart_data($type, $data) - Format data for Chart.js-style output
# ---------------------------------------------------------------------------
sub ovmd_chart_data
{
    my ($type, $data) = @_;
    $type ||= 'bar';

    my @labels;
    my @values;
    my @colors;

    my @palette = (
        '#4CAF50', '#2196F3', '#FF9800', '#F44336',
        '#9C27B0', '#00BCD4', '#795548', '#607D8B',
        '#8BC34A', '#03A9F4', '#FFC107', '#E91E63',
    );

    if (ref($data) eq 'ARRAY') {
        my $i = 0;
        for my $item (@$data) {
            push @labels, $item->{'domain'} || $item->{'name'} || $item->{'mount'} || "Item $i";
            push @values, $item->{'bandwidth'} || $item->{'bytes'} || $item->{'percent'} || $item->{'value'} || 0;
            push @colors, $palette[$i % scalar(@palette)];
            $i++;
        }
    }

    return {
        'labels'   => \@labels,
        'datasets' => [{
            'label'           => ucfirst($type),
            'data'            => \@values,
            'backgroundColor' => \@colors,
            'borderColor'     => '#333',
            'borderWidth'     => 1,
        }],
    };
}

# ---------------------------------------------------------------------------
# ovmd_human_size() - Convert bytes to human-readable format
# ---------------------------------------------------------------------------
sub ovmd_human_size
{
    my ($bytes) = @_;
    $bytes ||= 0;

    if ($bytes >= 1073741824) {
        return sprintf("%.1f GB", $bytes / 1073741824);
    } elsif ($bytes >= 1048576) {
        return sprintf("%.1f MB", $bytes / 1048576);
    } elsif ($bytes >= 1024) {
        return sprintf("%.1f KB", $bytes / 1024);
    }
    return "$bytes B";
}

# ---------------------------------------------------------------------------
# ovmd_status_color() - Return color based on percentage threshold
# ---------------------------------------------------------------------------
sub ovmd_status_color
{
    my ($pct) = @_;
    $pct ||= 0;
    return '#F44336' if $pct >= 90;   # Red
    return '#FF9800' if $pct >= 70;   # Orange/Amber
    return '#4CAF50';                  # Green
}

1;
