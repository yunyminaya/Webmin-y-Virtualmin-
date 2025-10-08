#!/bin/bash

# SIEM Log Collector
# Collects and normalizes logs from multiple sources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/siem_events.db"
CONFIG_FILE="$SCRIPT_DIR/siem_config.conf"

# Default configuration
LOG_SOURCES=(
    "/var/log/syslog"
    "/var/log/auth.log"
    "/var/log/apache2/access.log"
    "/var/log/apache2/error.log"
    "/var/log/nginx/access.log"
    "/var/log/nginx/error.log"
    "/var/log/mysql/error.log"
    "/var/log/mail.log"
    "/usr/libexec/webmin/miniserv.log"
    "/var/webmin/virtualmin.log"
)

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Function to normalize and insert event
insert_event() {
    local source="$1"
    local event_type="$2"
    local severity="$3"
    local message="$4"
    local raw_log="$5"
    local ip_address="$6"
    local user_agent="$7"
    local session_id="$8"

    # Escape single quotes for SQL
    message=$(echo "$message" | sed "s/'/''/g")
    raw_log=$(echo "$raw_log" | sed "s/'/''/g")
    user_agent=$(echo "${user_agent:-}" | sed "s/'/''/g")

    sqlite3 "$DB_FILE" "INSERT INTO events (source, event_type, severity, message, raw_log, ip_address, user_agent, session_id) VALUES ('$source', '$event_type', '$severity', '$message', '$raw_log', '$ip_address', '$user_agent', '$session_id');"
}

# Function to parse syslog/auth logs
parse_syslog() {
    local logfile="$1"
    local source="$2"

    if [ ! -f "$logfile" ]; then
        return
    fi

    # Get last processed position
    local position_file="$SCRIPT_DIR/.${source}_position"
    local last_pos=0
    if [ -f "$position_file" ]; then
        last_pos=$(cat "$position_file")
    fi

    local current_size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)

    if [ "$current_size" -lt "$last_pos" ]; then
        # Log rotated, start from beginning
        last_pos=0
    fi

    # Read new lines
    tail -c +$((last_pos + 1)) "$logfile" 2>/dev/null | while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi

        # Parse common patterns
        if echo "$line" | grep -q "Failed password\|authentication failure\|Invalid user"; then
            event_type="failed_login"
            severity="medium"
            ip_address=$(echo "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -1)
        elif echo "$line" | grep -q "Accepted password\|session opened"; then
            event_type="successful_login"
            severity="low"
            ip_address=$(echo "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | head -1)
        elif echo "$line" | grep -q "sudo\|su\["; then
            event_type="privilege_escalation"
            severity="medium"
        elif echo "$line" | grep -q "CRON\|anacron"; then
            event_type="scheduled_task"
            severity="low"
        else
            event_type="system_event"
            severity="info"
        fi

        insert_event "$source" "$event_type" "$severity" "$(echo "$line" | cut -d' ' -f6-)" "$line" "$ip_address"
    done

    # Update position
    echo "$current_size" > "$position_file"
}

# Function to parse web server logs
parse_web_log() {
    local logfile="$1"
    local source="$2"

    if [ ! -f "$logfile" ]; then
        return
    fi

    local position_file="$SCRIPT_DIR/.${source}_position"
    local last_pos=0
    if [ -f "$position_file" ]; then
        last_pos=$(cat "$position_file")
    fi

    local current_size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)

    if [ "$current_size" -lt "$last_pos" ]; then
        last_pos=0
    fi

    tail -c +$((last_pos + 1)) "$logfile" 2>/dev/null | while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi

        # Parse Apache/Nginx common log format
        # Assume format: IP - - [timestamp] "method path protocol" status size "referer" "user_agent"
        ip_address=$(echo "$line" | awk '{print $1}')
        timestamp=$(echo "$line" | awk '{print $4 $5}' | sed 's/\[//' | sed 's/\]//')
        request=$(echo "$line" | awk '{print $6 $7 $8}' | sed 's/"//g')
        status=$(echo "$line" | awk '{print $9}')
        size=$(echo "$line" | awk '{print $10}')
        referer=$(echo "$line" | awk '{print $11}' | sed 's/"//g')
        user_agent=$(echo "$line" | cut -d'"' -f6)

        if [ "$status" -ge 400 ]; then
            event_type="http_error"
            severity="medium"
        elif echo "$request" | grep -q "\.php\|\.asp\|\.jsp"; then
            event_type="web_app_access"
            severity="low"
        else
            event_type="web_access"
            severity="low"
        fi

        message="HTTP $status: $request from $ip_address"
        insert_event "$source" "$event_type" "$severity" "$message" "$line" "$ip_address" "$user_agent"
    done

    echo "$current_size" > "$position_file"
}

# Function to parse Webmin/Virtualmin logs
parse_webmin_log() {
    local logfile="$1"
    local source="$2"

    if [ ! -f "$logfile" ]; then
        return
    fi

    local position_file="$SCRIPT_DIR/.${source}_position"
    local last_pos=0
    if [ -f "$position_file" ]; then
        last_pos=$(cat "$position_file")
    fi

    local current_size=$(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null || echo 0)

    if [ "$current_size" -lt "$last_pos" ]; then
        last_pos=0
    fi

    tail -c +$((last_pos + 1)) "$logfile" 2>/dev/null | while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi

        if echo "$line" | grep -q "LOGIN\|LOGOUT"; then
            event_type="webmin_auth"
            severity="low"
        elif echo "$line" | grep -q "ERROR\|FAILED"; then
            event_type="webmin_error"
            severity="medium"
        else
            event_type="webmin_action"
            severity="info"
        fi

        insert_event "$source" "$event_type" "$severity" "$line" "$line"
    done

    echo "$current_size" > "$position_file"
}

# Function to collect firewall logs (integrate with intelligent-firewall)
collect_firewall_logs() {
    # Check if intelligent-firewall is available
    if [ -d "../intelligent-firewall" ]; then
        # Get blocked IPs and suspicious activities
        sqlite3 "../intelligent-firewall/firewall.db" "SELECT ip, reason, timestamp FROM blocked_ips WHERE timestamp > datetime('now', '-5 minutes');" 2>/dev/null | while IFS='|' read -r ip reason timestamp; do
            insert_event "firewall" "block" "high" "Blocked IP: $ip - $reason" "Firewall block: $ip|$reason|$timestamp" "$ip"
        done
    fi
}

# Function to collect IDS logs
collect_ids_logs() {
    # Check for IDS logs (assuming Snort or similar)
    for logfile in /var/log/snort/alert /var/log/suricata/eve.json; do
        if [ -f "$logfile" ]; then
            parse_syslog "$logfile" "ids"
        fi
    done
}

# Main collection function
main() {
    echo "$(date): Starting log collection..."

    # Initialize database if not exists
    if [ ! -f "$DB_FILE" ]; then
        echo "Database not found, initializing..."
        bash "$SCRIPT_DIR/init_siem_db.sh"
    fi

    # Collect from each source
    for logfile in "${LOG_SOURCES[@]}"; do
        basename=$(basename "$logfile" | sed 's/\./_/g')
        case "$basename" in
            syslog|auth_log|mail_log)
                parse_syslog "$logfile" "$basename"
                ;;
            access_log|error_log)
                if echo "$logfile" | grep -q "apache"; then
                    parse_web_log "$logfile" "apache_$basename"
                elif echo "$logfile" | grep -q "nginx"; then
                    parse_web_log "$logfile" "nginx_$basename"
                fi
                ;;
            miniserv_log)
                parse_webmin_log "$logfile" "webmin"
                ;;
            virtualmin_log)
                parse_webmin_log "$logfile" "virtualmin"
                ;;
            *)
                parse_syslog "$logfile" "$basename"
                ;;
        esac
    done

    # Collect firewall and IDS logs
    collect_firewall_logs
    collect_ids_logs

    echo "$(date): Log collection completed."
}

# Run main function
main

# Integrate with blockchain
if [ -f "$SCRIPT_DIR/integrate_blockchain.sh" ]; then
    bash "$SCRIPT_DIR/integrate_blockchain.sh"
fi