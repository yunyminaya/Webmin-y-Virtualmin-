#!/bin/bash

# SIEM Correlation Engine
# Processes events and applies correlation rules

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/siem_events.db"

# Function to check threshold rules
check_threshold_rule() {
    local rule_id="$1"
    local conditions="$2"
    local time_window="$3"
    local threshold="$4"

    # Parse conditions
    local source=$(echo "$conditions" | jq -r '.source // empty' 2>/dev/null || echo "")
    local event_type=$(echo "$conditions" | jq -r '.event_type // empty' 2>/dev/null || echo "")

    # Build query
    local query="SELECT COUNT(*) FROM events WHERE processed = 0"
    if [ -n "$source" ]; then
        query="$query AND source = '$source'"
    fi
    if [ -n "$event_type" ]; then
        query="$query AND event_type = '$event_type'"
    fi
    query="$query AND timestamp > datetime('now', '-$time_window seconds')"

    local count=$(sqlite3 "$DB_FILE" "$query")

    if [ "$count" -ge "$threshold" ]; then
        return 0  # Threshold exceeded
    else
        return 1  # Not exceeded
    fi
}

# Function to check pattern rules
check_pattern_rule() {
    local rule_id="$1"
    local conditions="$2"

    local regex=$(echo "$conditions" | jq -r '.message.regex // empty' 2>/dev/null || echo "")

    if [ -n "$regex" ]; then
        local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE processed = 0 AND message REGEXP '$regex'")
        if [ "$count" -gt 0 ]; then
            return 0
        fi
    fi

    return 1
}

# Function to check sequence rules (simplified)
check_sequence_rule() {
    local rule_id="$1"
    local conditions="$2"

    # For now, just check if multiple events of same type in short time
    # Could be enhanced with more complex sequence matching
    local event_types=$(echo "$conditions" | jq -r '.sequence[] // empty' 2>/dev/null || echo "")
    if [ -n "$event_types" ]; then
        local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE processed = 0 AND event_type IN ($event_types) AND timestamp > datetime('now', '-300 seconds')")
        if [ "$count" -ge 2 ]; then
            return 0
        fi
    fi

    return 1
}

# Function to create alert
create_alert() {
    local rule_id="$1"
    local severity="$2"
    local title="$3"
    local description="$4"
    local event_ids="$5"

    sqlite3 "$DB_FILE" "INSERT INTO alerts (rule_id, severity, title, description, event_ids) VALUES ($rule_id, '$severity', '$title', '$description', '$event_ids');"

    echo "Alert created: $title"
}

# Function to get unprocessed events for correlation
get_correlation_events() {
    local rule_id="$1"
    local time_window="$2"

    sqlite3 "$DB_FILE" "SELECT id FROM events WHERE processed = 0 AND timestamp > datetime('now', '-$time_window seconds')" | tr '\n' ','
}

# Main correlation function
run_correlation() {
    echo "$(date): Running correlation engine..."

    # Get all enabled rules
    sqlite3 "$DB_FILE" "SELECT id, name, rule_type, conditions, actions FROM correlation_rules WHERE enabled = 1 ORDER BY priority DESC;" | while IFS='|' read -r rule_id name rule_type conditions actions; do

        echo "Processing rule: $name ($rule_type)"

        local triggered=0
        local event_ids=""

        case "$rule_type" in
            "threshold")
                local threshold=$(echo "$conditions" | jq -r '.threshold // 0' 2>/dev/null || echo 0)
                local time_window=$(echo "$conditions" | jq -r '.time_window // 300' 2>/dev/null || echo 300)
                if check_threshold_rule "$rule_id" "$conditions" "$time_window" "$threshold"; then
                    triggered=1
                    event_ids=$(get_correlation_events "$rule_id" "$time_window")
                fi
                ;;
            "pattern")
                if check_pattern_rule "$rule_id" "$conditions"; then
                    triggered=1
                    event_ids=$(sqlite3 "$DB_FILE" "SELECT id FROM events WHERE processed = 0 AND message REGEXP '$(echo "$conditions" | jq -r '.message.regex // empty' 2>/dev/null || echo "")'" | tr '\n' ',')
                fi
                ;;
            "sequence")
                if check_sequence_rule "$rule_id" "$conditions"; then
                    triggered=1
                    event_ids=$(get_correlation_events "$rule_id" "300")
                fi
                ;;
        esac

        if [ "$triggered" -eq 1 ]; then
            # Parse actions
            local severity=$(echo "$actions" | jq -r '.severity // "medium"' 2>/dev/null || echo "medium")
            local alert_title=$(echo "$actions" | jq -r '.alert // "Security Alert"' 2>/dev/null || echo "Security Alert")
            local description="$name triggered by correlated events"

            # Remove trailing comma from event_ids
            event_ids=$(echo "$event_ids" | sed 's/,$//')

            create_alert "$rule_id" "$severity" "$alert_title" "$description" "[$event_ids]"

            # Mark events as processed
            if [ -n "$event_ids" ]; then
                sqlite3 "$DB_FILE" "UPDATE events SET processed = 1 WHERE id IN ($event_ids);"
            fi

            # Check for escalation actions
            local block_ip=$(echo "$actions" | jq -r '.block_ip // false' 2>/dev/null || echo "false")
            if [ "$block_ip" = "true" ]; then
                # Get IPs from events
                local ips=$(sqlite3 "$DB_FILE" "SELECT DISTINCT ip_address FROM events WHERE id IN ($event_ids) AND ip_address IS NOT NULL AND ip_address != '';")
                for ip in $ips; do
                    echo "Blocking IP: $ip"
                    # Integrate with firewall
                    if [ -d "../intelligent-firewall" ]; then
                        sqlite3 "../intelligent-firewall/firewall.db" "INSERT OR REPLACE INTO blocked_ips (ip, reason, timestamp) VALUES ('$ip', 'SIEM correlation rule: $name', datetime('now'));" 2>/dev/null
                    fi
                done
            fi
        fi
    done

    echo "$(date): Correlation engine completed."
}

# Run ML anomaly detection if available
run_ml_detection() {
    if [ -f "$SCRIPT_DIR/ml_anomaly_detector.py" ] && command -v python3 &> /dev/null; then
        echo "Running ML anomaly detection..."
        python3 "$SCRIPT_DIR/ml_anomaly_detector.py"
    fi
}

# Main function
main() {
    run_correlation
    run_ml_detection
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi