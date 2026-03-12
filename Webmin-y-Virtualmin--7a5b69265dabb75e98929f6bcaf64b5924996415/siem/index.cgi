#!/usr/bin/perl

# SIEM Dashboard - Main interface
# Webmin module for SIEM management

use strict;
use warnings;
use WebminCore;
use DBI;
use JSON;

&init_config();
&ReadParse();

my $db_file = "$module_root_directory/siem_events.db";

# Connect to database
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1, AutoCommit => 1 });

&ui_print_header("SIEM Security Dashboard", "", undef, undef, 0, 1);

# Get dashboard data
my $stats = get_dashboard_stats();
my $recent_alerts = get_recent_alerts(10);
my $events_chart = get_events_chart_data();

print &ui_tabs_start([
    [ 'dashboard', 'Dashboard', 1 ],
    [ 'alerts', 'Alerts' ],
    [ 'events', 'Events' ],
    [ 'rules', 'Correlation Rules' ],
    [ 'compliance', 'Compliance' ],
    [ 'reports', 'Reports' ],
    [ 'forensics', 'Forensics' ],
    [ 'blockchain', 'Blockchain' ]
], 'tab', $in{'tab'} || 'dashboard');

# Dashboard tab
if (!$in{'tab'} || $in{'tab'} eq 'dashboard') {
    print &ui_tabs_start_tab('tab', 'dashboard');

    # Summary cards
    print &ui_columns_start([
        'Security Events (24h)',
        'Active Alerts',
        'Critical Alerts',
        'Blocked IPs'
    ]);

    print &ui_columns_row([
        &ui_textbox('events_24h', $stats->{'events_24h'}, 10, 0, undef, 1),
        &ui_textbox('active_alerts', $stats->{'active_alerts'}, 10, 0, undef, 1),
        &ui_textbox('critical_alerts', $stats->{'critical_alerts'}, 10, 0, undef, 1),
        &ui_textbox('blocked_ips', $stats->{'blocked_ips'}, 10, 0, undef, 1)
    ]);

    print &ui_columns_end();

    # Recent alerts table
    print &ui_subheading('Recent Alerts');
    print &ui_columns_table([
        'Time',
        'Severity',
        'Title',
        'Status',
        'Actions'
    ], 100, \@$recent_alerts,
    [ 'timestamp', 'severity', 'title', 'status', 'actions' ]);

    # Events chart placeholder (would use Chart.js or similar)
    print &ui_subheading('Events by Source (Last 24h)');
    print "<canvas id='eventsChart' width='400' height='200'></canvas>";
    print "<script>
        var ctx = document.getElementById('eventsChart').getContext('2d');
        var chart = new Chart(ctx, {
            type: 'bar',
            data: " . encode_json($events_chart) . ",
            options: { responsive: true }
        });
    </script>";

    print &ui_tabs_end_tab('tab', 'dashboard');
}

# Alerts tab
elsif ($in{'tab'} eq 'alerts') {
    print &ui_tabs_start_tab('tab', 'alerts');

    # Alert management interface
    print &ui_form_start('acknowledge_alert.cgi', 'post');
    print &ui_hidden('tab', 'alerts');

    my $all_alerts = get_all_alerts();
    print &ui_subheading('All Alerts');

    my @table_data;
    foreach my $alert (@$all_alerts) {
        my $actions = '';
        if ($alert->{'status'} ne 'resolved') {
            $actions .= &ui_checkbox('acknowledge', $alert->{'id'}, undef, 'Acknowledge') . ' ';
            $actions .= &ui_checkbox('resolve', $alert->{'id'}, undef, 'Resolve');
        }
        push @table_data, [
            $alert->{'timestamp'},
            $alert->{'severity'},
            $alert->{'title'},
            $alert->{'description'},
            $alert->{'status'},
            $actions
        ];
    }

    print &ui_columns_table([
        'Time',
        'Severity',
        'Title',
        'Description',
        'Status',
        'Actions'
    ], 100, \@table_data);

    print &ui_form_end([ [ 'update', 'Update Selected' ] ]);

    print &ui_tabs_end_tab('tab', 'alerts');
}

# Events tab
elsif ($in{'tab'} eq 'events') {
    print &ui_tabs_start_tab('tab', 'events');

    # Event search and filtering
    print &ui_form_start('search_events.cgi', 'post');
    print &ui_hidden('tab', 'events');

    print &ui_table_start('Search Events', 'width=100%');
    print &ui_table_row('Source',
        &ui_select('source', undef, [
            [ '', 'All Sources' ],
            [ 'syslog', 'System Log' ],
            [ 'auth', 'Authentication' ],
            [ 'apache', 'Apache' ],
            [ 'nginx', 'Nginx' ],
            [ 'firewall', 'Firewall' ],
            [ 'ids', 'IDS' ]
        ]));
    print &ui_table_row('Event Type',
        &ui_textbox('event_type', undef, 30));
    print &ui_table_row('Severity',
        &ui_select('severity', undef, [
            [ '', 'All Severities' ],
            [ 'critical', 'Critical' ],
            [ 'high', 'High' ],
            [ 'medium', 'Medium' ],
            [ 'low', 'Low' ],
            [ 'info', 'Info' ]
        ]));
    print &ui_table_row('Time Range',
        &ui_select('time_range', '24h', [
            [ '1h', 'Last Hour' ],
            [ '24h', 'Last 24 Hours' ],
            [ '7d', 'Last 7 Days' ],
            [ '30d', 'Last 30 Days' ]
        ]));
    print &ui_table_end();

    print &ui_form_end([ [ 'search', 'Search Events' ] ]);

    print &ui_tabs_end_tab('tab', 'events');
}

# Rules tab
elsif ($in{'tab'} eq 'rules') {
    print &ui_tabs_start_tab('tab', 'rules');

    my $rules = get_correlation_rules();

    print &ui_subheading('Correlation Rules');
    print &ui_form_start('update_rules.cgi', 'post');
    print &ui_hidden('tab', 'rules');

    my @rules_table;
    foreach my $rule (@$rules) {
        push @rules_table, [
            $rule->{'name'},
            $rule->{'description'},
            $rule->{'rule_type'},
            $rule->{'enabled'} ? 'Yes' : 'No',
            &ui_checkbox('enable_rule', $rule->{'id'}, $rule->{'enabled'})
        ];
    }

    print &ui_columns_table([
        'Name',
        'Description',
        'Type',
        'Enabled',
        'Actions'
    ], 100, \@rules_table);

    print &ui_form_end([ [ 'update', 'Update Rules' ] ]);

    print &ui_tabs_end_tab('tab', 'rules');
}

# Compliance tab
elsif ($in{'tab'} eq 'compliance') {
    print &ui_tabs_start_tab('tab', 'compliance');

    my $compliance_status = get_compliance_status();

    print &ui_subheading('Compliance Status');

    foreach my $standard (keys %$compliance_status) {
        print &ui_subheading("$standard Compliance");
        print &ui_table_start("$standard Requirements", 'width=100%');

        foreach my $req (@{$compliance_status->{$standard}}) {
            my $status_color = $req->{'status'} eq 'pass' ? 'success' :
                             $req->{'status'} eq 'fail' ? 'danger' : 'warning';
            print &ui_table_row($req->{'requirement'},
                "<span class='label label-$status_color'>" . uc($req->{'status'}) . "</span>");
        }

        print &ui_table_end();
    }

    print &ui_tabs_end_tab('tab', 'compliance');
}

# Reports tab
elsif ($in{'tab'} eq 'reports') {
    print &ui_tabs_start_tab('tab', 'reports');

    print &ui_subheading('Generate Reports');
    print &ui_form_start('generate_report.cgi', 'post');
    print &ui_hidden('tab', 'reports');

    print &ui_table_start('Report Parameters', 'width=100%');
    print &ui_table_row('Report Type',
        &ui_select('report_type', undef, [
            [ 'daily', 'Daily Security Report' ],
            [ 'weekly', 'Weekly Security Report' ],
            [ 'monthly', 'Monthly Security Report' ],
            [ 'compliance', 'Compliance Report' ],
            [ 'forensic', 'Forensic Report' ]
        ]));
    print &ui_table_row('Format',
        &ui_select('format', 'html', [
            [ 'html', 'HTML' ],
            [ 'pdf', 'PDF' ],
            [ 'json', 'JSON' ]
        ]));
    print &ui_table_row('Email Report',
        &ui_yesno_radio('email_report', 0));
    print &ui_table_end();

    print &ui_form_end([ [ 'generate', 'Generate Report' ] ]);

    print &ui_tabs_end_tab('tab', 'reports');
}

