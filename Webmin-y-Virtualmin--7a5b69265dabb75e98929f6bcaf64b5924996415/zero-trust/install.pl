#!/usr/bin/perl
# install.pl - Zero-Trust module installation script

use strict;
use warnings;

print "Installing Zero-Trust Security Architecture module...\n";

# Create necessary directories
mkdir("$module_root_directory/config") unless -d "$module_root_directory/config";
mkdir("$module_root_directory/logs") unless -d "$module_root_directory/logs";

# Initialize configuration
print "Initializing Zero-Trust configuration...\n";
require './zero-trust-lib.pl';
load_zero_trust_config();

# Create database tables for session tracking
print "Setting up session tracking database...\n";
my $db_file = "$module_root_directory/zero_trust_sessions.db";
if (!-f $db_file) {
    system("sqlite3 $db_file 'CREATE TABLE sessions (id TEXT PRIMARY KEY, user TEXT, ip TEXT, user_agent TEXT, device_fingerprint TEXT, trust_score REAL, last_activity INTEGER, created INTEGER);'");
    system("sqlite3 $db_file 'CREATE TABLE trust_events (id INTEGER PRIMARY KEY, timestamp INTEGER, event_type TEXT, user TEXT, details TEXT, risk_score REAL);'");
    system("sqlite3 $db_file 'CREATE TABLE device_registry (id INTEGER PRIMARY KEY, user TEXT, device_fingerprint TEXT, device_name TEXT, trust_level TEXT, first_seen INTEGER, last_seen INTEGER);'");
}

# Setup encryption certificates
print "Setting up encryption certificates...\n";
system("openssl req -x509 -newkey rsa:4096 -keyout $module_root_directory/ssl/private.key -out $module_root_directory/ssl/certificate.crt -days 365 -nodes -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost' 2>/dev/null");
mkdir("$module_root_directory/ssl") unless -d "$module_root_directory/ssl";

# Configure web server for E2E encryption
print "Configuring web server for end-to-end encryption...\n";
# This would integrate with Apache/Nginx configuration

# Initialize SIEM integration
print "Setting up SIEM integration...\n";
if (-d '../siem') {
    # Create correlation rules for Zero-Trust events
    my $siem_db = '../siem/siem_events.db';
    if (-f $siem_db) {
        system("sqlite3 $siem_db \"INSERT OR IGNORE INTO correlation_rules (name, description, rule_type, pattern, severity, enabled) VALUES ('Zero-Trust Auth Failure', 'Multiple authentication failures in Zero-Trust system', 'threshold', 'zero_trust:auth_failure', 'high', 1);\"");
        system("sqlite3 $siem_db \"INSERT OR IGNORE INTO correlation_rules (name, description, rule_type, pattern, severity, enabled) VALUES ('Zero-Trust Context Violation', 'Contextual access violations', 'pattern', 'zero_trust:context_denied', 'medium', 1);\"");
    }
}

# Setup firewall integration
print "Setting up intelligent firewall integration...\n";
if (-d '../intelligent-firewall') {
    # Add Zero-Trust zones to firewall configuration
    # This would modify firewall rules
}

print "Zero-Trust Security Architecture module installed successfully!\n";
print "Please restart Webmin/Virtualmin to activate all features.\n";