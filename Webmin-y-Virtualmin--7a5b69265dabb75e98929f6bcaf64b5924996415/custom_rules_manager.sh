#!/bin/bash

# ============================================================================
# GESTOR DE REGLAS PERSONALIZABLES
# PARA WEBMIN/VIRTUALMIN IDS/IPS
# ============================================================================
# Sistema para crear, modificar y gestionar reglas de detección
# Interfaz para configuración avanzada de patrones y umbrales
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

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="/etc/webmin-virtualmin-ids/rules"
CONFIG_FILE="$RULES_DIR/custom_rules.conf"
LOG_FILE="$RULES_DIR/rules_manager.log"

# Función de logging
log_rules() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$(dirname "$LOG_FILE")"

    case "$level" in
        "SUCCESS") echo -e "${GREEN}✅ [$timestamp] RULES:${NC} $message" ;;
        "INFO")    echo -e "${BLUE}💎 [$timestamp] RULES:${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠️ [$timestamp] RULES:${NC} $message" ;;
        "ERROR")   echo -e "${RED}❌ [$timestamp] RULES:${NC} $message" ;;
        *)         echo -e "${PURPLE}🔥 [$timestamp] RULES:${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Inicializar sistema de reglas
init_rules_system() {
    log_rules "INFO" "Inicializando sistema de reglas personalizables..."

    mkdir -p "$RULES_DIR"
    mkdir -p "$RULES_DIR/backup"
    mkdir -p "$RULES_DIR/templates"

    # Crear configuración por defecto si no existe
    if [[ ! -f "$CONFIG_FILE" ]]; then
        create_default_rules
    fi

    log_rules "SUCCESS" "Sistema de reglas inicializado"
}

# Crear reglas por defecto
create_default_rules() {
    log_rules "INFO" "Creando reglas por defecto..."

    cat > "$CONFIG_FILE" << 'EOF'
# ============================================================================
# CONFIGURACIÓN DE REGLAS PERSONALIZABLES - WEBMIN/VIRTUALMIN IDS
# ============================================================================
# Este archivo contiene todas las reglas de detección y respuesta
# Modificar con cuidado - hacer backup antes de cambios
# ============================================================================

# ===== CONFIGURACIÓN GENERAL =====
[RULES_CONFIG]
# Habilitar/deshabilitar reglas personalizadas
custom_rules_enabled=true

# Modo de operación (strict, normal, permissive)
operation_mode=normal

# Archivo de log para reglas personalizadas
custom_rules_log=/etc/webmin-virtualmin-ids/rules/custom_rules.log

# ===== UMBRALES DE DETECCIÓN =====
[THRESHOLDS]
# Ataques SQL Injection
sql_injection_threshold=2
sql_injection_timeframe=300

# Ataques XSS
xss_threshold=2
xss_timeframe=300

# Fuerza bruta
bruteforce_threshold=5
bruteforce_timeframe=600

# Actividad sospechosa
suspicious_activity_threshold=10
suspicious_activity_timeframe=300

# Ataques DDoS
ddos_connections_threshold=1000
ddos_requests_per_minute=500

# Ataques a paneles de control
control_panel_threshold=10
control_panel_timeframe=300

# ===== PATRONES DE DETECCIÓN =====
[PATTERNS]

# Patrones SQL Injection
[SQL_INJECTION_PATTERNS]
patterns=union.*select,select.*from,insert.*into,update.*set,delete.*from,1=1.*,xp_cmdshell,exec.*master,having.*1=1,group.*by.*having,or.*1=1.*--,.*'.*--,.*#.*,benchmark\(,script.*src,load_file\(,into.*outfile

# Patrones XSS
[XSS_PATTERNS]
patterns=<script,<iframe,<object,<embed,javascript:,vbscript:,data:text/html,onload=,onerror=,onclick=,<svg,expression\(,vbscript:,@import

# Patrones de fuerza bruta
[BRUTEFORCE_PATTERNS]
patterns=Failed password,authentication failure,Invalid user,Connection closed by,Bad protocol version,Failed login

# Patrones de escaneo
[SCAN_PATTERNS]
patterns=HEAD /,OPTIONS /,TRACE /,CONNECT /,PUT /,DELETE /,PATCH /,PROPFIND /,MKCOL /,COPY /,MOVE /,LOCK /,UNLOCK /

# ===== ACCIONES DE RESPUESTA =====
[ACTIONS]

# Acción por defecto para amenazas críticas
[CRITICAL_ACTION]
action=block_ip,send_alert,email_admin
ban_time=3600
alert_level=CRITICAL

# Acción por defecto para amenazas altas
[HIGH_ACTION]
action=block_ip,send_alert,log_threat
ban_time=1800
alert_level=HIGH

# Acción por defecto para amenazas medias
[MEDIUM_ACTION]
action=log_threat,send_alert
ban_time=900
alert_level=MEDIUM

# Acción por defecto para amenazas bajas
[LOW_ACTION]
action=log_threat
ban_time=300
alert_level=LOW

# ===== LISTAS BLANCAS/NEGRAS =====
[WHITELIST]
# IPs que nunca deben bloquearse (una por línea)
# Ejemplos:
# 192.168.1.100
# 10.0.0.1

[BLACKLIST]
# IPs que siempre deben bloquearse (una por línea)
# Ejemplos:
# 1.1.1.1
# 8.8.8.8

# ===== REGLAS PERSONALIZADAS =====
[CUSTOM_RULES]
# Ejemplo de regla personalizada:
# rule1_name=SQL Injection Avanzado
# rule1_pattern=union.*select.*from.*information_schema
# rule1_threshold=1
# rule1_action=block_ip,send_alert,email_admin
# rule1_ban_time=7200
# rule1_alert_level=CRITICAL

# ===== CONFIGURACIÓN AVANZADA =====
[ADVANCED]
# Habilitar aprendizaje automático básico
ml_enabled=false

# Archivo de modelo ML (si existe)
ml_model_file=/etc/webmin-virtualmin-ids/rules/ml_model.dat

# Umbral de confianza para ML (0.0-1.0)
ml_confidence_threshold=0.8

# Habilitar correlación de eventos
event_correlation_enabled=true

# Ventana de correlación en segundos
correlation_window=300

# ===== LOGS Y REPORTES =====
[LOGGING]
# Nivel de logging (DEBUG, INFO, WARNING, ERROR)
log_level=INFO

# Rotación de logs (días)
log_rotation_days=30

# Compresión de logs antiguos
log_compression=true

# ===== EXPORTACIÓN/IMPORTACIÓN =====
[EXPORT]
# Formatos soportados: json, yaml, xml
export_format=json

# Archivo de exportación
export_file=/etc/webmin-virtualmin-ids/rules/rules_export.json
EOF

    log_rules "SUCCESS" "Reglas por defecto creadas"
}

# Cargar configuración de reglas
load_rules_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Extraer secciones usando sed/awk
        log_rules "INFO" "Cargando configuración de reglas..."
    else
        log_rules "ERROR" "Archivo de configuración no encontrado: $CONFIG_FILE"
        return 1
    fi
}

# Función para agregar regla personalizada
add_custom_rule() {
    local rule_name="$1"
    local pattern="$2"
    local threshold="${3:-1}"
    local action="${4:-log_threat}"
    local ban_time="${5:-300}"
    local alert_level="${6:-MEDIUM}"

    log_rules "INFO" "Agregando regla personalizada: $rule_name"

    # Verificar que no exista ya
    if grep -q "rule.*_name=$rule_name" "$CONFIG_FILE"; then
        log_rules "ERROR" "La regla '$rule_name' ya existe"
        return 1
    fi

    # Encontrar el número de regla siguiente
    local next_num=1
    while grep -q "rule${next_num}_name=" "$CONFIG_FILE"; do
        ((next_num++))
    done

    # Agregar la regla
    cat >> "$CONFIG_FILE" << EOF

# Regla personalizada agregada el $(date)
rule${next_num}_name=$rule_name
rule${next_num}_pattern=$pattern
rule${next_num}_threshold=$threshold
rule${next_num}_action=$action
rule${next_num}_ban_time=$ban_time
rule${next_num}_alert_level=$alert_level
EOF

    log_rules "SUCCESS" "Regla personalizada '$rule_name' agregada"
}

# Función para eliminar regla personalizada
remove_custom_rule() {
    local rule_name="$1"

    log_rules "INFO" "Eliminando regla personalizada: $rule_name"

    # Crear backup
    cp "$CONFIG_FILE" "$RULES_DIR/backup/rules_backup_$(date +%Y%m%d_%H%M%S).conf"

    # Eliminar la regla (varias líneas)
    sed -i "/rule.*_name=$rule_name/,/^$/d" "$CONFIG_FILE"

    log_rules "SUCCESS" "Regla personalizada '$rule_name' eliminada"
}

# Función para listar reglas
list_rules() {
    echo "=== REGLAS DE DETECCIÓN CONFIGURADAS ==="
    echo ""

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "❌ No hay archivo de configuración"
        return 1
    fi

    echo "📊 UMBRALES:"
    echo "  SQL Injection: $(grep 'sql_injection_threshold' "$CONFIG_FILE" | cut -d'=' -f2)"
    echo "  XSS: $(grep 'xss_threshold' "$CONFIG_FILE" | cut -d'=' -f2)"
    echo "  Fuerza Bruta: $(grep 'bruteforce_threshold' "$CONFIG_FILE" | cut -d'=' -f2)"
    echo "  DDoS: $(grep 'ddos_connections_threshold' "$CONFIG_FILE" | cut -d'=' -f2)"
    echo ""

    echo "🎯 PATRONES DE DETECCIÓN:"
    local sql_patterns=$(grep 'patterns=' "$CONFIG_FILE" | head -1 | cut -d'=' -f2)
    echo "  SQL Injection: ${sql_patterns:0:50}..."
    local xss_patterns=$(grep 'patterns=' "$CONFIG_FILE" | sed -n '2p' | cut -d'=' -f2)
    echo "  XSS: ${xss_patterns:0:50}..."
    echo ""

    echo "⚙️ REGLAS PERSONALIZADAS:"
    local custom_rules=$(grep 'rule.*_name=' "$CONFIG_FILE" | wc -l)
    if [[ $custom_rules -gt 0 ]]; then
        grep 'rule.*_name=' "$CONFIG_FILE" | while read -r line; do
            local rule_name=$(echo "$line" | cut -d'=' -f2)
            echo "  ✅ $rule_name"
        done
    else
        echo "  📝 No hay reglas personalizadas"
    fi
    echo ""

    echo "📋 LISTAS DE CONTROL:"
    local whitelist_count=$(grep -c '^[0-9]' "$CONFIG_FILE" 2>/dev/null || echo "0")
    local blacklist_count=$(grep -A 100 '\[BLACKLIST\]' "$CONFIG_FILE" | grep -c '^[0-9]' 2>/dev/null || echo "0")
    echo "  Whitelist: $whitelist_count IPs"
    echo "  Blacklist: $blacklist_count IPs"
}

# Función para modificar umbral
modify_threshold() {
    local threshold_name="$1"
    local new_value="$2"

    log_rules "INFO" "Modificando umbral $threshold_name = $new_value"

    # Crear backup
    cp "$CONFIG_FILE" "$RULES_DIR/backup/rules_backup_$(date +%Y%m%d_%H%M%S).conf"

    # Modificar el valor
    sed -i "s/$threshold_name=.*/$threshold_name=$new_value/" "$CONFIG_FILE"

    log_rules "SUCCESS" "Umbral modificado: $threshold_name = $new_value"
}

# Función para agregar IP a whitelist
add_to_whitelist() {
    local ip="$1"

    # Validar IP
    if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_rules "ERROR" "IP inválida: $ip"
        return 1
    fi

    log_rules "INFO" "Agregando IP a whitelist: $ip"

    # Verificar si ya existe
    if grep -q "^$ip$" "$CONFIG_FILE"; then
        log_rules "WARNING" "IP ya está en whitelist: $ip"
        return 1
    fi

    # Agregar después de [WHITELIST]
    sed -i "/^\[WHITELIST\]$/a $ip" "$CONFIG_FILE"

    log_rules "SUCCESS" "IP agregada a whitelist: $ip"
}

# Función para agregar IP a blacklist
add_to_blacklist() {
    local ip="$1"

    # Validar IP
    if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_rules "ERROR" "IP inválida: $ip"
        return 1
    fi

    log_rules "INFO" "Agregando IP a blacklist: $ip"

    # Verificar si ya existe
    if grep -A 100 '\[BLACKLIST\]' "$CONFIG_FILE" | grep -q "^$ip$"; then
        log_rules "WARNING" "IP ya está en blacklist: $ip"
        return 1
    fi

    # Agregar después de [BLACKLIST]
    sed -i "/^\[BLACKLIST\]$/a $ip" "$CONFIG_FILE"

    log_rules "SUCCESS" "IP agregada a blacklist: $ip"
}

# Función para exportar reglas
export_rules() {
    local format="${1:-json}"
    local output_file="${2:-$RULES_DIR/rules_export.$format}"

    log_rules "INFO" "Exportando reglas en formato $format..."

    case "$format" in
        "json")
            export_rules_json "$output_file"
            ;;
        "yaml")
            export_rules_yaml "$output_file"
            ;;
        *)
            log_rules "ERROR" "Formato no soportado: $format"
            return 1
            ;;
    esac

    log_rules "SUCCESS" "Reglas exportadas a: $output_file"
}

# Exportar a JSON
export_rules_json() {
    local output_file="$1"

    cat > "$output_file" << EOF
{
  "exported_at": "$(date -Iseconds)",
  "system": "Webmin/Virtualmin IDS",
  "version": "1.0",
  "rules": {
    "thresholds": {
      "sql_injection_threshold": $(grep 'sql_injection_threshold' "$CONFIG_FILE" | cut -d'=' -f2),
      "xss_threshold": $(grep 'xss_threshold' "$CONFIG_FILE" | cut -d'=' -f2),
      "bruteforce_threshold": $(grep 'bruteforce_threshold' "$CONFIG_FILE" | cut -d'=' -f2),
      "ddos_threshold": $(grep 'ddos_connections_threshold' "$CONFIG_FILE" | cut -d'=' -f2)
    },
    "custom_rules": [
EOF

    # Agregar reglas personalizadas
    local first=true
    grep 'rule.*_name=' "$CONFIG_FILE" | while read -r line; do
        local rule_num=$(echo "$line" | sed 's/rule\([0-9]*\)_name=.*/\1/')
        local rule_name=$(echo "$line" | cut -d'=' -f2)

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$output_file"
        fi

        cat >> "$output_file" << EOF
      {
        "name": "$rule_name",
        "pattern": "$(grep "rule${rule_num}_pattern" "$CONFIG_FILE" | cut -d'=' -f2)",
        "threshold": $(grep "rule${rule_num}_threshold" "$CONFIG_FILE" | cut -d'=' -f2),
        "action": "$(grep "rule${rule_num}_action" "$CONFIG_FILE" | cut -d'=' -f2)",
        "ban_time": $(grep "rule${rule_num}_ban_time" "$CONFIG_FILE" | cut -d'=' -f2),
        "alert_level": "$(grep "rule${rule_num}_alert_level" "$CONFIG_FILE" | cut -d'=' -f2)"
      }
EOF
    done

    cat >> "$output_file" << EOF
    ]
  }
}
EOF
}

# Exportar a YAML
export_rules_yaml() {
    local output_file="$1"

    cat > "$output_file" << EOF
---
exported_at: "$(date -Iseconds)"
system: "Webmin/Virtualmin IDS"
version: "1.0"
rules:
  thresholds:
    sql_injection_threshold: $(grep 'sql_injection_threshold' "$CONFIG_FILE" | cut -d'=' -f2)
    xss_threshold: $(grep 'xss_threshold' "$CONFIG_FILE" | cut -d'=' -f2)
    bruteforce_threshold: $(grep 'bruteforce_threshold' "$CONFIG_FILE" | cut -d'=' -f2)
    ddos_threshold: $(grep 'ddos_connections_threshold' "$CONFIG_FILE" | cut -d'=' -f2)
  custom_rules:
EOF

    # Agregar reglas personalizadas
    grep 'rule.*_name=' "$CONFIG_FILE" | while read -r line; do
        local rule_num=$(echo "$line" | sed 's/rule\([0-9]*\)_name=.*/\1/')
        local rule_name=$(echo "$line" | cut -d'=' -f2)

        cat >> "$output_file" << EOF
    - name: "$rule_name"
      pattern: "$(grep "rule${rule_num}_pattern" "$CONFIG_FILE" | cut -d'=' -f2)"
      threshold: $(grep "rule${rule_num}_threshold" "$CONFIG_FILE" | cut -d'=' -f2)
      action: "$(grep "rule${rule_num}_action" "$CONFIG_FILE" | cut -d'=' -f2)"
      ban_time: $(grep "rule${rule_num}_ban_time" "$CONFIG_FILE" | cut -d'=' -f2)
      alert_level: "$(grep "rule${rule_num}_alert_level" "$CONFIG_FILE" | cut -d'=' -f2)"
EOF
    done
}

# Función para importar reglas
import_rules() {
    local input_file="$1"

    log_rules "INFO" "Importando reglas desde: $input_file"

    if [[ ! -f "$input_file" ]]; then
        log_rules "ERROR" "Archivo no encontrado: $input_file"
        return 1
    fi

    # Crear backup
    cp "$CONFIG_FILE" "$RULES_DIR/backup/rules_backup_pre_import_$(date +%Y%m%d_%H%M%S).conf"

    # Detectar formato y importar
    if [[ "$input_file" == *.json ]]; then
        import_rules_json "$input_file"
    elif [[ "$input_file" == *.yaml ]] || [[ "$input_file" == *.yml ]]; then
        import_rules_yaml "$input_file"
    else
        log_rules "ERROR" "Formato no reconocido. Use .json o .yaml"
        return 1
    fi

    log_rules "SUCCESS" "Reglas importadas exitosamente"
}

# Función para validar reglas
validate_rules() {
    log_rules "INFO" "Validando configuración de reglas..."

    local errors=0

    # Verificar umbrales
    local thresholds=("sql_injection_threshold" "xss_threshold" "bruteforce_threshold" "ddos_connections_threshold")
    for threshold in "${thresholds[@]}"; do
        local value=$(grep "$threshold" "$CONFIG_FILE" | cut -d'=' -f2)
        if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -le 0 ]]; then
            log_rules "ERROR" "Umbral inválido: $threshold = $value"
            ((errors++))
        fi
    done

    # Verificar patrones
    if ! grep -q "patterns=" "$CONFIG_FILE"; then
        log_rules "WARNING" "No se encontraron patrones de detección"
    fi

    # Verificar reglas personalizadas
    grep 'rule.*_name=' "$CONFIG_FILE" | while read -r line; do
        local rule_name=$(echo "$line" | cut -d'=' -f2)
        local rule_num=$(echo "$line" | sed 's/rule\([0-9]*\)_name=.*/\1/')

        # Verificar que tenga todos los campos requeridos
        local required_fields=("pattern" "threshold" "action" "ban_time" "alert_level")
        for field in "${required_fields[@]}"; do
            if ! grep -q "rule${rule_num}_$field=" "$CONFIG_FILE"; then
                log_rules "ERROR" "Regla '$rule_name' incompleta: falta $field"
                ((errors++))
            fi
        done
    done

    if [[ $errors -eq 0 ]]; then
        log_rules "SUCCESS" "Configuración de reglas válida"
        return 0
    else
        log_rules "ERROR" "Se encontraron $errors errores en la configuración"
        return 1
    fi
}

# Función principal
main() {
    local action="${1:-status}"

    case "$action" in
        "init")
            init_rules_system
            ;;
        "list")
            list_rules
            ;;
        "add")
            if [[ $# -lt 3 ]]; then
                echo "Uso: $0 add <nombre> <patrón> [umbral] [acción] [tiempo_ban] [nivel_alerta]"
                exit 1
            fi
            add_custom_rule "$2" "$3" "${4:-1}" "${5:-log_threat}" "${6:-300}" "${7:-MEDIUM}"
            ;;
        "remove")
            if [[ $# -lt 2 ]]; then
                echo "Uso: $0 remove <nombre_regla>"
                exit 1
            fi
            remove_custom_rule "$2"
            ;;
        "threshold")
            if [[ $# -lt 3 ]]; then
                echo "Uso: $0 threshold <nombre_umbral> <nuevo_valor>"
                exit 1
            fi
            modify_threshold "$2" "$3"
            ;;
        "whitelist")
            if [[ $# -lt 2 ]]; then
                echo "Uso: $0 whitelist <IP>"
                exit 1
            fi
            add_to_whitelist "$2"
            ;;
        "blacklist")
            if [[ $# -lt 2 ]]; then
                echo "Uso: $0 blacklist <IP>"
                exit 1
            fi
            add_to_blacklist "$2"
            ;;
        "export")
            export_rules "${2:-json}" "${3:-}"
            ;;
        "import")
            if [[ $# -lt 2 ]]; then
                echo "Uso: $0 import <archivo>"
                exit 1
            fi
            import_rules "$2"
            ;;
        "validate")
            validate_rules
            ;;
        "status")
            echo "=== ESTADO DEL GESTOR DE REGLAS ==="
            echo "Directorio: $RULES_DIR"
            echo "Configuración: $CONFIG_FILE"
            echo "Log: $LOG_FILE"
            echo ""

            if [[ -f "$CONFIG_FILE" ]]; then
                local custom_rules=$(grep -c 'rule.*_name=' "$CONFIG_FILE")
                echo "Reglas personalizadas: $custom_rules"
                echo "✅ Sistema operativo"
            else
                echo "❌ Sistema no inicializado - ejecute: $0 init"
            fi
            ;;
        *)
            echo "Gestor de Reglas Personalizables - Webmin/Virtualmin IDS"
            echo ""
            echo "Uso: $0 [acción] [parámetros]"
            echo ""
            echo "Acciones:"
            echo "  init                    - Inicializar sistema"
            echo "  list                    - Listar reglas configuradas"
            echo "  add <nombre> <patrón>  - Agregar regla personalizada"
            echo "  remove <nombre>         - Eliminar regla personalizada"
            echo "  threshold <nombre> <valor> - Modificar umbral"
            echo "  whitelist <IP>          - Agregar IP a whitelist"
            echo "  blacklist <IP>          - Agregar IP a blacklist"
            echo "  export [formato] [archivo] - Exportar reglas (json/yaml)"
            echo "  import <archivo>        - Importar reglas"
            echo "  validate                - Validar configuración"
            echo "  status                  - Mostrar estado del sistema"
            ;;
    esac
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi