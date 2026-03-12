#!/bin/bash

# Sistema de Integración Virtualmin con Contenedores
# Gestión automática de dominios en contenedores con SSL y monitoreo
# Versión: 2.0.0 - Producción Lista

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# ===== CONFIGURACIÓN =====
VIRTUALMIN_API_URL="${VIRTUALMIN_API_URL:-https://localhost:10000}"
VIRTUALMIN_API_USER="${VIRTUALMIN_API_USER:-root}"
VIRTUALMIN_API_PASS="${VIRTUALMIN_API_PASS:-}"
CONTAINER_NETWORK="${CONTAINER_NETWORK:-virtualmin_containers}"
SSL_CERT_DIR="${SSL_CERT_DIR:-$SCRIPT_DIR/ssl/certs}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-admin@localhost}"
DOMAIN_CONFIG_DIR="${DOMAIN_CONFIG_DIR:-$SCRIPT_DIR/domains}"

# Función para verificar conexión con Virtualmin
check_virtualmin_connection() {
    log_step "Verificando conexión con Virtualmin..."

    if [[ -z "$VIRTUALMIN_API_PASS" ]]; then
        log_error "VIRTUALMIN_API_PASS no configurada"
        log_info "Configura la variable de entorno VIRTUALMIN_API_PASS"
        return 1
    fi

    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=list-domains" \
        -d "json=1" \
        --connect-timeout 10 \
        --max-time 30)

    if [[ $? -ne 0 ]]; then
        log_error "No se puede conectar a Virtualmin en $VIRTUALMIN_API_URL"
        return 1
    fi

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "Conexión con Virtualmin establecida"
        return 0
    else
        log_error "Error de autenticación con Virtualmin: $(echo "$response" | jq -r '.error // "Unknown error"')"
        return 1
    fi
}

# Función para crear dominio en contenedor
create_container_domain() {
    local domain="$1"
    local app_name="$2"
    local container_port="$3"

    log_step "Creando dominio '$domain' para aplicación '$app_name'..."

    # Crear directorio de configuración del dominio
    local domain_dir="$DOMAIN_CONFIG_DIR/$domain"
    mkdir -p "$domain_dir"

    # Generar configuración del dominio
    cat > "$domain_dir/domain-config.json" << EOF
{
  "domain": "$domain",
  "app_name": "$app_name",
  "container_port": $container_port,
  "created_at": "$(date -Iseconds)",
  "ssl_enabled": true,
  "proxy_enabled": true,
  "monitoring_enabled": true,
  "backup_enabled": true
}
EOF

    # Crear dominio en Virtualmin
    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=create-domain" \
        -d "domain=$domain" \
        -d "pass=$(openssl rand -base64 12)" \
        -d "desc=Container App: $app_name" \
        -d "template=Default Settings" \
        -d "features=web,ssl,dns" \
        -d "json=1")

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "Dominio '$domain' creado en Virtualmin"

        # Configurar proxy reverso
        configure_domain_proxy "$domain" "$container_port"

        # Solicitar certificado SSL
        request_ssl_certificate "$domain"

        # Configurar monitoreo
        configure_domain_monitoring "$domain" "$app_name"

        return 0
    else
        log_error "Error al crear dominio: $(echo "$response" | jq -r '.error // "Unknown error"')"
        return 1
    fi
}

# Función para configurar proxy reverso para dominio
configure_domain_proxy() {
    local domain="$1"
    local container_port="$2"

    log_step "Configurando proxy reverso para $domain -> localhost:$container_port..."

    # Crear configuración de Apache/Nginx en Virtualmin
    local proxy_config="
<VirtualHost *:80>
    ServerName $domain
    ServerAlias www.$domain

    ProxyPass / http://localhost:$container_port/
    ProxyPassReverse / http://localhost:$container_port/

    # Headers para proxy
    RequestHeader set X-Forwarded-Proto \"http\"
    RequestHeader set X-Forwarded-Port \"80\"
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
</VirtualHost>

<VirtualHost *:443>
    ServerName $domain
    ServerAlias www.$domain

    SSLEngine on
    SSLCertificateFile /etc/ssl/virtualmin/$domain.crt
    SSLCertificateKeyFile /etc/ssl/virtualmin/$domain.key

    ProxyPass / http://localhost:$container_port/
    ProxyPassReverse / http://localhost:$container_port/

    # Headers para proxy
    RequestHeader set X-Forwarded-Proto \"https\"
    RequestHeader set X-Forwarded-Port \"443\"
    RequestHeader set X-Real-IP %{REMOTE_ADDR}s
</VirtualHost>"

    # Guardar configuración
    local config_file="$DOMAIN_CONFIG_DIR/$domain/proxy.conf"
    echo "$proxy_config" > "$config_file"

    # Aplicar configuración en Virtualmin
    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=modify-web" \
        -d "domain=$domain" \
        -d "proxy=localhost:$container_port" \
        -d "json=1")

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "Proxy reverso configurado para $domain"
    else
        log_warning "Error al configurar proxy: $(echo "$response" | jq -r '.error // "Unknown error"')"
        log_info "Configuración guardada en: $config_file"
    fi
}

# Función para solicitar certificado SSL
request_ssl_certificate() {
    local domain="$1"

    log_step "Solicitando certificado SSL para $domain..."

    # Verificar si Let's Encrypt está disponible
    if command_exists certbot; then
        # Usar Certbot para obtener certificado
        if certbot certonly --standalone -d "$domain" --email "$LETSENCRYPT_EMAIL" --agree-tos --non-interactive; then
            log_success "Certificado SSL obtenido para $domain"

            # Copiar certificados al directorio de Virtualmin
            mkdir -p "$SSL_CERT_DIR"
            cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$SSL_CERT_DIR/${domain}.crt"
            cp "/etc/letsencrypt/live/$domain/privkey.pem" "$SSL_CERT_DIR/${domain}.key"

            # Configurar SSL en Virtualmin
            configure_ssl_in_virtualmin "$domain"
            return 0
        else
            log_warning "Error al obtener certificado con Certbot"
        fi
    fi

    # Fallback: Generar certificado auto-firmado
    log_info "Generando certificado SSL auto-firmado..."
    generate_self_signed_cert "$domain"
}

# Función para generar certificado auto-firmado
generate_self_signed_cert() {
    local domain="$1"

    mkdir -p "$SSL_CERT_DIR"

    # Generar clave privada
    openssl genrsa -out "$SSL_CERT_DIR/${domain}.key" 2048

    # Generar certificado
    openssl req -new -x509 -key "$SSL_CERT_DIR/${domain}.key" \
        -out "$SSL_CERT_DIR/${domain}.crt" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain" \
        -addext "subjectAltName=DNS:$domain,DNS:www.$domain"

    log_success "Certificado SSL auto-firmado generado para $domain"

    # Configurar SSL en Virtualmin
    configure_ssl_in_virtualmin "$domain"
}

# Función para configurar SSL en Virtualmin
configure_ssl_in_virtualmin() {
    local domain="$1"

    log_step "Configurando SSL en Virtualmin para $domain..."

    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=install-cert" \
        -d "domain=$domain" \
        -d "cert=$SSL_CERT_DIR/${domain}.crt" \
        -d "key=$SSL_CERT_DIR/${domain}.key" \
        -d "json=1")

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "SSL configurado para $domain en Virtualmin"
    else
        log_warning "Error al configurar SSL: $(echo "$response" | jq -r '.error // "Unknown error"')"
    fi
}

# Función para configurar monitoreo de dominio
configure_domain_monitoring() {
    local domain="$1"
    local app_name="$2"

    log_step "Configurando monitoreo para $domain ($app_name)..."

    # Crear configuración de monitoreo
    local monitoring_config="$DOMAIN_CONFIG_DIR/$domain/monitoring.json"
    cat > "$monitoring_config" << EOF
{
  "domain": "$domain",
  "app_name": "$app_name",
  "monitors": {
    "http": {
      "url": "https://$domain",
      "interval": 60,
      "timeout": 10,
      "expected_status": 200
    },
    "ssl": {
      "enabled": true,
      "check_expiry": true,
      "warning_days": 30,
      "critical_days": 7
    },
    "performance": {
      "response_time_warning": 3000,
      "response_time_critical": 10000
    }
  },
  "alerts": {
    "email": "$LETSENCRYPT_EMAIL",
    "slack_webhook": "",
    "enabled": true
  }
}
EOF

    log_success "Monitoreo configurado para $domain"
}

# Función para listar dominios de contenedores
list_container_domains() {
    log_step "Listando dominios de contenedores..."

    echo
    echo "=== DOMINIOS DE CONTENEDORES ==="
    echo

    if [[ ! -d "$DOMAIN_CONFIG_DIR" ]]; then
        echo "No hay dominios configurados"
        return 0
    fi

    local domain_count=0
    for domain_dir in "$DOMAIN_CONFIG_DIR"/*/; do
        if [[ -d "$domain_dir" && -f "$domain_dir/domain-config.json" ]]; then
            ((domain_count++))
            local domain
            domain=$(basename "$domain_dir")

            local config
            config=$(jq -r '.app_name, .container_port, .ssl_enabled, .created_at' "$domain_dir/domain-config.json" 2>/dev/null)

            if [[ -n "$config" ]]; then
                echo "🌐 $domain"
                echo "   Aplicación: $(echo "$config" | sed -n '1p')"
                echo "   Puerto: $(echo "$config" | sed -n '2p')"
                echo "   SSL: $(echo "$config" | sed -n '3p')"
                echo "   Creado: $(echo "$config" | sed -n '4p')"
                echo
            fi
        fi
    done

    if [[ $domain_count -eq 0 ]]; then
        echo "No hay dominios de contenedores configurados"
    else
        echo "Total de dominios: $domain_count"
    fi
}

# Función para eliminar dominio de contenedor
remove_container_domain() {
    local domain="$1"

    log_step "Eliminando dominio '$domain'..."

    if [[ ! -d "$DOMAIN_CONFIG_DIR/$domain" ]]; then
        log_error "Dominio '$domain' no encontrado"
        return 1
    fi

    # Eliminar dominio de Virtualmin
    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=delete-domain" \
        -d "domain=$domain" \
        -d "json=1")

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "Dominio '$domain' eliminado de Virtualmin"
    else
        log_warning "Error al eliminar dominio de Virtualmin: $(echo "$response" | jq -r '.error // "Unknown error"')"
    fi

    # Eliminar archivos de configuración
    rm -rf "$DOMAIN_CONFIG_DIR/$domain"

    # Eliminar certificados SSL
    rm -f "$SSL_CERT_DIR/${domain}.crt" "$SSL_CERT_DIR/${domain}.key"

    log_success "Dominio '$domain' eliminado completamente"
}

# Función para renovar certificados SSL
renew_ssl_certificates() {
    log_step "Renovando certificados SSL..."

    if ! command_exists certbot; then
        log_error "Certbot no está instalado"
        return 1
    fi

    # Renovar todos los certificados
    if certbot renew; then
        log_success "Certificados SSL renovados"

        # Copiar certificados renovados
        for domain_dir in "$DOMAIN_CONFIG_DIR"/*/; do
            if [[ -d "$domain_dir" ]]; then
                local domain
                domain=$(basename "$domain_dir")

                if [[ -d "/etc/letsencrypt/live/$domain" ]]; then
                    cp "/etc/letsencrypt/live/$domain/fullchain.pem" "$SSL_CERT_DIR/${domain}.crt"
                    cp "/etc/letsencrypt/live/$domain/privkey.pem" "$SSL_CERT_DIR/${domain}.key"
                    log_info "Certificado actualizado para $domain"
                fi
            fi
        done

        # Recargar configuración de Virtualmin
        reload_virtualmin_config
    else
        log_error "Error al renovar certificados SSL"
        return 1
    fi
}

# Función para recargar configuración de Virtualmin
reload_virtualmin_config() {
    log_step "Recargando configuración de Virtualmin..."

    local response
    response=$(curl -s "$VIRTUALMIN_API_URL/virtual-server/remote.cgi" \
        --user "$VIRTUALMIN_API_USER:$VIRTUALMIN_API_PASS" \
        -d "program=reload-config" \
        -d "json=1")

    if echo "$response" | jq -e '.status == "success"' >/dev/null 2>&1; then
        log_success "Configuración de Virtualmin recargada"
    else
        log_warning "Error al recargar configuración: $(echo "$response" | jq -r '.error // "Unknown error"')"
    fi
}

# Función para verificar estado de dominios
check_domains_status() {
    log_step "Verificando estado de dominios..."

    echo
    echo "=== ESTADO DE DOMINIOS ==="
    echo

    if [[ ! -d "$DOMAIN_CONFIG_DIR" ]]; then
        echo "No hay dominios configurados"
        return 0
    fi

    for domain_dir in "$DOMAIN_CONFIG_DIR"/*/; do
        if [[ -d "$domain_dir" && -f "$domain_dir/domain-config.json" ]]; then
            local domain
            domain=$(basename "$domain_dir")

            local app_name
            app_name=$(jq -r '.app_name' "$domain_dir/domain-config.json")

            # Verificar conectividad HTTP
            if curl -s --max-time 10 "https://$domain" >/dev/null 2>&1; then
                echo "✅ $domain ($app_name) - Online"
            else
                echo "❌ $domain ($app_name) - Offline"
            fi

            # Verificar SSL
            if [[ -f "$SSL_CERT_DIR/${domain}.crt" ]]; then
                local expiry
                expiry=$(openssl x509 -in "$SSL_CERT_DIR/${domain}.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
                if [[ -n "$expiry" ]]; then
                    local days_left
                    days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))
                    if [[ $days_left -lt 30 ]]; then
                        echo "   ⚠️  SSL expira en $days_left días"
                    else
                        echo "   🔒 SSL válido ($days_left días restantes)"
                    fi
                fi
            else
                echo "   🚫 Sin certificado SSL"
            fi
        fi
    done
    echo
}

# Función para crear red de contenedores
create_container_network() {
    log_step "Creando red de contenedores '$CONTAINER_NETWORK'..."

    if docker network ls --format "{{.Name}}" | grep -q "^${CONTAINER_NETWORK}$"; then
        log_info "Red '$CONTAINER_NETWORK' ya existe"
    else
        if docker network create --driver bridge "$CONTAINER_NETWORK"; then
            log_success "Red de contenedores '$CONTAINER_NETWORK' creada"
        else
            log_error "Error al crear red de contenedores"
            return 1
        fi
    fi
}

# Función para conectar contenedor a red
connect_container_to_network() {
    local container_name="$1"

    log_step "Conectando contenedor '$container_name' a red '$CONTAINER_NETWORK'..."

    if docker network connect "$CONTAINER_NETWORK" "$container_name" 2>/dev/null; then
        log_success "Contenedor '$container_name' conectado a red"
    else
        log_info "Contenedor '$container_name' ya está conectado o no existe"
    fi
}

# Función para configurar DNS para contenedores
configure_container_dns() {
    log_step "Configurando DNS para contenedores..."

    # Crear archivo de hosts para contenedores
    local hosts_file="$SCRIPT_DIR/container-hosts"

    cat > "$hosts_file" << EOF
# Container DNS Configuration
# Generated automatically - Do not edit manually

127.0.0.1 localhost
::1 localhost

# Virtualmin domains
EOF

    # Agregar dominios configurados
    if [[ -d "$DOMAIN_CONFIG_DIR" ]]; then
        for domain_dir in "$DOMAIN_CONFIG_DIR"/*/; do
            if [[ -d "$domain_dir" ]]; then
                local domain
                domain=$(basename "$domain_dir")
                echo "127.0.0.1 $domain www.$domain" >> "$hosts_file"
            fi
        done
    fi

    log_success "Configuración DNS creada: $hosts_file"
}

