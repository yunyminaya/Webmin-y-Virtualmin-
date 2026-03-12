#!/bin/bash

# SIEM Compliance Checker
# Checks compliance with PCI-DSS, GDPR, HIPAA standards

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/siem_events.db"

# Function to check PCI-DSS requirements
check_pci_dss() {
    echo "Checking PCI-DSS compliance..."

    # Requirement 10: Track and monitor all access to network resources and cardholder data
    local log_access=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE message LIKE '%card%' AND timestamp > datetime('now', '-1 year');")
    local pci_status="pass"
    if [ "$log_access" -eq 0 ]; then
        pci_status="fail"
    fi

    sqlite3 "$DB_FILE" "UPDATE compliance_checks SET status = '$pci_status', last_checked = datetime('now') WHERE standard = 'PCI-DSS' AND requirement = 'Log all access to cardholder data';"

    # Requirement 11: Regularly test security systems and processes
    local test_events=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE event_type = 'security_test' AND timestamp > datetime('now', '-30 days');")
    pci_status="pass"
    if [ "$test_events" -eq 0 ]; then
        pci_status="warning"
    fi

    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO compliance_checks (standard, requirement, status, last_checked) VALUES ('PCI-DSS', 'Regularly test security systems', '$pci_status', datetime('now'));"

    echo "PCI-DSS check completed."
}

# Function to check GDPR requirements
check_gdpr() {
    echo "Checking GDPR compliance..."

    # Article 33: Notification of a personal data breach to the supervisory authority within 72 hours
    local breaches=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM alerts WHERE severity IN ('critical', 'high') AND timestamp > datetime('now', '-72 hours');")
    local gdpr_status="pass"
    if [ "$breaches" -gt 0 ]; then
        # Check if notifications were sent (simplified check)
        local notifications=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE event_type = 'gdpr_notification' AND timestamp > datetime('now', '-72 hours');")
        if [ "$notifications" -eq 0 ]; then
            gdpr_status="fail"
        fi
    fi

    sqlite3 "$DB_FILE" "UPDATE compliance_checks SET status = '$gdpr_status', last_checked = datetime('now') WHERE standard = 'GDPR' AND requirement = 'Data breach notification within 72 hours';"

    # Article 25: Data protection by design and by default
    local privacy_events=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE tags LIKE '%privacy%' AND timestamp > datetime('now', '-1 year');")
    gdpr_status="pass"
    if [ "$privacy_events" -eq 0 ]; then
        gdpr_status="warning"
    fi

    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO compliance_checks (standard, requirement, status, last_checked) VALUES ('GDPR', 'Data protection by design', '$gdpr_status', datetime('now'));"

    echo "GDPR check completed."
}

# Function to check HIPAA requirements
check_hipaa() {
    echo "Checking HIPAA compliance..."

    # Security Rule: Access control - unique user identification
    local unique_users=$(sqlite3 "$DB_FILE" "SELECT COUNT(DISTINCT user) FROM events WHERE user IS NOT NULL AND timestamp > datetime('now', '-1 year');")
    local hipaa_status="pass"
    if [ "$unique_users" -eq 0 ]; then
        hipaa_status="fail"
    fi

    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO compliance_checks (standard, requirement, status, last_checked) VALUES ('HIPAA', 'Unique user identification', '$hipaa_status', datetime('now'));"

    # Security Rule: Audit controls - hardware, software, and/or procedural mechanisms
    local audit_events=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE tags LIKE '%PHI%' AND timestamp > datetime('now', '-1 year');")
    hipaa_status="pass"
    if [ "$audit_events" -eq 0 ]; then
        hipaa_status="warning"
    fi

    sqlite3 "$DB_FILE" "UPDATE compliance_checks SET status = '$hipaa_status', last_checked = datetime('now') WHERE standard = 'HIPAA' AND requirement = 'Audit logs for PHI access';"

    # Security Rule: Integrity - mechanisms to authenticate ePHI
    local integrity_checks=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM events WHERE event_type = 'integrity_check' AND timestamp > datetime('now', '-30 days');")
    hipaa_status="pass"
    if [ "$integrity_checks" -eq 0 ]; then
        hipaa_status="warning"
    fi

    sqlite3 "$DB_FILE" "INSERT OR REPLACE INTO compliance_checks (standard, requirement, status, last_checked) VALUES ('HIPAA', 'Data integrity mechanisms', '$hipaa_status', datetime('now'));"

    echo "HIPAA check completed."
}

# Function to generate compliance report
generate_compliance_report() {
    local standard="$1"
    local output_file="$SCRIPT_DIR/compliance_report_${standard}.html"

    echo "Generating $standard compliance report..."

    cat > "$output_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$standard Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .pass { color: green; }
        .fail { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>$standard Compliance Report</h1>
    <p>Generated on: $(date)</p>

    <table>
        <tr>
            <th>Requirement</th>
            <th>Status</th>
            <th>Last Checked</th>
        </tr>
EOF

    sqlite3 "$DB_FILE" "SELECT requirement, status, last_checked FROM compliance_checks WHERE standard = '$standard';" | while IFS='|' read -r req status checked; do
        echo "        <tr>" >> "$output_file"
        echo "            <td>$req</td>" >> "$output_file"
        echo "            <td class='$status'>${status^}</td>" >> "$output_file"
        echo "            <td>$checked</td>" >> "$output_file"
        echo "        </tr>" >> "$output_file"
    done

    cat >> "$output_file" << EOF
    </table>
</body>
</html>
EOF

    echo "Report saved to $output_file"
}

# Function to run all compliance checks
run_all_checks() {
    check_pci_dss
    check_gdpr
    check_hipaa
}

# Main function
main() {
    case "${1:-all}" in
        "pci-dss")
            check_pci_dss
            ;;
        "gdpr")
            check_gdpr
            ;;
        "hipaa")
            check_hipaa
            ;;
        "report")
            if [ -z "$2" ]; then
                echo "Usage: $0 report <standard>"
                exit 1
            fi
            generate_compliance_report "$2"
            ;;
        "all")
            run_all_checks
            ;;
        *)
            echo "Usage: $0 [pci-dss|gdpr|hipaa|report|all]"
            exit 1
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi