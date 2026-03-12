#!/bin/bash

# SIEM Alert Manager
# Handles alert processing, escalation, and notifications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/siem_events.db"
CONFIG_FILE="$SCRIPT_DIR/siem_config.conf"

# Default configuration
SMTP_SERVER="localhost"
SMTP_PORT="25"
ADMIN_EMAIL="admin@localhost"
ESCALATION_LEVELS=(
    "email:admin@localhost"
    "sms:+1234567890"
    "call:+1234567890"
    "pager:security_team"
)

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Function to send email notification
send_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    if command -v mail &> /dev/null; then
        echo "$body" | mail -s "$subject" "$to"
    elif command -v sendmail &> /dev/null; then
        echo "To: $to
Subject: $subject

$body" | sendmail -t
    else
        echo "No email client available"
    fi
}

# Function to send SMS (placeholder - integrate with SMS gateway)
send_sms() {
    local number="$1"
    local message="$2"

    # Placeholder for SMS integration
    echo "SMS to $number: $message"
    # Could integrate with Twilio, AWS SNS, etc.
}

# Function to make call (placeholder)
make_call() {
    local number="$1"
    local message="$2"

    echo "Call to $number: $message"
    # Could integrate with VoIP services
}

# Function to send pager alert
send_pager() {
    local pager_id="$1"
    local message="$2"

    echo "Pager alert to $pager_id: $message"
    # Could integrate with pager services
}

# Function to notify based on escalation level
notify_escalation() {
    local level="$1"
    local alert_id="$2"
    local severity="$3"
    local title="$4"
    local description="$5"

    local notification="${ESCALATION_LEVELS[$level]}"
    local method=$(echo "$notification" | cut -d: -f1)
    local target=$(echo "$notification" | cut -d: -f2)

    local subject="SIEM Alert [$severity] - $title"
    local body="Alert ID: $alert_id
Severity: $severity
Title: $title
Description: $description
Time: $(date)
Escalation Level: $level

Please investigate immediately."

    case "$method" in
        "email")
            send_email "$target" "$subject" "$body"
            ;;
        "sms")
            send_sms "$target" "$body"
            ;;
        "call")
            make_call "$target" "$body"
            ;;
        "pager")
            send_pager "$target" "$body"
            ;;
    esac
}

# Function to check for escalation
check_escalation() {
    local alert_id="$1"
    local severity="$2"
    local current_level="$3"
    local timestamp="$4"

    # Calculate time since alert
    local alert_time=$(date -d "$timestamp" +%s)
    local current_time=$(date +%s)
    local age_minutes=$(( (current_time - alert_time) / 60 ))

    local new_level="$current_level"

    # Escalation rules based on severity and time
    case "$severity" in
        "critical")
            if [ "$age_minutes" -gt 5 ] && [ "$current_level" -lt 1 ]; then
                new_level=1
            elif [ "$age_minutes" -gt 15 ] && [ "$current_level" -lt 2 ]; then
                new_level=2
            elif [ "$age_minutes" -gt 30 ] && [ "$current_level" -lt 3 ]; then
                new_level=3
            fi
            ;;
        "high")
            if [ "$age_minutes" -gt 15 ] && [ "$current_level" -lt 1 ]; then
                new_level=1
            elif [ "$age_minutes" -gt 60 ] && [ "$current_level" -lt 2 ]; then
                new_level=2
            fi
            ;;
        "medium")
            if [ "$age_minutes" -gt 60 ] && [ "$current_level" -lt 1 ]; then
                new_level=1
            fi
            ;;
    esac

    if [ "$new_level" -gt "$current_level" ]; then
        echo "$new_level"
        return 0
    else
        echo "$current_level"
        return 1
    fi
}