# Forensics tab
elsif ($in{'tab'} eq 'forensics') {
    print &ui_tabs_start_tab('tab', 'forensics');

    print &ui_subheading('Forensic Analysis Options');
    print "<p><a href='forensic_blockchain_search.cgi' class='btn btn-primary'>Blockchain Forensic Search</a></p>";

    print &ui_subheading('SIEM Forensic Timeline Analysis');
    print &ui_form_start('forensic_search.cgi', 'post');
    print &ui_hidden('tab', 'forensics');

    print &ui_table_start('Timeline Parameters', 'width=100%');
    print &ui_table_row('IP Address',
        &ui_textbox('ip_address', undef, 20));
    print &ui_table_row('User',
        &ui_textbox('user', undef, 20));
    print &ui_table_row('Time Range',
        &ui_date_input('start_date', undef) . ' to ' . &ui_date_input('end_date', undef));
    print &ui_table_row('Event Types',
        &ui_textbox('event_types', undef, 50));
    print &ui_table_end();

    print &ui_form_end([ [ 'search', 'Generate Timeline' ] ]);

    print &ui_tabs_end_tab('tab', 'forensics');
}

# Blockchain tab
elsif ($in{'tab'} eq 'blockchain') {
    print &ui_tabs_start_tab('tab', 'blockchain');

    print &ui_subheading('Blockchain Dashboard');

    # Get blockchain stats
    my $blockchain_stats = get_blockchain_stats();

    # Summary cards
    print &ui_columns_start([
        'Total Blocks',
        'Total Logs',
        'Chain Size (KB)',
        'Pending Logs'
    ]);

    print &ui_columns_row([
        &ui_textbox('total_blocks', $blockchain_stats->{'total_blocks'} || 0, 10, 0, undef, 1),
        &ui_textbox('total_logs', $blockchain_stats->{'total_logs'} || 0, 10, 0, undef, 1),
        &ui_textbox('chain_size', sprintf("%.2f", ($blockchain_stats->{'chain_size_bytes'} || 0) / 1024), 10, 0, undef, 1),
        &ui_textbox('pending_logs', $blockchain_stats->{'pending_logs'} || 0, 10, 0, undef, 1)
    ]);

    print &ui_columns_end();

    # Chain integrity status
    my $integrity_status = $blockchain_stats->{'is_valid'} ? 'Valid' : 'Corrupted';
    my $status_color = $blockchain_stats->{'is_valid'} ? 'success' : 'danger';

    print &ui_subheading('Chain Integrity');
    print "<p><span class='label label-$status_color'>$integrity_status</span></p>";

    # Blockchain actions
    print &ui_form_start('blockchain_action.cgi', 'post');
    print &ui_hidden('tab', 'blockchain');

    print &ui_buttons_start();
    print &ui_submit('verify_integrity', 'Verify Integrity');
    print &ui_submit('mine_pending', 'Mine Pending Logs');
    print &ui_submit('view_chain', 'View Chain Details');
    print &ui_buttons_end();

    print &ui_form_end();

    # Recent blocks table
    if ($blockchain_stats->{'total_blocks'} > 0) {
        print &ui_subheading('Recent Blocks');
        my $recent_blocks = get_recent_blocks(5);
        print &ui_columns_table([
            'Block Index',
            'Timestamp',
            'Logs Count',
            'Hash (short)',
            'Actions'
        ], 100, \@$recent_blocks,
        [ 'index', 'timestamp', 'logs_count', 'hash_short', 'actions' ]);
    }

    print &ui_tabs_end_tab('tab', 'blockchain');
}

print &ui_tabs_end();

$dbh->disconnect();
&ui_print_footer('/', 'Webmin index');

# Helper functions
sub get_dashboard_stats {
    my $stats = {};

    # Events in last 24h
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM events WHERE timestamp > datetime('now', '-1 day')");
    $sth->execute();
    ($stats->{'events_24h'}) = $sth->fetchrow_array();

    # Active alerts
    $sth = $dbh->prepare("SELECT COUNT(*) FROM alerts WHERE status != 'resolved'");
    $sth->execute();
    ($stats->{'active_alerts'}) = $sth->fetchrow_array();

    # Critical alerts
    $sth = $dbh->prepare("SELECT COUNT(*) FROM alerts WHERE severity = 'critical' AND status != 'resolved'");
    $sth->execute();
    ($stats->{'critical_alerts'}) = $sth->fetchrow_array();

    # Blocked IPs (from firewall integration)
    $stats->{'blocked_ips'} = 0;
    if (-f "../intelligent-firewall/firewall.db") {
        my $fw_dbh = DBI->connect("dbi:SQLite:dbname=../intelligent-firewall/firewall.db", "", "");
        $sth = $fw_dbh->prepare("SELECT COUNT(*) FROM blocked_ips");
        $sth->execute();
        ($stats->{'blocked_ips'}) = $sth->fetchrow_array();
        $fw_dbh->disconnect();
    }

    return $stats;
}

sub get_recent_alerts {
    my ($limit) = @_;
    my $sth = $dbh->prepare("SELECT id, timestamp, severity, title, status FROM alerts ORDER BY timestamp DESC LIMIT ?");
    $sth->execute($limit);

    my @alerts;
    while (my $row = $sth->fetchrow_hashref()) {
        push @alerts, {
            'timestamp' => $row->{'timestamp'},
            'severity' => $row->{'severity'},
            'title' => $row->{'title'},
            'status' => $row->{'status'},
            'actions' => "<a href='view_alert.cgi?id=$row->{'id'}'>View</a>"
        };
    }

    return \@alerts;
}

sub get_events_chart_data {
    my $sth = $dbh->prepare("
        SELECT source, COUNT(*) as count
        FROM events
        WHERE timestamp > datetime('now', '-1 day')
        GROUP BY source
        ORDER BY count DESC
    ");
    $sth->execute();

    my @labels;
    my @data;

    while (my ($source, $count) = $sth->fetchrow_array()) {
        push @labels, $source;
        push @data, $count;
    }

    return {
        'labels' => \@labels,
        'datasets' => [{
            'label' => 'Events',
            'data' => \@data,
            'backgroundColor' => 'rgba(54, 162, 235, 0.5)',
            'borderColor' => 'rgba(54, 162, 235, 1)',
            'borderWidth' => 1
        }]
    };
}

sub get_all_alerts {
    my $sth = $dbh->prepare("SELECT * FROM alerts ORDER BY timestamp DESC");
    $sth->execute();

    my @alerts;
    while (my $row = $sth->fetchrow_hashref()) {
        push @alerts, $row;
    }

    return \@alerts;
}

sub get_correlation_rules {
    my $sth = $dbh->prepare("SELECT * FROM correlation_rules ORDER BY priority DESC");
    $sth->execute();

    my @rules;
    while (my $row = $sth->fetchrow_hashref()) {
        push @rules, $row;
    }

    return \@rules;
}

sub get_compliance_status {
    my $sth = $dbh->prepare("SELECT * FROM compliance_checks");
    $sth->execute();

    my %compliance;
    while (my $row = $sth->fetchrow_hashref()) {
        push @{$compliance{$row->{'standard'}}}, $row;
    }

    return \%compliance;
}

sub get_blockchain_stats {
    my $stats = {};

    # Try to get stats from blockchain_manager.py
    if (-f "$module_root_directory/blockchain_manager.py" && -x "/usr/bin/python3") {
        my $output = `cd $module_root_directory && python3 blockchain_manager.py stats 2>/dev/null`;
        if ($? == 0) {
            eval {
                my $json_stats = decode_json($output);
                $stats = $json_stats;
            };
        }
    }

    return $stats;
}

sub get_recent_blocks {
    my ($limit) = @_;

    my @blocks;

    # Read blockchain file and get recent blocks
    my $blockchain_file = "$module_root_directory/blockchain.json";
    if (-f $blockchain_file) {
        open my $fh, '<', $blockchain_file or return \@blocks;
        local $/;
        my $json_text = <$fh>;
        close $fh;

        eval {
            my $chain_data = decode_json($json_text);
            my $start_index = scalar(@$chain_data) - $limit;
            $start_index = 0 if $start_index < 0;

            for (my $i = $start_index; $i < scalar(@$chain_data); $i++) {
                my $block = $chain_data->[$i];
                my $logs_count = scalar(@{$block->{'logs'}});
                my $hash_short = substr($block->{'hash'}, 0, 16) . '...';

                push @blocks, {
                    'index' => $block->{'index'},
                    'timestamp' => scalar(localtime($block->{'timestamp'})),
                    'logs_count' => $logs_count,
                    'hash_short' => $hash_short,
                    'actions' => "<a href='view_block.cgi?index=$block->{'index'}'>View</a>"
                };
            }
        };
    }

    return \@blocks;
}