#!/bin/bash

# SIEM Report Generator
# Generates automated security reports

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/siem_events.db"
REPORTS_DIR="$SCRIPT_DIR/reports"

mkdir -p "$REPORTS_DIR"

# Function to generate daily security report
generate_daily_report() {
    local date="${1:-$(date +%Y-%m-%d)}"
    local report_file="$REPORTS_DIR/daily_security_report_$date.html"

    echo "Generating daily security report for $date..."

    # Get date range
    local start_date="$date 00:00:00"
    local end_date="$date 23:59:59"

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Daily Security Report - $date</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: white; border: 1px solid #ddd; border-radius: 3px; }
        .alert-critical { color: red; font-weight: bold; }
        .alert-high { color: orange; font-weight: bold; }
        .alert-medium { color: blue; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .chart { margin: 20px 0; }
    </style>
</head>
<body>
    <h1>Daily Security Report - $date</h1>
    <div class="summary">
        <h2>Executive Summary</h2>
        <p>This report covers security events and activities for $date.</p>
    </div>

    <h2>Key Metrics</h2>
    <div>
EOF

    # Security metrics
    local total_events=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE timestamp BETWEEN '$start_date' AND '$end_date';")
    local total_alerts=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM alerts WHERE timestamp BETWEEN '$start_date' AND '$end_date';")
    local critical_alerts=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM alerts WHERE severity = 'critical' AND timestamp BETWEEN '$start_date' AND '$end_date';")
    local blocked_ips=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE event_type = 'block' AND timestamp BETWEEN '$start_date' AND '$end_date';")

    cat >> "$report_file" << EOF
        <div class="metric"><strong>Total Events:</strong> $total_events</div>
        <div class="metric"><strong>Total Alerts:</strong> $total_alerts</div>
        <div class="metric"><strong>Critical Alerts:</strong> $critical_alerts</div>
        <div class="metric"><strong>Blocked IPs:</strong> $blocked_ips</div>
    </div>

    <h2>Alerts Summary</h2>
    <table>
        <tr><th>Severity</th><th>Count</th><th>Percentage</th></tr>
EOF

    sqlite3 "$DB_FILE" "SELECT severity, COUNT(*) as count FROM alerts WHERE timestamp BETWEEN '$start_date' AND '$end_date' GROUP BY severity;" | while IFS='|' read -r severity count; do
        local percentage=$(( count * 100 / total_alerts ))
        local css_class="alert-$severity"
        echo "        <tr><td class='$css_class'>${severity^}</td><td>$count</td><td>$percentage%</td></tr>" >> "$report_file"
    done

    cat >> "$report_file" << EOF
    </table>

    <h2>Top Event Sources</h2>
    <table>
        <tr><th>Source</th><th>Event Count</th></tr>
EOF

    sqlite3 "$DB_FILE" "SELECT source, COUNT(*) as count FROM events WHERE timestamp BETWEEN '$start_date' AND '$end_date' GROUP BY source ORDER BY count DESC LIMIT 10;" | while IFS='|' read -r source count; do
        echo "        <tr><td>$source</td><td>$count</td></tr>" >> "$report_file"
    done

    cat >> "$report_file" << EOF
    </table>

    <h2>Recent Critical Alerts</h2>
    <table>
        <tr><th>Time</th><th>Title</th><th>Description</th><th>Status</th></tr>
EOF

    sqlite3 "$DB_FILE" "SELECT timestamp, title, description, status FROM alerts WHERE severity = 'critical' AND timestamp BETWEEN '$start_date' AND '$end_date' ORDER BY timestamp DESC;" | while IFS='|' read -r timestamp title description status; do
        echo "        <tr><td>$timestamp</td><td>$title</td><td>$description</td><td>$status</td></tr>" >> "$report_file"
    done

    cat >> "$report_file" << EOF
    </table>

    <h2>Compliance Status</h2>
    <table>
        <tr><th>Standard</th><th>Requirement</th><th>Status</th></tr>
EOF

    sqlite3 "$DB_FILE" "SELECT standard, requirement, status FROM compliance_checks;" | while IFS='|' read -r standard requirement status; do
        local css_class="alert-$status"
        echo "        <tr><td>$standard</td><td>$requirement</td><td class='$css_class'>${status^}</td></tr>" >> "$report_file"
    done

    cat >> "$report_file" << EOF
    </table>

    <hr>
    <p><small>Report generated on $(date) by SIEM System</small></p>
</body>
</html>
EOF

    # Save report to database
    local content=$(cat "$report_file")
    sqlite3 "$DB_FILE" "INSERT INTO reports (report_type, period_start, period_end, content, format) VALUES ('daily', '$start_date', '$end_date', '$content', 'html');"

    echo "Daily report saved to $report_file"
}

# Function to generate weekly security report
generate_weekly_report() {
    local week_start="${1:-$(date -d 'last monday' +%Y-%m-%d)}"
    local week_end=$(date -d "$week_start +6 days" +%Y-%m-%d)
    local report_file="$REPORTS_DIR/weekly_security_report_$week_start.html"

    echo "Generating weekly security report for $week_start to $week_end..."

    # Similar structure to daily report but with weekly data
    # Implementation would be similar but with different date ranges and additional weekly metrics

    generate_daily_report "$week_end"  # For now, use daily report structure
    mv "$REPORTS_DIR/daily_security_report_$week_end.html" "$report_file"

    echo "Weekly report saved to $report_file"
}

# Function to generate compliance report
generate_compliance_report() {
    local report_file="$REPORTS_DIR/compliance_report_$(date +%Y-%m-%d).html"

    echo "Generating compliance report..."

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Compliance Report - $(date +%Y-%m-%d)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .standard { margin-bottom: 30px; border: 1px solid #ddd; padding: 15px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Compliance Report</h1>
    <p>Generated on: $(date)</p>
EOF

    for standard in "PCI-DSS" "GDPR" "HIPAA"; do
        echo "    <div class='standard'>" >> "$report_file"
        echo "        <h2>$standard Compliance</h2>" >> "$report_file"
        echo "        <table>" >> "$report_file"
        echo "            <tr><th>Requirement</th><th>Status</th><th>Last Checked</th></tr>" >> "$report_file"

        sqlite3 "$DB_FILE" "SELECT requirement, status, last_checked FROM compliance_checks WHERE standard = '$standard';" | while IFS='|' read -r req status checked; do
            echo "            <tr><td>$req</td><td class='$status'>${status^}</td><td>$checked</td></tr>" >> "$report_file"
        done

        echo "        </table>" >> "$report_file"
        echo "    </div>" >> "$report_file"
    done

    cat >> "$report_file" << EOF
</body>
</html>
EOF

    echo "Compliance report saved to $report_file"
}

# Function to send reports via email
send_report() {
    local report_file="$1"
    local recipient="${2:-admin@localhost}"
    local subject="${3:-SIEM Security Report}"

    if [ -f "$report_file" ]; then
        echo "Sending report $report_file to $recipient..."

        if command -v mail &> /dev/null; then
            mail -s "$subject" -a "$report_file" "$recipient" < /dev/null
        elif command -v mutt &> /dev/null; then
            echo "SIEM Security Report attached." | mutt -s "$subject" -a "$report_file" -- "$recipient"
        else
            echo "No email client available for sending reports"
        fi
    else
        echo "Report file $report_file not found"
    fi
}

# Function to cleanup old reports
cleanup_old_reports() {
    local days="${1:-90}"

    echo "Cleaning up reports older than $days days..."

    find "$REPORTS_DIR" -name "*.html" -mtime +$days -delete

    # Remove old reports from database
    sqlite3 "$DB_FILE" "DELETE FROM reports WHERE generated_at < datetime('now', '-$days days');"

    echo "Cleanup completed."
}

# Main function
main() {
    case "${1:-daily}" in
        "daily")
            generate_daily_report "${2:-$(date +%Y-%m-%d)}"
            ;;
        "weekly")
            generate_weekly_report "${2:-$(date -d 'last monday' +%Y-%m-%d)}"
            ;;
        "compliance")
            generate_compliance_report
            ;;
        "send")
            if [ -z "$2" ]; then
                echo "Usage: $0 send <report_file> [recipient] [subject]"
                exit 1
            fi
            send_report "$2" "${3:-admin@localhost}" "${4:-SIEM Security Report}"
            ;;
        "cleanup")
            cleanup_old_reports "${2:-90}"
            ;;
        *)
            echo "Usage: $0 [daily|weekly|compliance|send|cleanup]"
            exit 1
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi