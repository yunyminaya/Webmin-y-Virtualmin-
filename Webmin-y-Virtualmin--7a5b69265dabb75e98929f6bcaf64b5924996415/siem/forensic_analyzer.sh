#!/bin/bash

# SIEM Forensic Analyzer
# Provides timeline analysis and forensic investigation tools

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/siem_events.db"
TIMELINE_DIR="$SCRIPT_DIR/timelines"

mkdir -p "$TIMELINE_DIR"

# Function to generate forensic timeline
generate_timeline() {
    local ip_address="$1"
    local user="$2"
    local start_date="$3"
    local end_date="$4"
    local event_types="$5"

    local timeline_file="$TIMELINE_DIR/timeline_$(date +%Y%m%d_%H%M%S).json"

    echo "Generating forensic timeline..."

    # Build query
    local query="SELECT id, timestamp, source, event_type, severity, message, ip_address, user_agent FROM events WHERE 1=1"

    if [ -n "$ip_address" ]; then
        query="$query AND ip_address = '$ip_address'"
    fi

    if [ -n "$user" ]; then
        query="$query AND message LIKE '%$user%'"
    fi

    if [ -n "$start_date" ]; then
        query="$query AND timestamp >= '$start_date'"
    fi

    if [ -n "$end_date" ]; then
        query="$query AND timestamp <= '$end_date'"
    fi

    if [ -n "$event_types" ]; then
        # Convert comma-separated to SQL IN clause
        local types_list=$(echo "$event_types" | sed 's/,/\x27,\x27/g' | sed 's/^/\x27/' | sed 's/$/\x27/')
        query="$query AND event_type IN ($types_list)"
    fi

    query="$query ORDER BY timestamp ASC"

    # Generate JSON timeline
    echo "[" > "$timeline_file"

    local first=1
    sqlite3 "$DB_FILE" "$query;" | while IFS='|' read -r id timestamp source event_type severity message ip_address user_agent; do
        if [ "$first" -eq 0 ]; then
            echo "," >> "$timeline_file"
        fi
        first=0

        # Escape JSON strings
        message=$(echo "$message" | sed 's/"/\\"/g')
        user_agent=$(echo "${user_agent:-}" | sed 's/"/\\"/g')

        cat >> "$timeline_file" << EOF
{
  "id": $id,
  "timestamp": "$timestamp",
  "source": "$source",
  "event_type": "$event_type",
  "severity": "$severity",
  "message": "$message",
  "ip_address": "$ip_address",
  "user_agent": "$user_agent"
}
EOF
    done

    echo "]" >> "$timeline_file"

    echo "Timeline saved to $timeline_file"

    # Generate HTML visualization
    generate_timeline_html "$timeline_file"
}

# Function to generate HTML timeline visualization
generate_timeline_html() {
    local json_file="$1"
    local html_file="${json_file%.json}.html"

    cat > "$html_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>SIEM Forensic Timeline</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .timeline { position: relative; padding: 20px 0; }
        .event { margin: 10px 0; padding: 10px; border-left: 3px solid #ccc; background: #f9f9f9; }
        .event.critical { border-left-color: red; background: #ffe6e6; }
        .event.high { border-left-color: orange; background: #fff3cd; }
        .event.medium { border-left-color: blue; background: #d1ecf1; }
        .event.low { border-left-color: green; background: #d4edda; }
        .timestamp { font-weight: bold; color: #666; }
        .source { font-style: italic; }
        .details { margin-top: 5px; }
        .filter { margin-bottom: 20px; padding: 10px; background: #f0f0f0; }
    </style>
</head>
<body>
    <h1>SIEM Forensic Timeline</h1>

    <div class="filter">
        <label>Filter by severity:
            <select id="severityFilter">
                <option value="all">All</option>
                <option value="critical">Critical</option>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
                <option value="info">Info</option>
            </select>
        </label>
        <label>Filter by source:
            <input type="text" id="sourceFilter" placeholder="Enter source...">
        </label>
        <button onclick="applyFilters()">Apply Filters</button>
    </div>

    <div class="timeline" id="timeline">
EOF

    # Read JSON and generate HTML events
    local content=$(cat "$json_file")
    # Use jq if available, otherwise simple parsing
    if command -v jq &> /dev/null; then
        echo "$content" | jq -r '.[] | "<div class=\"event \(.severity)\" data-severity=\"\(.severity)\" data-source=\"\(.source)\">
            <div class=\"timestamp\">\(.timestamp)</div>
            <div class=\"source\">\(.source) - \(.event_type)</div>
            <div class=\"details\">IP: \(.ip_address // "N/A")<br>Message: \(.message)</div>
        </div>"' >> "$html_file"
    else
        # Simple parsing without jq
        echo "$content" | sed 's/\[//' | sed 's/\]//' | sed 's/},{/}\n{/g' | while read -r event; do
            local timestamp=$(echo "$event" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
            local source=$(echo "$event" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
            local event_type=$(echo "$event" | grep -o '"event_type":"[^"]*"' | cut -d'"' -f4)
            local severity=$(echo "$event" | grep -o '"severity":"[^"]*"' | cut -d'"' -f4)
            local message=$(echo "$event" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 | sed 's/\\"/"/g')
            local ip=$(echo "$event" | grep -o '"ip_address":"[^"]*"' | cut -d'"' -f4)

            cat >> "$html_file" << EOF
        <div class="event $severity" data-severity="$severity" data-source="$source">
            <div class="timestamp">$timestamp</div>
            <div class="source">$source - $event_type</div>
            <div class="details">IP: ${ip:-N/A}<br>Message: $message</div>
        </div>
EOF
        done
    fi

    cat >> "$html_file" << 'EOF'
    </div>

    <script>
        function applyFilters() {
            const severityFilter = document.getElementById('severityFilter').value;
            const sourceFilter = document.getElementById('sourceFilter').value.toLowerCase();
            const events = document.querySelectorAll('.event');

            events.forEach(event => {
                const eventSeverity = event.dataset.severity;
                const eventSource = event.dataset.source.toLowerCase();
                const showBySeverity = severityFilter === 'all' || eventSeverity === severityFilter;
                const showBySource = sourceFilter === '' || eventSource.includes(sourceFilter);

                event.style.display = (showBySeverity && showBySource) ? 'block' : 'none';
            });
        }
    </script>
</body>
</html>
EOF

    echo "HTML timeline saved to $html_file"
}

# Function to analyze attack patterns
analyze_attack_pattern() {
    local ip_address="$1"
    local time_window="${2:-1 hour}"

    echo "Analyzing attack patterns for IP: $ip_address"

    # Get events for this IP in time window
    local events=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE ip_address = '$ip_address' AND timestamp > datetime('now', '-$time_window');")
    local failed_auth=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE ip_address = '$ip_address' AND event_type = 'failed_login' AND timestamp > datetime('now', '-$time_window');")
    local suspicious_access=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE ip_address = '$ip_address' AND event_type IN ('suspicious_access', 'web_app_attack') AND timestamp > datetime('now', '-$time_window');")

    echo "Total events: $events"
    echo "Failed authentications: $failed_auth"
    echo "Suspicious access attempts: $suspicious_access"

    # Determine attack type
    if [ "$failed_auth" -gt 10 ]; then
        echo "Pattern: Brute force attack detected"
    elif [ "$suspicious_access" -gt 5 ]; then
        echo "Pattern: Probing/scanning activity detected"
    elif [ "$events" -gt 100 ]; then
        echo "Pattern: High volume traffic (possible DoS)"
    else
        echo "Pattern: Normal activity"
    fi
}

# Function to export forensic data
export_forensic_data() {
    local case_id="$1"
    local start_date="$2"
    local end_date="$3"
    local output_file="$TIMELINE_DIR/forensic_export_${case_id}_$(date +%Y%m%d).csv"

    echo "Exporting forensic data for case $case_id..."

    # Export events
    sqlite3 -header -csv "$DB_FILE" "SELECT * FROM events WHERE timestamp BETWEEN '$start_date' AND '$end_date' ORDER BY timestamp;" > "$output_file"

    # Export related alerts
    local alert_file="${output_file%.csv}_alerts.csv"
    sqlite3 -header -csv "$DB_FILE" "SELECT * FROM alerts WHERE timestamp BETWEEN '$start_date' AND '$end_date' ORDER BY timestamp;" > "$alert_file"

    echo "Forensic data exported to:"
    echo "  Events: $output_file"
    echo "  Alerts: $alert_file"

    # Create case summary
    local summary_file="${output_file%.csv}_summary.txt"
    {
        echo "Forensic Case Summary - Case ID: $case_id"
        echo "Time Period: $start_date to $end_date"
        echo "Generated: $(date)"
        echo
        echo "Event Statistics:"
        sqlite3 "$DB_FILE" "SELECT event_type, COUNT(*) FROM events WHERE timestamp BETWEEN '$start_date' AND '$end_date' GROUP BY event_type;" | while IFS='|' read -r type count; do
            echo "  $type: $count"
        done
        echo
        echo "Alert Statistics:"
        sqlite3 "$DB_FILE" "SELECT severity, COUNT(*) FROM alerts WHERE timestamp BETWEEN '$start_date' AND '$end_date' GROUP BY severity;" | while IFS='|' read -r sev count; do
            echo "  $sev: $count"
        done
    } > "$summary_file"

    echo "  Summary: $summary_file"
}

# Function to search for indicators of compromise (IOC)
search_ioc() {
    local ioc="$1"
    local search_type="${2:-ip}"  # ip, hash, domain, etc.

    echo "Searching for IOC: $ioc (type: $search_type)"

    case "$search_type" in
        "ip")
            sqlite3 "$DB_FILE" "SELECT timestamp, source, event_type, message FROM events WHERE ip_address = '$ioc' ORDER BY timestamp DESC LIMIT 20;" | while IFS='|' read -r ts src type msg; do
                echo "$ts [$src] $type: $msg"
            done
            ;;
        "hash")
            sqlite3 "$DB_FILE" "SELECT timestamp, source, event_type, message FROM events WHERE message LIKE '%$ioc%' ORDER BY timestamp DESC LIMIT 20;" | while IFS='|' read -r ts src type msg; do
                echo "$ts [$src] $type: $msg"
            done
            ;;
        "domain")
            sqlite3 "$DB_FILE" "SELECT timestamp, source, event_type, message FROM events WHERE message LIKE '%$ioc%' ORDER BY timestamp DESC LIMIT 20;" | while IFS='|' read -r ts src type msg; do
                echo "$ts [$src] $type: $msg"
            done
            ;;
    esac
}

# Main function
main() {
    case "${1:-timeline}" in
        "timeline")
            if [ -z "$2" ]; then
                echo "Usage: $0 timeline <ip> [user] [start_date] [end_date] [event_types]"
                exit 1
            fi
            generate_timeline "$2" "${3:-}" "${4:-}" "${5:-}" "${6:-}"
            ;;
        "analyze")
            if [ -z "$2" ]; then
                echo "Usage: $0 analyze <ip_address> [time_window]"
                exit 1
            fi
            analyze_attack_pattern "$2" "${3:-1 hour}"
            ;;
        "export")
            if [ -z "$4" ]; then
                echo "Usage: $0 export <case_id> <start_date> <end_date>"
                exit 1
            fi
            export_forensic_data "$2" "$3" "$4"
            ;;
        "ioc")
            if [ -z "$2" ]; then
                echo "Usage: $0 ioc <indicator> [type]"
                exit 1
            fi
            search_ioc "$2" "${3:-ip}"
            ;;
        *)
            echo "Usage: $0 [timeline|analyze|export|ioc]"
            exit 1
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi