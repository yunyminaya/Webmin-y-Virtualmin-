#!/usr/bin/perl
# continuous_monitor.pl - Continuous monitoring daemon for Zero-Trust

use strict;
use warnings;
use DBI;
use JSON;
use Time::HiRes qw(sleep);

# Configuration
my $session_timeout = 3600;  # 1 hour
my $check_interval = 60;     # Check every minute
my $db_file = "$module_root_directory/zero_trust_sessions.db";

# Connect to database
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1, AutoCommit => 1 });

print "Zero-Trust Continuous Monitor started...\n";

while (1) {
    eval {
        # Get active sessions
        my $sth = $dbh->prepare("SELECT * FROM sessions WHERE last_activity > ?");
        $sth->execute(time() - $session_timeout);

        while (my $session = $sth->fetchrow_hashref()) {
            # Perform continuous verification
            my $trust_score = check_session_trust($session);

            # Update trust score
            my $update_sth = $dbh->prepare("UPDATE sessions SET trust_score = ? WHERE id = ?");
            $update_sth->execute($trust_score, $session->{'id'});

            # Check for anomalies
            if ($trust_score < 0.5) {
                log_anomaly($session, 'low_trust_score', "Trust score dropped to $trust_score");
            }

            # Check for session hijacking indicators
            if (detect_session_anomaly($session)) {
                log_anomaly($session, 'session_anomaly', 'Potential session hijacking detected');
                # Terminate suspicious session
                terminate_session($session->{'id'});
            }
        }

        # Clean up expired sessions
        $dbh->do("DELETE FROM sessions WHERE last_activity < ?", undef, time() - ($session_timeout * 2));

        # Update device registry
        update_device_registry();
    };

    if ($@) {
        warn "Error in continuous monitor: $@";
    }

    sleep($check_interval);
}

sub check_session_trust {
    my ($session) = @_;

    require './zero-trust-lib.pl';
    return calculate_trust_score($session->{'user'}, $session->{'id'});
}

sub detect_session_anomaly {
    my ($session) = @_;

    # Check for unusual access patterns
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM trust_events WHERE user = ? AND event_type = 'location_change' AND timestamp > ?");
    $sth->execute($session->{'user'}, time() - 3600);  # Last hour
    my ($location_changes) = $sth->fetchrow_array();

    return 1 if $location_changes > 3;  # Too many location changes

    # Check for device fingerprint changes
    my $device_sth = $dbh->prepare("SELECT device_fingerprint FROM sessions WHERE user = ? ORDER BY last_activity DESC LIMIT 2");
    $device_sth->execute($session->{'user'});
    my @fingerprints;
    while (my ($fp) = $device_sth->fetchrow_array()) {
        push @fingerprints, $fp;
    }

    return 1 if @fingerprints == 2 && $fingerprints[0] ne $fingerprints[1];

    return 0;
}

sub log_anomaly {
    my ($session, $type, $description) = @_;

    my $sth = $dbh->prepare("INSERT INTO trust_events (timestamp, event_type, user, details, risk_score) VALUES (?, ?, ?, ?, ?)");
    $sth->execute(time(), $type, $session->{'user'}, $description, 0.8);

    # Send alert to SIEM
    require '../siem/siem-lib.pl';
    &log_siem_event('zero_trust', $type, $session->{'user'}, $description);
}

sub terminate_session {
    my ($session_id) = @_;

    $dbh->do("DELETE FROM sessions WHERE id = ?", undef, $session_id);

    # Log termination
    my $sth = $dbh->prepare("INSERT INTO trust_events (timestamp, event_type, user, details, risk_score) VALUES (?, ?, ?, ?, ?)");
    $sth->execute(time(), 'session_terminated', 'system', "Session $session_id terminated due to security policy", 1.0);
}

sub update_device_registry {
    # Update last seen times for devices
    $dbh->do("UPDATE device_registry SET last_seen = ? WHERE device_fingerprint IN (SELECT device_fingerprint FROM sessions)", undef, time());
}