#!/bin/bash

# ============================================================================
# SISTEMA DE ALERTAS EN TIEMPO REAL
# PARA WEBMIN Y VIRTUALMIN IDS/IPS
# ============================================================================
# Alertas por email, Telegram, Slack y otros canales
# Configuración personalizable de notificaciones
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables de configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERT_DIR="/etc/webmin-virtualmin-ids/alerts"
CONFIG_FILE="$ALERT_DIR/alert_config.conf"
LOG_FILE="$ALERT_DIR/alerts.log"

# Configuración por defecto
DEFAULT_EMAIL="root@localhost"
DEFAULT_TELEGRAM_BOT_TOKEN=""
DEFAULT_TELEGRAM_CHAT_ID=""
DEFAULT_SLACK_WEBHOOK=""
DEFAULT_DISCORD_WEBHOOK=""
DEFAULT_ALERT_LEVEL="MEDIUM"

# Función de logging
log_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$(dirname "$LOG_FILE")"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] ALERTS:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] ALERTS:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] ALERTS:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] ALERTS:${NC} $message" ;;
        "ALERT")   echo -e "${RED}🚨 [$timestamp] ALERTS:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] ALERTS:${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Inicializar configuración
init_alert_config() {
    mkdir -p "$ALERT_DIR"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_alert "INFO" "Creando configuración por defecto..."

        cat > "$CONFIG_FILE" << EOF
# Configuración del Sistema de Alertas - Webmin/Virtualmin IDS
# Modificar estos valores según sus necesidades

# Configuración de Email
ALERT_EMAIL="$DEFAULT_EMAIL"
EMAIL_SUBJECT_PREFIX="[IDS-ALERT]"

# Configuración de Telegram
TELEGRAM_BOT_TOKEN="$DEFAULT_TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$DEFAULT_TELEGRAM_CHAT_ID"

# Configuración de Slack
SLACK_WEBHOOK_URL="$DEFAULT_SLACK_WEBHOOK"

# Configuración de Discord
DISCORD_WEBHOOK_URL="$DEFAULT_DISCORD_WEBHOOK"

# Configuración de Pushover
PUSHOVER_USER_KEY=""
PUSHOVER_APP_TOKEN=""

# Niveles de alerta (LOW, MEDIUM, HIGH, CRITICAL)
MIN_ALERT_LEVEL="$DEFAULT_ALERT_LEVEL"

# Canales habilitados (separados por comas: email,telegram,slack,discord,pushover)
ENABLED_CHANNELS="email"

# Configuración de rate limiting (segundos entre alertas del mismo tipo)
ALERT_RATE_LIMIT=300

# Lista de emails adicionales (separados por comas)
ADDITIONAL_EMAILS=""
EOF

        log_alert "SUCCESS" "Configuración creada: $CONFIG_FILE"
    fi

    # Cargar configuración
    source "$CONFIG_FILE" 2>/dev/null || log_alert "WARNING" "Error cargando configuración"
}

# Cargar configuración
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# Función para enviar alerta por email
send_email_alert() {
    local subject="$1"
    local message="$2"
    local level="${3:-MEDIUM}"

    if [[ -z "$ALERT_EMAIL" ]] && [[ -z "$ADDITIONAL_EMAILS" ]]; then
        return 1
    fi

    local full_subject="$EMAIL_SUBJECT_PREFIX $subject"
    local recipients="$ALERT_EMAIL"

    if [[ -n "$ADDITIONAL_EMAILS" ]]; then
        recipients="$recipients,$ADDITIONAL_EMAILS"
    fi

    # Crear mensaje con formato
    local email_message="$(create_formatted_message "$subject" "$message" "$level")"

    # Enviar email
    if command -v mail >/dev/null 2>&1; then
        echo "$email_message" | mail -s "$full_subject" "$recipients" 2>/dev/null && \
        log_alert "SUCCESS" "Email enviado a: $recipients"
    elif command -v sendmail >/dev/null 2>&1; then
        {
            echo "To: $recipients"
            echo "Subject: $full_subject"
            echo ""
            echo "$email_message"
        } | sendmail -t && \
        log_alert "SUCCESS" "Email enviado via sendmail a: $recipients"
    else
        log_alert "WARNING" "No se pudo enviar email - ni mail ni sendmail disponibles"
        return 1
    fi
}

# Función para enviar alerta por Telegram
send_telegram_alert() {
    local subject="$1"
    local message="$2"
    local level="${3:-MEDIUM}"

    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 1
    fi

    local telegram_message="$(create_telegram_message "$subject" "$message" "$level")"

    local url="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage"
    local data="chat_id=$TELEGRAM_CHAT_ID&text=$telegram_message&parse_mode=HTML"

    if command -v curl >/dev/null 2>&1; then
        if curl -s -X POST "$url" -d "$data" >/dev/null 2>&1; then
            log_alert "SUCCESS" "Mensaje Telegram enviado"
        else
            log_alert "ERROR" "Error enviando mensaje Telegram"
            return 1
        fi
    else
        log_alert "WARNING" "curl no disponible para Telegram"
        return 1
    fi
}

# Función para enviar alerta por Slack
send_slack_alert() {
    local subject="$1"
    local message="$2"
    local level="${3:-MEDIUM}"

    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return 1
    fi

    local slack_message="$(create_slack_message "$subject" "$message" "$level")"

    if command -v curl >/dev/null 2>&1; then
        if curl -s -X POST -H 'Content-type: application/json' \
               --data "$slack_message" "$SLACK_WEBHOOK_URL" >/dev/null 2>&1; then
            log_alert "SUCCESS" "Mensaje Slack enviado"
        else
            log_alert "ERROR" "Error enviando mensaje Slack"
            return 1
        fi
    else
        log_alert "WARNING" "curl no disponible para Slack"
        return 1
    fi
}

# Función para enviar alerta por Discord
send_discord_alert() {
    local subject="$1"
    local message="$2"
    local level="${3:-MEDIUM}"

    if [[ -z "$DISCORD_WEBHOOK_URL" ]]; then
        return 1
    fi

    local discord_message="$(create_discord_message "$subject" "$message" "$level")"

    if command -v curl >/dev/null 2>&1; then
        if curl -s -X POST -H 'Content-Type: application/json' \
               -d "$discord_message" "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1; then
            log_alert "SUCCESS" "Mensaje Discord enviado"
        else
            log_alert "ERROR" "Error enviando mensaje Discord"
            return 1
        fi
    else
        log_alert "WARNING" "curl no disponible para Discord"
        return 1
    fi
}

# Función para enviar alerta por Pushover
send_pushover_alert() {
    local subject="$1"
    local message="$2"
    local level="${3:-MEDIUM}"

    if [[ -z "$PUSHOVER_USER_KEY" ]] || [[ -z "$PUSHOVER_APP_TOKEN" ]]; then
        return 1
    fi

    local priority="$(get_pushover_priority "$level")"

    if command -v curl >/dev/null 2>&1; then
        if curl -s \
               --form-string "token=$PUSHOVER_APP_TOKEN" \
               --form-string "user=$PUSHOVER_USER_KEY" \
               --form-string "title=$subject" \
               --form-string "message=$message" \
               --form-string "priority=$priority" \
               https://api.pushover.net/1/messages.json >/dev/null 2>&1; then
            log_alert "SUCCESS" "Mensaje Pushover enviado"
        else
            log_alert "ERROR" "Error enviando mensaje Pushover"
            return 1
        fi
    else
        log_alert "WARNING" "curl no disponible para Pushover"
        return 1
    fi
}

# Crear mensaje formateado para email
create_formatted_message() {
    local subject="$1"
    local message="$2"
    local level="$3"

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat << EOF
🚨 ALERTA DE SEGURIDAD - $level 🚨

Servidor: $hostname
Timestamp: $timestamp
Tipo: $subject

$message

---
Sistema de Detección de Intrusiones
Webmin/Virtualmin IDS
EOF
}

# Crear mensaje para Telegram
create_telegram_message() {
    local subject="$1"
    local message="$2"
    local level="$3"

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local emoji="$(get_level_emoji "$level")"

    # Escapar caracteres especiales para HTML
    message=$(echo "$message" | sed 's/&/\&/g; s/</\</g; s/>/\>/g')

    echo "<b>$emoji ALERTA $level $emoji</b>
<b>Servidor:</b> $hostname
<b>Hora:</b> $timestamp
<b>Tipo:</b> $subject

$message

<i>Webmin/Virtualmin IDS</i>"
}

# Crear mensaje para Slack
create_slack_message() {
    local subject="$1"
    local message="$2"
    local level="$3"

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="$(get_slack_color "$level")"

    cat << EOF
{
  "attachments": [
    {
      "color": "$color",
      "title": "🚨 ALERTA DE SEGURIDAD - $level",
      "fields": [
        {
          "title": "Servidor",
          "value": "$hostname",
          "short": true
        },
        {
          "title": "Tipo",
          "value": "$subject",
          "short": true
        },
        {
          "title": "Hora",
          "value": "$timestamp",
          "short": true
        }
      ],
      "text": "$message",
      "footer": "Webmin/Virtualmin IDS"
    }
  ]
}
EOF
}

# Crear mensaje para Discord
create_discord_message() {
    local subject="$1"
    local message="$2"
    local level="$3"

    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color="$(get_discord_color "$level")"

    cat << EOF
{
  "embeds": [
    {
      "title": "🚨 ALERTA DE SEGURIDAD - $level",
      "color": $color,
      "fields": [
        {
          "name": "Servidor",
          "value": "$hostname",
          "inline": true
        },
        {
          "name": "Tipo",
          "value": "$subject",
          "inline": true
        },
        {
          "name": "Hora",
          "value": "$timestamp",
          "inline": true
        }
      ],
      "description": "$message",
      "footer": {
        "text": "Webmin/Virtualmin IDS"
      }
    }
  ]
}
EOF
}

# Funciones auxiliares para colores/emojis
get_level_emoji() {
    local level="$1"
    case "$level" in
        "CRITICAL") echo "🔴" ;;
        "HIGH") echo "🟠" ;;
        "MEDIUM") echo "🟡" ;;
        "LOW") echo "🟢" ;;
        *) echo "ℹ️" ;;
    esac
}

get_slack_color() {
    local level="$1"
    case "$level" in
        "CRITICAL") echo "danger" ;;
        "HIGH") echo "warning" ;;
        "MEDIUM") echo "#ffa500" ;;
        "LOW") echo "good" ;;
        *) echo "#808080" ;;
    esac
}

get_discord_color() {
    local level="$1"
    case "$level" in
        "CRITICAL") echo "16711680" ;;  # Rojo
        "HIGH") echo "16753920" ;;      # Naranja
        "MEDIUM") echo "16776960" ;;    # Amarillo
        "LOW") echo "65280" ;;         # Verde
        *) echo "8421504" ;;           # Gris
    esac
}

get_pushover_priority() {
    local level="$1"
    case "$level" in
        "CRITICAL") echo "2" ;;  # Alta prioridad + sonido
        "HIGH") echo "1" ;;      # Alta prioridad
        "MEDIUM") echo "0" ;;    # Normal
        "LOW") echo "-1" ;;     # Baja prioridad
        *) echo "0" ;;
    esac
}

# Verificar si el nivel de alerta está habilitado
should_send_alert() {
    local level="$1"

    # Convertir niveles a números para comparación
    local level_num="$(level_to_number "$level")"
    local min_level_num="$(level_to_number "$MIN_ALERT_LEVEL")"

    [[ $level_num -ge $min_level_num ]]
}

level_to_number() {
    local level="$1"
    case "$level" in
        "CRITICAL") echo "4" ;;
        "HIGH") echo "3" ;;
        "MEDIUM") echo "2" ;;
        "LOW") echo "1" ;;
        *) echo "0" ;;
    esac
}

# Función principal para enviar alerta
send_alert() {
    local subject="$1"
    local message="$2"
    local level="${3:-MEDIUM}"

    # Verificar si el nivel está habilitado
    if ! should_send_alert "$level"; then
        log_alert "INFO" "Alerta ignorada (nivel $level por debajo del mínimo $MIN_ALERT_LEVEL)"
        return 0
    fi

    log_alert "INFO" "Enviando alerta: $subject (Nivel: $level)"

    # Enviar por todos los canales habilitados
    IFS=',' read -ra CHANNELS <<< "$ENABLED_CHANNELS"
    for channel in "${CHANNELS[@]}"; do
        channel=$(echo "$channel" | xargs)  # Trim whitespace

        case "$channel" in
            "email")
                send_email_alert "$subject" "$message" "$level" || true
                ;;
            "telegram")
                send_telegram_alert "$subject" "$message" "$level" || true
                ;;
            "slack")
                send_slack_alert "$subject" "$message" "$level" || true
                ;;
            "discord")
                send_discord_alert "$subject" "$message" "$level" || true
                ;;
            "pushover")
                send_pushover_alert "$subject" "$message" "$level" || true
                ;;
        esac
    done
}

# Función para configurar alertas
configure_alerts() {
    echo "=== CONFIGURACIÓN DEL SISTEMA DE ALERTAS ==="
    echo ""
    echo "Configuración actual:"
    echo "Archivo: $CONFIG_FILE"
    echo ""

    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Contenido actual:"
        cat "$CONFIG_FILE"
        echo ""
    fi

    echo "Para modificar la configuración, edite el archivo: $CONFIG_FILE"
    echo ""
    echo "Ejemplos de configuración:"
    echo ""
    echo "# Email básico:"
    echo "ALERT_EMAIL=\"admin@tu-dominio.com\""
    echo "ENABLED_CHANNELS=\"email\""
    echo ""
    echo "# Telegram:"
    echo "TELEGRAM_BOT_TOKEN=\"tu_bot_token\""
    echo "TELEGRAM_CHAT_ID=\"tu_chat_id\""
    echo "ENABLED_CHANNELS=\"telegram\""
    echo ""
    echo "# Múltiples canales:"
    echo "ENABLED_CHANNELS=\"email,telegram,slack\""
    echo ""
    echo "# Niveles de alerta:"
    echo "MIN_ALERT_LEVEL=\"HIGH\"  # Solo alertas HIGH y CRITICAL"
}

# Función para probar alertas
test_alerts() {
    local channel="${1:-all}"

    log_alert "INFO" "Probando sistema de alertas..."

    local test_subject="TEST DE ALERTA"
    local test_message="Esta es una alerta de prueba del sistema IDS/IPS de Webmin/Virtualmin.

Si recibe esta alerta, la configuración es correcta."

    if [[ "$channel" == "all" ]]; then
        send_alert "$test_subject" "$test_message" "LOW"
    else
        # Probar canal específico
        case "$channel" in
            "email")
                send_email_alert "$test_subject" "$test_message" "LOW"
                ;;
            "telegram")
                send_telegram_alert "$test_subject" "$test_message" "LOW"
                ;;
            "slack")
                send_slack_alert "$test_subject" "$test_message" "LOW"
                ;;
            "discord")
                send_discord_alert "$test_subject" "$test_message" "LOW"
                ;;
            "pushover")
                send_pushover_alert "$test_subject" "$test_message" "LOW"
                ;;
            *)
                log_alert "ERROR" "Canal desconocido: $channel"
                return 1
                ;;
        esac
    fi

    log_alert "SUCCESS" "Prueba de alertas completada"
}

# Función de validación de inputs
validate_input() {
    local input="$1"
    local type="$2"

    case "$type" in
        "action")
            # Solo letras, números, guiones bajos
            [[ "$input" =~ ^[a-zA-Z0-9_]+$ ]]
            ;;
        "level")
            # Niveles válidos
            [[ "$input" =~ ^(CRITICAL|HIGH|MEDIUM|LOW)$ ]]
            ;;
        "channel")
            # Canales válidos
            [[ "$input" =~ ^(email|telegram|slack|discord|pushover|all)$ ]]
            ;;
        "text")
            # Texto básico, sin caracteres peligrosos para comandos
            [[ "$input" != *";"* ]] && [[ "$input" != *"&"* ]] && [[ "$input" != *"|"* ]] && [[ "$input" != *"\`"* ]] && [[ "$input" != *"$"* ]] && [[ "$input" != *"("* ]] && [[ "$input" != *")"* ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# Función principal
main() {
    local action="${1:-status}"

    # Validar acción
    if ! validate_input "$action" "action" 2>/dev/null; then
        echo "❌ Error: Acción inválida: $action"
        exit 1
    fi

    case "$action" in
        "init")
            init_alert_config
            ;;
        "test")
            load_config
            local channel="${2:-all}"
            if ! validate_input "$channel" "channel" 2>/dev/null; then
                echo "❌ Error: Canal inválido: $channel"
                exit 1
            fi
            test_alerts "$channel"
            ;;
        "config")
            configure_alerts
            ;;
        "send")
            load_config
            local subject="${2:-Test Alert}"
            local message="${3:-Test message}"
            local level="${4:-MEDIUM}"

            # Validar inputs
            if ! validate_input "$level" "level" 2>/dev/null; then
                echo "❌ Error: Nivel inválido: $level"
                exit 1
            fi
            if ! validate_input "$subject" "text" 2>/dev/null; then
                echo "❌ Error: Asunto contiene caracteres peligrosos: $subject"
                exit 1
            fi
            if ! validate_input "$message" "text" 2>/dev/null; then
                echo "❌ Error: Mensaje contiene caracteres peligrosos: $message"
                exit 1
            fi

            send_alert "$subject" "$message" "$level"
            ;;
        "status")
            echo "=== ESTADO DEL SISTEMA DE ALERTAS ==="
            echo "Directorio: $ALERT_DIR"
            echo "Configuración: $CONFIG_FILE"
            echo "Log: $LOG_FILE"
            echo ""

            if [[ -f "$CONFIG_FILE" ]]; then
                echo "Canales habilitados: $ENABLED_CHANNELS"
                echo "Nivel mínimo: $MIN_ALERT_LEVEL"
                echo "✅ Sistema configurado"
            else
                echo "❌ Sistema no configurado - ejecute: $0 init"
            fi
            ;;
        *)
            echo "Sistema de Alertas - Webmin/Virtualmin IDS"
            echo ""
            echo "Uso: $0 [acción] [parámetros]"
            echo ""
            echo "Acciones:"
            echo "  init           - Inicializar configuración"
            echo "  test [canal]   - Probar alertas (canal: email, telegram, slack, discord, pushover)"
            echo "  config         - Mostrar configuración actual"
            echo "  send \"titulo\" \"mensaje\" [nivel] - Enviar alerta manual"
            echo "  status         - Mostrar estado del sistema"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi