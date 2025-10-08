# conditional-policies-lib.pl
# Conditional access policies for RBAC

use strict;
use warnings;

our %policies_config;

# Load policies config
sub load_policies_config {
    my $config_file = "$config_directory/conditional_policies.config";
    if (-f $config_file) {
        %policies_config = &read_file_cached($config_file, \%policies_config);
    } else {
        %policies_config = (
            policies => []
        );
        &write_file($config_file, \%policies_config);
    }
}

# Check conditional policies
sub check_conditional_policies {
    my ($user, $module, $action) = @_;
    load_policies_config() unless %policies_config;

    foreach my $policy (@{$policies_config{'policies'}}) {
        next unless $policy->{'enabled'};
        next unless $policy->{'module'} eq $module || $policy->{'module'} eq '*';
        next unless $policy->{'action'} eq $action || $policy->{'action'} eq '*';

        # Check user condition
        if ($policy->{'user_condition'} eq 'specific' && $policy->{'users'} !~ /\b$user\b/) {
            next;
        }
        if ($policy->{'user_condition'} eq 'role') {
            my $user_role = &get_user_role($user);
            next unless $user_role eq $policy->{'role'};
        }

        # Check time condition
        if ($policy->{'time_condition'} eq 'range') {
            my ($hour) = (localtime())[2];
            next unless $hour >= $policy->{'start_hour'} && $hour <= $policy->{'end_hour'};
        }

        # Check IP condition
        if ($policy->{'ip_condition'} eq 'range') {
            my $client_ip = $ENV{'REMOTE_ADDR'};
            next unless &ip_in_range($client_ip, $policy->{'ip_start'}, $policy->{'ip_end'});
        }

        # Zero-Trust: Location-based access
        if ($policy->{'location_condition'} eq 'country') {
            my $client_country = &get_client_country($ENV{'REMOTE_ADDR'});
            next unless $client_country eq $policy->{'allowed_country'};
        }

        # Zero-Trust: Device type restrictions
        if ($policy->{'device_condition'} eq 'type') {
            my $device_type = &detect_device_type($ENV{'HTTP_USER_AGENT'});
            next unless grep { $_ eq $device_type } @{$policy->{'allowed_device_types'}};
        }

        # Zero-Trust: Risk-based access
        if ($policy->{'risk_condition'} eq 'max_risk') {
            my $current_risk = &calculate_access_risk($user, $ENV{'REMOTE_ADDR'}, $ENV{'HTTP_USER_AGENT'});
            next unless $current_risk <= $policy->{'max_risk_score'};
        }

        # Zero-Trust: Behavioral analysis
        if ($policy->{'behavior_condition'} eq 'normal_pattern') {
            my $is_normal = &check_behavior_pattern($user, $module, $action);
            next unless $is_normal;
        }

        # Policy matches, check if allow or deny
        return $policy->{'effect'} eq 'allow' ? 1 : 0;
    }

    return undef;  # No policy matched
}

# Add policy
sub add_policy {
    my ($policy) = @_;
    load_policies_config() unless %policies_config;
    push @{$policies_config{'policies'}}, $policy;
    &write_file("$config_directory/conditional_policies.config", \%policies_config);
}

# IP in range check
sub ip_in_range {
    my ($ip, $start, $end) = @_;
    my @ip_parts = split(/\./, $ip);
    my @start_parts = split(/\./, $start);
    my @end_parts = split(/\./, $end);

    for (my $i = 0; $i < 4; $i++) {
        return 0 if $ip_parts[$i] < $start_parts[$i];
        return 0 if $ip_parts[$i] > $end_parts[$i];
        return 1 if $ip_parts[$i] > $start_parts[$i] || $ip_parts[$i] < $end_parts[$i];
    }
    return 1;
}

# Zero-Trust: Get client country from IP
sub get_client_country {
    my ($ip) = @_;
    # Placeholder: integrate with GeoIP database
    # For demo, return 'US' for local IPs
    return 'US' if $ip =~ /^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\./;
    return 'Unknown';
}

# Zero-Trust: Detect device type from User-Agent
sub detect_device_type {
    my ($user_agent) = @_;
    return 'mobile' if $user_agent =~ /Mobile|iPhone|Android/;
    return 'tablet' if $user_agent =~ /Tablet|iPad/;
    return 'desktop';
}

# Zero-Trust: Calculate access risk score
sub calculate_access_risk {
    my ($user, $ip, $user_agent) = @_;
    my $risk = 0;

    # Risk factors
    $risk += 0.3 if &get_client_country($ip) ne 'US';  # Geographic risk
    $risk += 0.2 if &detect_device_type($user_agent) eq 'mobile';  # Device type risk
    $risk += 0.1;  # Base risk

    return $risk;
}

# Zero-Trust: Check behavior pattern
sub check_behavior_pattern {
    my ($user, $module, $action) = @_;
    # Placeholder: analyze user behavior patterns
    # Check if access is within normal hours, frequency, etc.
    my ($hour) = (localtime())[2];
    return 1 if $hour >= 8 && $hour <= 18;  # Normal business hours
    return 0;  # Outside normal hours
}

1;