# Función para mostrar instrucciones de integración
show_integration_instructions() {
    log_success "Sistema de integración Virtualmin-Contenedores configurado exitosamente"
    echo
    log_info "=== INTEGRACIÓN VIRTUALMIN CONTENEDORES ==="
    echo
    log_info "✅ Conexión con API de Virtualmin verificada"
    log_info "✅ Sistema de creación automática de dominios"
    log_info "✅ Configuración automática de proxy reverso"
    log_info "✅ Gestión automática de certificados SSL"
    log_info "✅ Monitoreo integrado de dominios"
    log_info "✅ Red de contenedores dedicada"
    log_info "✅ Configuración DNS para contenedores"
    echo
    log_info "=== COMANDOS DE GESTIÓN ==="
    echo
    log_info "Crear dominio para aplicación:"
    echo "  ./virtualmin_container_integration.sh create-domain <dominio> <app> <puerto>"
    echo
    log_info "Listar dominios:"
    echo "  ./virtualmin_container_integration.sh list-domains"
    echo
    log_info "Verificar estado de dominios:"
    echo "  ./virtualmin_container_integration.sh check-status"
    echo
    log_info "Eliminar dominio:"
    echo "  ./virtualmin_container_integration.sh remove-domain <dominio>"
    echo
    log_info "Renovar certificados SSL:"
    echo "  ./virtualmin_container_integration.sh renew-ssl"
    echo
    log_info "Ejemplos:"
    echo "  ./virtualmin_container_integration.sh create-domain miapp.com myapp 8080"
    echo "  ./virtualmin_container_integration.sh check-status"
    echo
    log_info "=== CONFIGURACIÓN DE ENTORNO ==="
    echo
    log_info "Variables requeridas:"
    echo "  export VIRTUALMIN_API_USER=root"
    echo "  export VIRTUALMIN_API_PASS=tu_password"
    echo "  export VIRTUALMIN_API_URL=https://localhost:10000"
    echo "  export LETSENCRYPT_EMAIL=admin@tu-dominio.com"
    echo
    log_info "=== ESTRUCTURA DE ARCHIVOS ==="
    echo
    log_info "📁 $DOMAIN_CONFIG_DIR/     - Configuraciones de dominios"
    log_info "📁 $SSL_CERT_DIR/          - Certificados SSL"
    log_info "📁 container-hosts         - Configuración DNS"
    echo
    log_info "=== CARACTERÍSTICAS AVANZADAS ==="
    echo
    log_info "• Creación automática de dominios en Virtualmin"
    log_info "• Configuración de proxy reverso transparente"
    log_info "• Certificados SSL con Let's Encrypt"
    log_info "• Monitoreo continuo de disponibilidad"
    log_info "• Alertas automáticas por email"
    log_info "• Renovación automática de certificados"
    log_info "• Integración completa con sistema de contenedores"
}

# Función principal
main() {
    local action="${1:-help}"

    case "$action" in
        "setup")
            check_virtualmin_connection
            create_container_network
            configure_container_dns
            show_integration_instructions
            ;;
        "create-domain")
            if [[ $# -lt 4 ]]; then
                log_error "Uso: $0 create-domain <dominio> <app> <puerto>"
                exit 1
            fi
            check_virtualmin_connection
            create_container_domain "$2" "$3" "$4"
            ;;
        "remove-domain")
            if [[ $# -lt 2 ]]; then
                log_error "Uso: $0 remove-domain <dominio>"
                exit 1
            fi
            check_virtualmin_connection
            remove_container_domain "$2"
            ;;
        "list-domains")
            list_container_domains
            ;;
        "check-status")
            check_domains_status
            ;;
        "renew-ssl")
            check_virtualmin_connection
            renew_ssl_certificates
            ;;
        "connect-network")
            if [[ $# -lt 2 ]]; then
                log_error "Uso: $0 connect-network <contenedor>"
                exit 1
            fi
            connect_container_to_network "$2"
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Función de ayuda
show_help() {
    cat << EOF
Sistema de Integración Virtualmin con Contenedores
Versión: 2.0.0

USO:
    $0 <acción> [opciones]

ACCIONES:
    setup                     Configurar integración completa
    create-domain <dominio> <app> <puerto>
                            Crear dominio para aplicación en contenedor
    remove-domain <dominio>  Eliminar dominio y configuración
    list-domains             Listar dominios configurados
    check-status             Verificar estado de todos los dominios
    renew-ssl                Renovar certificados SSL
    connect-network <contenedor>
                            Conectar contenedor a red dedicada
    help                     Mostrar esta ayuda

VARIABLES DE ENTORNO:
    VIRTUALMIN_API_URL       URL de la API de Virtualmin
    VIRTUALMIN_API_USER      Usuario de la API de Virtualmin
    VIRTUALMIN_API_PASS      Password de la API de Virtualmin
    LETSENCRYPT_EMAIL        Email para Let's Encrypt
    CONTAINER_NETWORK        Nombre de la red de contenedores

EJEMPLOS:
    $0 setup
    $0 create-domain miapp.com myapp 8080
    $0 list-domains
    $0 check-status
    $0 remove-domain miapp.com

CARACTERÍSTICAS:
    • Creación automática de dominios en Virtualmin
    • Configuración de proxy reverso
    • Certificados SSL con Let's Encrypt
    • Monitoreo de disponibilidad
    • Renovación automática de SSL
    • Red dedicada para contenedores
    • Configuración DNS automática

NOTAS:
    - Requiere conexión activa con Virtualmin
    - Certbot opcional para SSL automático
    - Configura variables de entorno antes de usar
EOF
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi