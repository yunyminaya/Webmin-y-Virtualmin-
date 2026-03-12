#!/usr/bin/perl

# Zero-Trust Security Dashboard - Main interface
# Webmin module for Zero-Trust security management

use strict;
use warnings;
use WebminCore;
use JSON;

&init_config();
&ReadParse();

require './zero-trust-lib.pl';

&ui_print_header("Zero-Trust Security Dashboard", "", undef, undef, 0, 1);

# Load configuration
load_zero_trust_config();

# Get dashboard data
my $trust_stats = get_trust_dashboard_stats();
my $active_sessions = get_active_sessions();
my $risk_alerts = get_risk_alerts(10);

print &ui_tabs_start([
    [ 'dashboard', 'Dashboard', 1 ],
    [ 'policies', 'Policies' ],
    [ 'monitoring', 'Monitoring' ],
    [ 'encryption', 'Encryption' ],
    [ 'reports', 'Reports' ]
], 'tab', $in{'tab'} || 'dashboard');

# Dashboard tab
if (!$in{'tab'} || $in{'tab'} eq 'dashboard') {
    print &ui_tabs_start_tab('tab', 'dashboard');

    # Trust score overview
    print &ui_subheading('Trust Overview');
    print &ui_columns_start([
        'Average Trust Score',
        'Active Sessions',
        'High-Risk Sessions',
        'Policy Violations (24h)'
    ]);

    print &ui_columns_row([
        &ui_textbox('avg_trust_score', $trust_stats->{'avg_trust_score'} . '%', 10, 0, undef, 1),
        &ui_textbox('active_sessions', $trust_stats->{'active_sessions'}, 10, 0, undef, 1),
        &ui_textbox('high_risk_sessions', $trust_stats->{'high_risk_sessions'}, 10, 0, undef, 1),
        &ui_textbox('policy_violations', $trust_stats->{'policy_violations_24h'}, 10, 0, undef, 1)
    ]);

    print &ui_columns_end();

    # Trust score chart
    print &ui_subheading('Trust Score Distribution');
    print "<canvas id='trustChart' width='400' height='200'></canvas>";

    # Recent risk alerts
    print &ui_subheading('Recent Risk Alerts');
    print &ui_columns_table([
        'Time',
        'User',
        'Risk Level',
        'Description',
        'Actions'
    ], 100, \@$risk_alerts,
    [ 'timestamp', 'user', 'risk_level', 'description', 'actions' ]);

    # Active sessions with trust scores
    print &ui_subheading('Active Sessions');
    my @session_table;
    foreach my $session (@$active_sessions) {
        my $trust_score = calculate_trust_score($session->{'user'}, $session->{'id'});
        my $status_color = $trust_score > 0.8 ? 'success' :
                          $trust_score > 0.6 ? 'warning' : 'danger';
        push @session_table, [
            $session->{'user'},
            $session->{'ip'},
            "<span class='label label-$status_color'>" . sprintf("%.0f%%", $trust_score * 100) . "</span>",
            $session->{'last_activity'},
            "<a href='terminate_session.cgi?id=$session->{'id'}'>Terminate</a>"
        ];
    }

    print &ui_columns_table([
        'User',
        'IP Address',
        'Trust Score',
        'Last Activity',
        'Actions'
    ], 100, \@session_table);

    print &ui_tabs_end_tab('tab', 'dashboard');
}

# Policies tab
elsif ($in{'tab'} eq 'policies') {
    print &ui_tabs_start_tab('tab', 'policies');

    print &ui_subheading('Zero-Trust Policy Configuration');

    # Continuous Authentication
    print &ui_form_start('update_policies.cgi', 'post');
    print &ui_hidden('tab', 'policies');
    print &ui_hidden('section', 'continuous_auth');

    print &ui_table_start('Continuous Authentication', 'width=100%');
    print &ui_table_row('Enabled',
        &ui_yesno_radio('continuous_auth_enabled', $zero_trust_config{'continuous_auth'}{'enabled'}));
    print &ui_table_row('Re-authentication Interval (seconds)',
        &ui_textbox('reauth_interval', $zero_trust_config{'continuous_auth'}{'reauth_interval'}, 10));
    print &ui_table_row('MFA Required',
        &ui_yesno_radio('mfa_required', $zero_trust_config{'continuous_auth'}{'mfa_required'}));
    print &ui_table_row('Device Verification',
        &ui_yesno_radio('device_verification', $zero_trust_config{'continuous_auth'}{'device_verification'}));
    print &ui_table_end();

    # Contextual Access
    print &ui_table_start('Contextual Access Control', 'width=100%');
    print &ui_table_row('Enabled',
        &ui_yesno_radio('contextual_enabled', $zero_trust_config{'contextual_access'}{'enabled'}));
    print &ui_table_row('Location Check',
        &ui_yesno_radio('location_check', $zero_trust_config{'contextual_access'}{'location_check'}));
    print &ui_table_row('Device Check',
        &ui_yesno_radio('device_check', $zero_trust_config{'contextual_access'}{'device_check'}));
    print &ui_table_row('Behavior Analysis',
        &ui_yesno_radio('behavior_analysis', $zero_trust_config{'contextual_access'}{'behavior_analysis'}));
    print &ui_table_row('Risk Threshold',
        &ui_textbox('risk_threshold', $zero_trust_config{'contextual_access'}{'risk_threshold'}, 5));
    print &ui_table_end();

    # Microsegmentation
    print &ui_table_start('Network Microsegmentation', 'width=100%');
    print &ui_table_row('Enabled',
        &ui_yesno_radio('microseg_enabled', $zero_trust_config{'microsegmentation'}{'enabled'}));
    print &ui_table_end();

    print &ui_form_end([ [ 'update_policies', 'Update Policies' ] ]);

    print &ui_tabs_end_tab('tab', 'policies');
}

# Monitoring tab
elsif ($in{'tab'} eq 'monitoring') {
    print &ui_tabs_start_tab('tab', 'monitoring');

    print &ui_subheading('Real-time Security Monitoring');

    # Session monitoring
    print &ui_table_start('Session Activity', 'width=100%');
    print &ui_table_row('Total Active Sessions', scalar @$active_sessions);
    print &ui_table_row('Sessions Requiring Re-auth', 0);  # Placeholder
    print &ui_table_row('High-Risk Sessions', $trust_stats->{'high_risk_sessions'});
    print &ui_table_end();

    # Anomaly detection status
    print &ui_table_start('Anomaly Detection', 'width=100%');
    print &ui_table_row('Status', 'Active');
    print &ui_table_row('Anomalies Detected (24h)', 5);  # Placeholder
    print &ui_table_row('False Positives', 1);  # Placeholder
    print &ui_table_end();

    print &ui_tabs_end_tab('tab', 'monitoring');
}

# Encryption tab
elsif ($in{'tab'} eq 'encryption') {
    print &ui_tabs_start_tab('tab', 'encryption');

    print &ui_subheading('End-to-End Encryption Configuration');

    print &ui_form_start('update_encryption.cgi', 'post');
    print &ui_hidden('tab', 'encryption');

    print &ui_table_start('Encryption Settings', 'width=100%');
    print &ui_table_row('E2E Encryption Enabled',
        &ui_yesno_radio('e2e_enabled', $zero_trust_config{'encryption'}{'e2e_enabled'}));
    print &ui_table_row('TLS Version',
        &ui_select('tls_version', $zero_trust_config{'encryption'}{'tls_version'},
            [ [ '1.2', 'TLS 1.2' ], [ '1.3', 'TLS 1.3' ] ]));
    print &ui_table_row('Certificate Validation',
        &ui_yesno_radio('cert_validation', $zero_trust_config{'encryption'}{'cert_validation'}));
    print &ui_table_end();

    print &ui_form_end([ [ 'update_encryption', 'Update Encryption Settings' ] ]);

    print &ui_tabs_end_tab('tab', 'encryption');
}

# Reports tab
elsif ($in{'tab'} eq 'reports') {
    print &ui_tabs_start_tab('tab', 'reports');

    print &ui_subheading('Zero-Trust Security Reports');

    print &ui_form_start('generate_report.cgi', 'post');
    print &ui_hidden('tab', 'reports');

    print &ui_table_start('Generate Report', 'width=100%');
    print &ui_table_row('Report Type',
        &ui_select('report_type', undef, [
            [ 'trust_score', 'Trust Score Analysis' ],
            [ 'access_patterns', 'Access Patterns Report' ],
            [ 'risk_assessment', 'Risk Assessment Report' ],
            [ 'compliance', 'Zero-Trust Compliance Report' ]
        ]));
    print &ui_table_row('Time Period',
        &ui_select('time_period', '24h', [
            [ '1h', 'Last Hour' ],
            [ '24h', 'Last 24 Hours' ],
            [ '7d', 'Last 7 Days' ],
            [ '30d', 'Last 30 Days' ]
        ]));
    print &ui_table_row('Format',
        &ui_select('format', 'html', [
            [ 'html', 'HTML' ],
            [ 'pdf', 'PDF' ],
            [ 'json', 'JSON' ]
        ]));
    print &ui_table_end();

    print &ui_form_end([ [ 'generate', 'Generate Report' ] ]);

    print &ui_tabs_end_tab('tab', 'reports');
}

print &ui_tabs_end();

# JavaScript for charts
print <<EOF;
<script>
var ctx = document.getElementById('trustChart');
if (ctx) {
    ctx = ctx.getContext('2d');
    var chart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['High Trust', 'Medium Trust', 'Low Trust'],
            datasets: [{
                data: [65, 25, 10],
                backgroundColor: [
                    'rgba(75, 192, 192, 0.5)',
                    'rgba(255, 206, 86, 0.5)',
                    'rgba(255, 99, 132, 0.5)'
                ]
            }]
        },
        options: { responsive: true }
    });
}
</script>
EOF

&ui_print_footer('/', 'Webmin index');

# Helper functions
sub get_trust_dashboard_stats {
    return {
        'avg_trust_score' => 85,
        'active_sessions' => 12,
        'high_risk_sessions' => 2,
        'policy_violations_24h' => 3
    };
}

sub get_active_sessions {
    # Placeholder: return mock session data
    return [
        {
            'id' => 'sess_001',
            'user' => 'admin',
            'ip' => '192.168.1.100',
            'last_activity' => '2 minutes ago'
        },
        {
            'id' => 'sess_002',
            'user' => 'user1',
            'ip' => '10.0.0.50',
            'last_activity' => '5 minutes ago'
        }
    ];
}

sub get_risk_alerts {
    my ($limit) = @_;
    # Placeholder: return mock alerts
    return [
        {
            'timestamp' => '2025-09-30 08:45:00',
            'user' => 'user1',
            'risk_level' => 'High',
            'description' => 'Access from unusual location',
            'actions' => '<a href="view_alert.cgi?id=1">View</a>'
        }
    ];
}