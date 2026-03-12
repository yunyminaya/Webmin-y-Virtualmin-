#!/usr/bin/perl
# dynamic_policies.pl - Dynamic policy adaptation engine

use strict;
use warnings;
use DBI;
use JSON;
use Time::HiRes qw(gettimeofday);

# Configuration
my $db_file = "$module_root_directory/zero_trust_sessions.db";
my $learning_rate = 0.1;
my $adaptation_window = 86400;  # 24 hours

# Connect to database
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1, AutoCommit => 1 });

# Policy weights (learned parameters)
my %policy_weights = (
    'time_of_day' => 0.3,
    'location_risk' => 0.4,
    'device_trust' => 0.3,
    'behavior_score' => 0.5,
    'frequency_anomaly' => 0.2
);

sub adapt_policies {
    my ($user, $action_success, $context) = @_;

    # Collect features from context
    my $features = extract_features($user, $context);

    # Calculate current risk score
    my $current_risk = calculate_dynamic_risk($features);

    # Update weights based on outcome
    update_weights($features, $action_success, $current_risk);

    # Adjust policies if needed
    adjust_policies($user, $current_risk, $action_success);

    # Log adaptation
    log_adaptation($user, $features, $current_risk, $action_success);
}

sub extract_features {
    my ($user, $context) = @_;

    my $features = {};

    # Time-based features
    my ($sec, $min, $hour) = localtime();
    $features->{'hour'} = $hour;
    $features->{'is_business_hours'} = ($hour >= 9 && $hour <= 17) ? 1 : 0;

    # Location features
    $features->{'ip'} = $context->{'ip'};
    $features->{'country'} = get_country_from_ip($context->{'ip'});
    $features->{'is_vpn'} = detect_vpn_usage($context->{'ip'});

    # Device features
    $features->{'user_agent'} = $context->{'user_agent'};
    $features->{'device_type'} = detect_device_type($context->{'user_agent'});
    $features->{'device_fingerprint'} = $context->{'device_fingerprint'};

    # Behavioral features
    $features->{'session_count_24h'} = get_user_session_count_24h($user);
    $features->{'failed_attempts_1h'} = get_failed_attempts_1h($user);
    $features->{'unusual_location'} = is_unusual_location($user, $features->{'country'});

    return $features;
}

sub calculate_dynamic_risk {
    my ($features) = @_;

    my $risk = 0;

    # Weighted sum of features
    $risk += $policy_weights{'time_of_day'} * (1 - $features->{'is_business_hours'});
    $risk += $policy_weights{'location_risk'} * ($features->{'is_vpn'} ? 0.8 : 0.2);
    $risk += $policy_weights{'device_trust'} * (is_trusted_device($features->{'device_fingerprint'}) ? 0 : 0.6);
    $risk += $policy_weights{'behavior_score'} * ($features->{'failed_attempts_1h'} > 0 ? 0.7 : 0);
    $risk += $policy_weights{'frequency_anomaly'} * ($features->{'session_count_24h'} > 10 ? 0.5 : 0);

    return $risk > 1 ? 1 : $risk;
}

sub update_weights {
    my ($features, $success, $current_risk) = @_;

    # Simple reinforcement learning update
    my $error = $success ? (1 - $current_risk) : $current_risk;
    my $adjustment = $learning_rate * $error;

    # Update weights based on feature importance
    if ($features->{'is_business_hours'} == 0) {
        $policy_weights{'time_of_day'} += $adjustment * 0.1;
    }

    if ($features->{'is_vpn'}) {
        $policy_weights{'location_risk'} += $adjustment * 0.1;
    }

    if (!is_trusted_device($features->{'device_fingerprint'})) {
        $policy_weights{'device_trust'} += $adjustment * 0.1;
    }

    if ($features->{'failed_attempts_1h'} > 0) {
        $policy_weights{'behavior_score'} += $adjustment * 0.1;
    }

    # Keep weights in reasonable bounds
    foreach my $key (keys %policy_weights) {
        $policy_weights{$key} = 0 if $policy_weights{$key} < 0;
        $policy_weights{$key} = 1 if $policy_weights{$key} > 1;
    }

    # Save updated weights
    save_policy_weights();
}

sub adjust_policies {
    my ($user, $risk, $success) = @_;

    # If high risk and failed action, tighten policies
    if ($risk > 0.7 && !$success) {
        require '../virtualmin-gpl-master/conditional-policies-lib.pl';

        # Add temporary restrictive policy
        my $policy = {
            'enabled' => 1,
            'module' => '*',
            'action' => '*',
            'user_condition' => 'specific',
            'users' => $user,
            'risk_condition' => 'max_risk',
            'max_risk_score' => 0.5,
            'effect' => 'deny',
            'expires' => time() + 3600  # 1 hour
        };

        &add_policy($policy);
    }

    # If low risk and successful, relax policies slightly
    elsif ($risk < 0.3 && $success) {
        # Could relax some restrictions for this user
    }
}

sub log_adaptation {
    my ($user, $features, $risk, $success) = @_;

    my $sth = $dbh->prepare("INSERT INTO trust_events (timestamp, event_type, user, details, risk_score) VALUES (?, ?, ?, ?, ?)");
    my $details = encode_json({
        'features' => $features,
        'weights' => \%policy_weights,
        'outcome' => $success ? 'success' : 'failure'
    });
    $sth->execute(time(), 'policy_adaptation', $user, $details, $risk);
}

# Helper functions
sub get_country_from_ip {
    my ($ip) = @_;
    # Placeholder: integrate with GeoIP
    return 'US';
}

sub detect_vpn_usage {
    my ($ip) = @_;
    # Placeholder: check against known VPN ranges
    return 0;
}

sub detect_device_type {
    my ($ua) = @_;
    return 'mobile' if $ua =~ /Mobile|Android|iPhone/;
    return 'desktop';
}

sub get_user_session_count_24h {
    my ($user) = @_;
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM sessions WHERE user = ? AND created > ?");
    $sth->execute($user, time() - 86400);
    my ($count) = $sth->fetchrow_array();
    return $count;
}

sub get_failed_attempts_1h {
    my ($user) = @_;
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM trust_events WHERE user = ? AND event_type = 'auth_failure' AND timestamp > ?");
    $sth->execute($user, time() - 3600);
    my ($count) = $sth->fetchrow_array();
    return $count;
}

sub is_unusual_location {
    my ($user, $country) = @_;
    # Check if this country is unusual for this user
    return 0;  # Placeholder
}

sub is_trusted_device {
    my ($fingerprint) = @_;
    my $sth = $dbh->prepare("SELECT trust_level FROM device_registry WHERE device_fingerprint = ?");
    $sth->execute($fingerprint);
    my ($trust_level) = $sth->fetchrow_array();
    return ($trust_level && $trust_level eq 'trusted') ? 1 : 0;
}

sub save_policy_weights {
    my $weights_file = "$module_root_directory/policy_weights.json";
    open(my $fh, '>', $weights_file) or return;
    print $fh encode_json(\%policy_weights);
    close($fh);
}

sub load_policy_weights {
    my $weights_file = "$module_root_directory/policy_weights.json";
    if (-f $weights_file) {
        open(my $fh, '<', $weights_file) or return;
        my $json = <$fh>;
        close($fh);
        %policy_weights = %{decode_json($json)};
    }
}

# Initialize
load_policy_weights();

1;