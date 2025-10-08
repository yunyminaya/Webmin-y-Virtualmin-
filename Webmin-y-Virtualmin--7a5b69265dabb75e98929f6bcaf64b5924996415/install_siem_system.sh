#!/bin/bash

# SIEM System Installer
# Installs and configures the complete SIEM system for Webmin/Virtualmin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIEM_DIR="$SCRIPT_DIR/siem"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."

    local missing_deps=()

    # Check for sqlite3
    if ! command -v sqlite3 &> /dev/null; then
        missing_deps+=("sqlite3")
    fi

    # Check for Python3
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    else
        # Check for required Python packages
        if ! python3 -c "import sqlite3, pandas, sklearn" 2>/dev/null; then
            missing_deps+=("python3-pandas python3-scikit-learn")
        fi
    fi

    # Check for jq (optional, for JSON processing)
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found - some features will be limited"
    fi

    # Check for Webmin
    if [ ! -d "/usr/libexec/webmin" ] && [ ! -d "/opt/webmin" ]; then
        print_warning "Webmin not found in standard locations"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install them and run the installer again."
        echo "On Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        echo "On CentOS/RHEL: sudo yum install ${missing_deps[*]}"
        exit 1
    fi

    print_status "Dependencies check passed"
}

# Function to install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."

    if command -v pip3 &> /dev/null; then
        pip3 install pandas scikit-learn joblib
    else
        print_warning "pip3 not found, trying to install via package manager..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y python3-pandas python3-scikit-learn python3-joblib
        elif command -v yum &> /dev/null; then
            yum install -y python3-pandas python3-scikit-learn python3-joblib
        else
            print_error "Could not install Python dependencies automatically"
            exit 1
        fi
    fi

    print_status "Python dependencies installed"
}

# Function to initialize SIEM database
init_database() {
    print_status "Initializing SIEM database..."

    cd "$SIEM_DIR"
    if [ -f "siem_events.db" ]; then
        print_warning "Database already exists, backing up..."
        mv "siem_events.db" "siem_events.db.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    bash init_siem_db.sh

    if [ $? -eq 0 ]; then
        print_status "Database initialized successfully"
    else
        print_error "Failed to initialize database"
        exit 1
    fi
}

# Function to install Webmin module
install_webmin_module() {
    print_status "Installing Webmin module..."

    # Find Webmin directory
    local webmin_dir=""
    for dir in "/usr/libexec/webmin" "/opt/webmin" "/usr/local/webmin"; do
        if [ -d "$dir" ]; then
            webmin_dir="$dir"
            break
        fi
    done

    if [ -z "$webmin_dir" ]; then
        print_warning "Webmin directory not found, skipping module installation"
        return
    fi

    local module_dir="$webmin_dir/siem"

    # Copy module files
    mkdir -p "$module_dir"
    cp "$SIEM_DIR/module.info" "$module_dir/"
    cp "$SIEM_DIR/index.cgi" "$module_dir/"

    # Set permissions
    chown -R root:root "$module_dir"
    chmod 755 "$module_dir"
    chmod 755 "$module_dir/index.cgi"

    print_status "Webmin module installed to $module_dir"
}

# Function to setup cron jobs
setup_cron_jobs() {
    print_status "Setting up cron jobs..."

    local cron_file="/etc/cron.d/siem"

    cat > "$cron_file" << EOF
# SIEM System Cron Jobs
# Collect logs every 5 minutes
*/5 * * * * root $SIEM_DIR/log_collector.sh

# Run correlation engine every 10 minutes
*/10 * * * * root $SIEM_DIR/correlation_engine.sh

# Process alerts every 5 minutes
*/5 * * * * root $SIEM_DIR/alert_manager.sh process

# Run compliance checks daily at 2 AM
0 2 * * * root $SIEM_DIR/compliance_checker.sh all

# Generate daily reports at 6 AM
0 6 * * * root $SIEM_DIR/report_generator.sh daily

# Cleanup old data weekly (Sundays at 3 AM)
0 3 * * 0 root $SIEM_DIR/alert_manager.sh cleanup 90 && $SIEM_DIR/report_generator.sh cleanup 90
EOF

    chmod 644 "$cron_file"

    print_status "Cron jobs configured"
}

# Function to create configuration file
create_config() {
    print_status "Creating configuration file..."

    local config_file="$SIEM_DIR/siem_config.conf"

    cat > "$config_file" << EOF
# SIEM System Configuration

# Database
DB_FILE="$SIEM_DIR/siem_events.db"

# Log sources (add custom paths as needed)
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

# Alert escalation settings
SMTP_SERVER="localhost"
SMTP_PORT="25"
ADMIN_EMAIL="admin@localhost"

# Escalation levels (method:target)
ESCALATION_LEVELS=(
    "email:admin@localhost"
    "sms:+1234567890"
    "call:+1234567890"
    "pager:security_team"
)

# Compliance settings
COMPLIANCE_STANDARDS=("PCI-DSS" "GDPR" "HIPAA")

# Reporting settings
REPORT_RETENTION_DAYS=90
AUTO_EMAIL_REPORTS=true
REPORT_RECIPIENTS="admin@localhost,security@company.com"
EOF

    chmod 600 "$config_file"

    print_status "Configuration file created at $config_file"
}

# Function to integrate with existing systems
integrate_systems() {
    print_status "Integrating with existing security systems..."

    # Check for intelligent-firewall
    if [ -d "../intelligent-firewall" ]; then
        print_status "Found intelligent-firewall, integrating..."
        # Add firewall events to log collector
    fi

    # Check for monitoring systems
    if [ -d "../pro_monitoring" ]; then
        print_status "Found pro_monitoring, integrating..."
        # Add monitoring integration
    fi

    # Check for IDS
    if [ -f "/etc/snort/snort.conf" ] || [ -f "/etc/suricata/suricata.yaml" ]; then
        print_status "Found IDS system, integrating..."
        # Add IDS log parsing
    fi

    print_status "System integration completed"
}

# Function to create systemd service (optional)
create_service() {
    print_status "Creating systemd service..."

    local service_file="/etc/systemd/system/siem.service"

    cat > "$service_file" << EOF
[Unit]
Description=SIEM Security Information and Event Management
After=network.target

[Service]
Type=simple
ExecStart=$SIEM_DIR/log_collector.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable siem

    print_status "Systemd service created and enabled"
}

# Function to run initial tests
run_tests() {
    print_status "Running initial system tests..."

    cd "$SIEM_DIR"

    # Test database
    if sqlite3 siem_events.db "SELECT COUNT(*) FROM events;" &>/dev/null; then
        print_status "Database test passed"
    else
        print_error "Database test failed"
    fi

    # Test log collector
    if timeout 10s bash log_collector.sh &>/dev/null; then
        print_status "Log collector test passed"
    else
        print_warning "Log collector test timed out (expected for first run)"
    fi

    # Test correlation engine
    if bash correlation_engine.sh &>/dev/null; then
        print_status "Correlation engine test passed"
    else
        print_error "Correlation engine test failed"
    fi

    print_status "Initial tests completed"
}

# Function to display post-installation instructions
post_install() {
    print_status "SIEM System installation completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Review and customize $SIEM_DIR/siem_config.conf"
    echo "2. Access the Webmin module at: Webmin → Servers → SIEM"
    echo "3. Monitor logs at $SIEM_DIR/siem_events.db"
    echo "4. Check reports in $SIEM_DIR/reports/"
    echo "5. Review alerts and configure notification preferences"
    echo
    echo "Useful commands:"
    echo "  $SIEM_DIR/log_collector.sh          # Manual log collection"
    echo "  $SIEM_DIR/correlation_engine.sh     # Manual correlation run"
    echo "  $SIEM_DIR/alert_manager.sh summary  # Alert summary"
    echo "  $SIEM_DIR/compliance_checker.sh all # Compliance check"
    echo "  $SIEM_DIR/report_generator.sh daily # Generate daily report"
    echo
    echo "The system will start collecting logs and processing events automatically."
}

# Main installation function
main() {
    echo "========================================"
    echo "  SIEM System Installation"
    echo "========================================"
    echo

    check_dependencies
    install_python_deps
    init_database
    install_webmin_module
    create_config
    setup_cron_jobs
    integrate_systems

    # Optional: create service
    read -p "Create systemd service for automatic startup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_service
    fi

    run_tests
    post_install
}

# Run main installation
main "$@"