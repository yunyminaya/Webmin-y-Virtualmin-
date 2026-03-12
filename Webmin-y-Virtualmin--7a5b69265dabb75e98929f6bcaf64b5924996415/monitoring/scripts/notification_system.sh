#!/bin/bash

# Sistema unificado de notificaciones para Webmin/Virtualmin DevOps
# Soporta Slack, Email, PagerDuty, y webhooks personalizados

set -e

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../configs"
LOG_DIR="/var/log/webmin_devops"

# Variables de configuración
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
EMAIL_RECIPIENTS="${EMAIL_RECIPIENTS:-admin@example.com}"
PAGERDUTY_INTEGRATION_KEY="${PAGERDUTY_INTEGRATION_KEY:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_DIR/notifications.log"
}

# Función para enviar notificación a Slack
send_slack_notification() {
    local message="$1"
    local color="${2:-good}"  # good, warning, danger
    local title="${3:-DevOps Notification}"

    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        log "⚠️ Slack webhook URL not configured"
        return 1
    fi

    local payload=$(cat <<EOF
{
  "attachments": [
    {
      "color": "$color",
      "title": "$title",
      "text": "$message",
      "footer": "Webmin/Virtualmin DevOps",
      "ts": $(date +%s)
    }
  ]
}
EOF
)

    if curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK_URL" >/dev/null 2>&1; then
        log "✅ Slack notification sent"
        return 0
    else
        log "❌ Failed to send Slack notification"
        return 1
    fi
}

# Función para enviar notificación por email
send_email_notification() {
    local subject="$1"
    local message="$2"
    local priority="${3:-normal}"  # low, normal, high

    if [ -z "$EMAIL_RECIPIENTS" ]; then
        log "⚠️ Email recipients not configured"
        return 1
    fi

    # Verificar que mail esté disponible
    if ! command -v mail >/dev/null 2>&1 && ! command -v sendmail >/dev/null 2>&1; then
        log "⚠️ Email command not available"
        return 1
    fi

    local email_headers=""
    case "$priority" in
        high)
            email_headers="-a 'X-Priority: 1' -a 'Importance: High'"
            ;;
        low)
            email_headers="-a 'X-Priority: 5' -a 'Importance: Low'"
            ;;
    esac

    # Crear mensaje completo
    local full_message="Subject: $subject

$message

--
Webmin/Virtualmin DevOps System
Generated at: $(date)
"

    # Intentar enviar con mail
    if command -v mail >/dev/null 2>&1; then
        echo "$full_message" | mail $email_headers -s "$subject" "$EMAIL_RECIPIENTS"
        log "✅ Email notification sent via mail"
        return 0
    fi

    # Intentar enviar con sendmail
    if command -v sendmail >/dev/null 2>&1; then
        (
            echo "To: $EMAIL_RECIPIENTS"
            echo "Subject: $subject"
            echo "$email_headers"
            echo ""
            echo "$full_message"
        ) | sendmail -t
        log "✅ Email notification sent via sendmail"
        return 0
    fi

    log "❌ Failed to send email notification"
    return 1
}

# Función para enviar alerta a PagerDuty
send_pagerduty_alert() {
    local summary="$1"
    local severity="${2:-info}"  # info, warning, error, critical
    local details="$3"

    if [ -z "$PAGERDUTY_INTEGRATION_KEY" ]; then
        log "⚠️ PagerDuty integration key not configured"
        return 1
    fi

    local payload=$(cat <<EOF
{
  "routing_key": "$PAGERDUTY_INTEGRATION_KEY",
  "event_action": "trigger",
  "payload": {
    "summary": "$summary",
    "severity": "$severity",
    "source": "webmin-virtualmin-devops",
    "component": "deployment-system",
    "group": "devops",
    "class": "deployment",
    "custom_details": {
      "details": "$details",
      "timestamp": "$(date -Iseconds)"
    }
  }
}
EOF
)

    if curl -s -X POST -H 'Content-type: application/json' \
         --data "$payload" 'https://events.pagerduty.com/v2/enqueue' >/dev/null 2>&1; then
        log "✅ PagerDuty alert sent"
        return 0
    else
        log "❌ Failed to send PagerDuty alert"
        return 1
    fi
}

# Función para enviar webhook personalizado
send_webhook_notification() {
    local event_type="$1"
    local data="$2"

    if [ -z "$WEBHOOK_URL" ]; then
        log "⚠️ Webhook URL not configured"
        return 1
    fi

    local payload=$(cat <<EOF
{
  "event_type": "$event_type",
  "timestamp": "$(date -Iseconds)",
  "source": "webmin-virtualmin-devops",
  "data": $data
}
EOF
)

    if curl -s -X POST -H 'Content-type: application/json' \
         --data "$payload" "$WEBHOOK_URL" >/dev/null 2>&1; then
        log "✅ Webhook notification sent"
        return 0
    else
        log "❌ Failed to send webhook notification"
        return 1
    fi
}

# Función principal para enviar notificaciones
send_notification() {
    local event_type="$1"
    local title="$2"
    local message="$3"
    local severity="${4:-info}"

    log "📢 Sending $severity notification: $title"

    # Determinar color para Slack basado en severidad
    local slack_color="good"
    case "$severity" in
        warning)
            slack_color="warning"
            ;;
        error|critical)
            slack_color="danger"
            ;;
    esac

    # Enviar notificaciones según el tipo de evento y severidad
    local notification_sent=false

    # Slack notifications para todos los eventos
    if send_slack_notification "$message" "$slack_color" "$title"; then
        notification_sent=true
    fi

    # Email notifications
    local email_priority="normal"
    case "$severity" in
        critical)
            email_priority="high"
            ;;
        warning)
            email_priority="normal"
            ;;
        info)
            email_priority="low"
            ;;
    esac

    if send_email_notification "$title" "$message" "$email_priority"; then
        notification_sent=true
    fi

    # PagerDuty para eventos críticos
    if [ "$severity" = "critical" ] || [ "$severity" = "error" ]; then
        send_pagerduty_alert "$title" "$severity" "$message"
    fi

    # Webhook para todos los eventos
    local webhook_data="{\"title\":\"$title\",\"message\":\"$message\",\"severity\":\"$severity\"}"
    send_webhook_notification "$event_type" "$webhook_data"

    if [ "$notification_sent" = true ]; then
        log "✅ Notification sent successfully"
        return 0
    else
        log "❌ Failed to send any notifications"
        return 1
    fi
}

# Funciones específicas para tipos de eventos comunes
notify_deployment_success() {
    local environment="$1"
    local version="$2"
    local duration="$3"

    local title="✅ Deployment Successful"
    local message="Deployment to $environment completed successfully

📦 Version: $version
⏱️ Duration: ${duration}s
🕐 Completed: $(date)"

    send_notification "deployment_success" "$title" "$message" "info"
}

notify_deployment_failure() {
    local environment="$1"
    local version="$2"
    local error="$3"

    local title="❌ Deployment Failed"
    local message="Deployment to $environment failed

📦 Version: $version
❌ Error: $error
🕐 Failed: $(date)"

    send_notification "deployment_failure" "$title" "$message" "error"
}

notify_rollback_executed() {
    local environment="$1"
    local reason="$2"

    local title="🔄 Rollback Executed"
    local message="Automatic rollback executed for $environment

📍 Reason: $reason
🕐 Executed: $(date)"

    send_notification "rollback_executed" "$title" "$message" "warning"
}

notify_system_alert() {
    local alert_type="$1"
    local details="$2"
    local severity="${3:-warning}"

    local title="🚨 System Alert: $alert_type"
    local message="System alert detected

📊 Type: $alert_type
📝 Details: $details
🕐 Detected: $(date)"

    send_notification "system_alert" "$title" "$message" "$severity"
}

notify_pipeline_status() {
    local pipeline="$1"
    local status="$2"
    local details="$3"

    local emoji="✅"
    local severity="info"

    case "$status" in
        failed)
            emoji="❌"
            severity="error"
            ;;
        running)
            emoji="▶️"
            severity="info"
            ;;
        cancelled)
            emoji="⏹️"
            severity="warning"
            ;;
    esac

    local title="$emoji Pipeline $status: $pipeline"
    local message="CI/CD Pipeline status update

🔧 Pipeline: $pipeline
📊 Status: $status
📝 Details: $details
🕐 Updated: $(date)"

    send_notification "pipeline_status" "$title" "$message" "$severity"
}

# Función para probar todas las configuraciones de notificación
test_notifications() {
    log "🧪 Testing notification configurations..."

    local test_message="This is a test notification from Webmin/Virtualmin DevOps system

🧪 Test Type: Configuration Test
🕐 Sent: $(date)"

    send_notification "test" "🧪 Notification Test" "$test_message" "info"
}

# Mostrar ayuda
show_help() {
    cat << EOF
Sistema de Notificaciones Webmin/Virtualmin DevOps

Uso: $0 <comando> [opciones]

Comandos disponibles:
  test                    Probar todas las configuraciones de notificación
  deploy-success <env> <version> <duration>    Notificar despliegue exitoso
  deploy-failure <env> <version> <error>       Notificar despliegue fallido
  rollback <env> <reason>                      Notificar rollback ejecutado
  alert <type> <details> [severity]            Enviar alerta del sistema
  pipeline <name> <status> <details>           Notificar estado de pipeline

Variables de entorno requeridas:
  SLACK_WEBHOOK_URL       URL del webhook de Slack
  EMAIL_RECIPIENTS        Destinatarios de email (separados por coma)
  PAGERDUTY_INTEGRATION_KEY  Clave de integración de PagerDuty
  WEBHOOK_URL             URL de webhook personalizado

Ejemplos:
  $0 test
  $0 deploy-success production v1.2.0 45
  $0 deploy-failure staging v1.2.0 "Database connection failed"
  $0 alert "High CPU Usage" "CPU usage at 95%" critical
EOF
}

# Procesar argumentos de línea de comandos
case "${1:-help}" in
    test)
        test_notifications
        ;;
    deploy-success)
        if [ $# -lt 4 ]; then
            echo "❌ Uso: $0 deploy-success <environment> <version> <duration>"
            exit 1
        fi
        notify_deployment_success "$2" "$3" "$4"
        ;;
    deploy-failure)
        if [ $# -lt 4 ]; then
            echo "❌ Uso: $0 deploy-failure <environment> <version> <error>"
            exit 1
        fi
        notify_deployment_failure "$2" "$3" "$4"
        ;;
    rollback)
        if [ $# -lt 3 ]; then
            echo "❌ Uso: $0 rollback <environment> <reason>"
            exit 1
        fi
        notify_rollback_executed "$2" "$3"
        ;;
    alert)
        if [ $# -lt 3 ]; then
            echo "❌ Uso: $0 alert <type> <details> [severity]"
            exit 1
        fi
        notify_system_alert "$2" "$3" "${4:-warning}"
        ;;
    pipeline)
        if [ $# -lt 4 ]; then
            echo "❌ Uso: $0 pipeline <name> <status> <details>"
            exit 1
        fi
        notify_pipeline_status "$2" "$3" "$4"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ Comando desconocido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac