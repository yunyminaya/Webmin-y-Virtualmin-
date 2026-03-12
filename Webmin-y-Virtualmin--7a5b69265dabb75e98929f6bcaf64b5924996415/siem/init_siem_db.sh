#!/bin/bash

# SIEM Database Initialization Script
# Creates SQLite database for SIEM events, rules, alerts, and compliance

DB_FILE="siem_events.db"

# Check if sqlite3 is available
if ! command -v sqlite3 &> /dev/null; then
    echo "sqlite3 is required but not installed. Please install sqlite3."
    exit 1
fi

# Create database and tables
sqlite3 "$DB_FILE" << 'EOF'
-- Events table for storing security events
CREATE TABLE IF NOT EXISTS events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50),
    event_type VARCHAR(50),
    severity VARCHAR(20),
    message TEXT,
    raw_log TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    session_id VARCHAR(100),
    correlation_id VARCHAR(100),
    tags TEXT,
    processed BOOLEAN DEFAULT 0
);

-- Correlation rules table
CREATE TABLE IF NOT EXISTS correlation_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100),
    description TEXT,
    rule_type VARCHAR(20), -- 'pattern', 'threshold', 'sequence'
    conditions TEXT, -- JSON conditions
    actions TEXT, -- JSON actions
    enabled BOOLEAN DEFAULT 1,
    priority INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Alerts table
CREATE TABLE IF NOT EXISTS alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    rule_id INTEGER,
    event_ids TEXT, -- JSON array of event IDs
    severity VARCHAR(20),
    title VARCHAR(200),
    description TEXT,
    status VARCHAR(20) DEFAULT 'new', -- 'new', 'acknowledged', 'resolved'
    assigned_to VARCHAR(100),
    escalated BOOLEAN DEFAULT 0,
    escalation_level INTEGER DEFAULT 0,
    FOREIGN KEY (rule_id) REFERENCES correlation_rules(id)
);

-- ML models table for anomaly detection
CREATE TABLE IF NOT EXISTS ml_models (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100),
    model_type VARCHAR(50),
    model_data BLOB,
    training_data TEXT,
    accuracy REAL,
    last_trained DATETIME,
    active BOOLEAN DEFAULT 0
);

-- Compliance checks table
CREATE TABLE IF NOT EXISTS compliance_checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    standard VARCHAR(50), -- 'PCI-DSS', 'GDPR', 'HIPAA'
    requirement VARCHAR(100),
    check_query TEXT,
    last_checked DATETIME,
    status VARCHAR(20), -- 'pass', 'fail', 'warning'
    details TEXT
);

-- Reports table
CREATE TABLE IF NOT EXISTS reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_type VARCHAR(50),
    period_start DATETIME,
    period_end DATETIME,
    generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    content TEXT,
    format VARCHAR(20) -- 'html', 'pdf', 'json'
);

-- Forensic timeline table
CREATE TABLE IF NOT EXISTS forensic_timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_id INTEGER,
    timestamp DATETIME,
    action VARCHAR(100),
    details TEXT,
    FOREIGN KEY (event_id) REFERENCES events(id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);
CREATE INDEX IF NOT EXISTS idx_events_source ON events(source);
CREATE INDEX IF NOT EXISTS idx_events_severity ON events(severity);
CREATE INDEX IF NOT EXISTS idx_events_processed ON events(processed);
CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status);
CREATE INDEX IF NOT EXISTS idx_alerts_timestamp ON alerts(timestamp);

-- Insert default correlation rules
INSERT OR IGNORE INTO correlation_rules (name, description, rule_type, conditions, actions, priority) VALUES
('Failed Login Attempts', 'Multiple failed login attempts from same IP', 'threshold',
 '{"source":"auth","event_type":"failed_login","threshold":5,"time_window":300}',
 '{"alert":"Multiple failed login attempts","severity":"medium","escalate_after":10}',
 2),

('Brute Force Attack', 'High number of failed authentications', 'threshold',
 '{"event_type":"failed_login","threshold":20,"time_window":600}',
 '{"alert":"Potential brute force attack","severity":"high","block_ip":true}',
 1),

('Suspicious File Access', 'Access to sensitive files', 'pattern',
 '{"message":{"regex":"access.*(/etc/passwd|/etc/shadow|config\.php)"}}',
 '{"alert":"Suspicious file access","severity":"high"}',
 1),

('DDoS Indicators', 'High traffic from single IP', 'threshold',
 '{"source":"firewall","event_type":"connection","threshold":1000,"time_window":60}',
 '{"alert":"Potential DDoS attack","severity":"critical","block_ip":true}',
 1);

-- Insert default compliance checks
INSERT OR IGNORE INTO compliance_checks (standard, requirement, check_query, status) VALUES
('PCI-DSS', 'Log all access to cardholder data', 'SELECT COUNT(*) FROM events WHERE message LIKE "%card%" AND timestamp > datetime("now", "-30 days")', 'unknown'),
('GDPR', 'Data breach notification within 72 hours', 'SELECT COUNT(*) FROM alerts WHERE severity="critical" AND timestamp > datetime("now", "-72 hours")', 'unknown'),
('HIPAA', 'Audit logs for PHI access', 'SELECT COUNT(*) FROM events WHERE tags LIKE "%PHI%" AND timestamp > datetime("now", "-1 year")', 'unknown');

EOF

echo "SIEM database initialized successfully at $DB_FILE"

# Set permissions
chmod 600 "$DB_FILE"

echo "Database permissions set to 600"