# Function to process alerts
process_alerts() {
    echo "$(date): Processing alerts..."

    # Get unacknowledged alerts
    sqlite3 "$DB_FILE" "SELECT id, severity, title, description, timestamp, escalation_level, status FROM alerts WHERE status != 'resolved' ORDER BY timestamp DESC;" | while IFS='|' read -r alert_id severity title description timestamp escalation_level status; do

        # Check for escalation
        new_level=$(check_escalation "$alert_id" "$severity" "$escalation_level" "$timestamp")

        if [ "$new_level" -gt "$escalation_level" ]; then
            echo "Escalating alert $alert_id to level $new_level"

            # Update escalation level
            sqlite3 "$DB_FILE" "UPDATE alerts SET escalation_level = $new_level WHERE id = $alert_id;"

            # Send notification
            notify_escalation "$new_level" "$alert_id" "$severity" "$title" "$description"
        fi

        # Auto-resolve old low-severity alerts
        if [ "$severity" = "low" ] || [ "$severity" = "info" ]; then
            alert_time=$(date -d "$timestamp" +%s)
            current_time=$(date +%s)
            age_hours=$(( (current_time - alert_time) / 3600 ))

            if [ "$age_hours" -gt 24 ]; then
                sqlite3 "$DB_FILE" "UPDATE alerts SET status = 'resolved' WHERE id = $alert_id;"
                echo "Auto-resolved old alert $alert_id"
            fi
        fi
    done

    echo "$(date): Alert processing completed."
}

# Function to acknowledge alert
acknowledge_alert() {
    local alert_id="$1"
    local user="$2"

    sqlite3 "$DB_FILE" "UPDATE alerts SET status = 'acknowledged', assigned_to = '$user' WHERE id = $alert_id;"

    echo "Alert $alert_id acknowledged by $user"
}

# Function to resolve alert
resolve_alert() {
    local alert_id="$1"
    local user="$2"

    sqlite3 "$DB_FILE" "UPDATE alerts SET status = 'resolved', assigned_to = '$user' WHERE id = $alert_id;"

    echo "Alert $alert_id resolved by $user"
}

# Function to get alert summary
get_alert_summary() {
    local period="${1:-1 hour}"

    echo "=== SIEM Alert Summary ($period) ==="
    echo

    # Count by severity
    echo "Alerts by severity:"
    sqlite3 "$DB_FILE" "SELECT severity, COUNT(*) FROM alerts WHERE timestamp > datetime('now', '-$period') GROUP BY severity;" | while IFS='|' read -r sev count; do
        echo "  $sev: $count"
    done

    echo
    echo "Alerts by status:"
    sqlite3 "$DB_FILE" "SELECT status, COUNT(*) FROM alerts WHERE timestamp > datetime('now', '-$period') GROUP BY status;" | while IFS='|' read -r stat count; do
        echo "  $stat: $count"
    done

    echo
    echo "Recent critical alerts:"
    sqlite3 "$DB_FILE" "SELECT id, title, timestamp FROM alerts WHERE severity = 'critical' AND timestamp > datetime('now', '-$period') ORDER BY timestamp DESC LIMIT 5;" | while IFS='|' read -r id title ts; do
        echo "  $id: $title ($ts)"
    done
}

# Function to cleanup old alerts
cleanup_old_alerts() {
    local days="${1:-90}"

    local count=$(sqlite3 "$DB_FILE" "DELETE FROM alerts WHERE timestamp < datetime('now', '-$days days') AND status = 'resolved';")

    if [ "$count" -gt 0 ]; then
        echo "Cleaned up $count old resolved alerts"
    fi
}

# Main function
main() {
    case "${1:-process}" in
        "process")
            process_alerts
            ;;
        "acknowledge")
            if [ -z "$2" ]; then
                echo "Usage: $0 acknowledge <alert_id> [user]"
                exit 1
            fi
            acknowledge_alert "$2" "${3:-system}"
            ;;
        "resolve")
            if [ -z "$2" ]; then
                echo "Usage: $0 resolve <alert_id> [user]"
                exit 1
            fi
            resolve_alert "$2" "${3:-system}"
            ;;
        "summary")
            get_alert_summary "${2:-1 hour}"
            ;;
        "cleanup")
            cleanup_old_alerts "${2:-90}"
            ;;
        *)
            echo "Usage: $0 [process|acknowledge|resolve|summary|cleanup]"
            exit 1
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi