#!/bin/bash

# Sistema Avanzado de Encriptación y Gestión de Certificados para Webmin/Virtualmin
# Funcionalidades: Generación automática SSL/TLS con Let's Encrypt, renovación automática,
# gestión wildcard, encriptación de datos, rotación de claves, validación, dashboard

set -e

# Configuración
LOG_FILE="/var/log/advanced_ssl_manager.log"
CERT_DIR="/etc/letsencrypt/live"
WEBROOT_DIR="/var/www/html"
DASHBOARD_DIR="/var/www/html/ssl_dashboard"
ENCRYPTED_DATA_DIR="/etc/ssl/private/encrypted"
KEY_ROTATION_DAYS=90
VALIDATION_INTERVAL=3600  # 1 hora

# Función de logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Función para verificar dependencias
check_dependencies() {
    log "Verificando dependencias..."
    command -v certbot >/dev/null 2>&1 || { log "ERROR: certbot no instalado"; exit 1; }
    command -v openssl >/dev/null 2>&1 || { log "ERROR: openssl no instalado"; exit 1; }
    command -v virtualmin >/dev/null 2>&1 || { log "ERROR: virtualmin no instalado"; exit 1; }
    log "Dependencias verificadas correctamente"
}

# Función para obtener dominios de Virtualmin
get_domains() {
    log "Obteniendo lista de dominios de Virtualmin..."
    virtualmin list-domains --name-only | grep -v "Domain" || echo ""
}

# Función para generar certificado SSL/TLS
generate_ssl_cert() {
    local domain=$1
    local is_wildcard=$2

    log "Generando certificado SSL para $domain (wildcard: $is_wildcard)"

    if [ "$is_wildcard" = "true" ]; then
        # Para wildcard, usar DNS challenge (requiere configuración DNS)
        certbot certonly --manual --preferred-challenges dns -d "*.$domain" -d "$domain" --agree-tos --email admin@$domain --manual-public-ip-logging-ok
    else
        # Para dominio normal, usar webroot
        certbot certonly --webroot -w "$WEBROOT_DIR" -d "$domain" --agree-tos --email admin@$domain
    fi

    if [ $? -eq 0 ]; then
        log "Certificado generado exitosamente para $domain"
        return 0
    else
        log "ERROR: Falló generación de certificado para $domain"
        return 1
    fi
}

# Función para renovar certificados
renew_certificates() {
    log "Verificando renovación de certificados..."
    certbot renew --quiet

    if [ $? -eq 0 ]; then
        log "Renovación completada exitosamente"
        reload_services
    else
        log "ERROR: Falló renovación de certificados"
    fi
}

# Función para recargar servicios
reload_services() {
    log "Recargando servicios..."
    systemctl reload apache2 2>/dev/null || service apache2 reload 2>/dev/null || true
    systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
    systemctl reload webmin 2>/dev/null || service webmin reload 2>/dev/null || true
    log "Servicios recargados"
}

# Función para encriptar datos sensibles
encrypt_sensitive_data() {
    local file=$1
    local encrypted_file="$ENCRYPTED_DATA_DIR/$(basename "$file").enc"

    log "Encriptando $file"
    openssl enc -aes-256-cbc -salt -in "$file" -out "$encrypted_file" -k "$(openssl rand -base64 32)"
    chmod 600 "$encrypted_file"
    log "Archivo encriptado: $encrypted_file"
}

# Función para desencriptar datos
decrypt_sensitive_data() {
    local encrypted_file=$1
    local output_file="${encrypted_file%.enc}"

    log "Desencriptando $encrypted_file"
    openssl enc -d -aes-256-cbc -in "$encrypted_file" -out "$output_file" -k "$(openssl rand -base64 32)"
    log "Archivo desencriptado: $output_file"
}

# Función para rotación de claves
rotate_keys() {
    log "Verificando rotación de claves..."

    find "$CERT_DIR" -name "privkey.pem" -mtime +$KEY_ROTATION_DAYS -exec dirname {} \; | while read -r cert_path; do
        domain=$(basename "$cert_path")
        log "Rotando clave para $domain"

        # Generar nueva clave privada
        openssl genrsa -out "$cert_path/privkey_new.pem" 2048
        chmod 600 "$cert_path/privkey_new.pem"

        # Copiar clave antigua como backup
        cp "$cert_path/privkey.pem" "$cert_path/privkey_old.pem"

        # Reemplazar clave
        mv "$cert_path/privkey_new.pem" "$cert_path/privkey.pem"

        # Regenerar certificado con nueva clave
        generate_ssl_cert "$domain" "false"

        log "Clave rotada para $domain"
    done
}

# Función para validar certificados
validate_certificates() {
    log "Validando certificados..."

    find "$CERT_DIR" -name "cert.pem" -exec openssl x509 -in {} -checkend 2592000 \; -print | while read -r line; do
        if [[ $line == *"will expire"* ]]; then
            cert_path=$(echo "$line" | cut -d: -f1)
            domain=$(basename "$(dirname "$cert_path")")
            log "ADVERTENCIA: Certificado para $domain expira en menos de 30 días"
        fi
    done
}

# Función para crear dashboard web
create_dashboard() {
    log "Creando dashboard web..."

    mkdir -p "$DASHBOARD_DIR"

    cat > "$DASHBOARD_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard SSL - Webmin/Virtualmin</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .cert-item { border: 1px solid #ccc; padding: 10px; margin: 10px 0; }
        .valid { color: green; }
        .expiring { color: orange; }
        .expired { color: red; }
    </style>
</head>
<body>
    <h1>Dashboard de Monitoreo SSL/TLS</h1>
    <div id="certificates"></div>

    <script>
        async function loadCertificates() {
            try {
                const response = await fetch('/ssl_dashboard/api/certificates');
                const data = await response.json();
                displayCertificates(data);
            } catch (error) {
                console.error('Error cargando certificados:', error);
            }
        }

        function displayCertificates(certs) {
            const container = document.getElementById('certificates');
            container.innerHTML = '';

            certs.forEach(cert => {
                const div = document.createElement('div');
                div.className = 'cert-item ' + getStatusClass(cert.daysUntilExpiry);
                div.innerHTML = `
                    <h3>${cert.domain}</h3>
                    <p>Expira: ${cert.expiryDate}</p>
                    <p>Días restantes: ${cert.daysUntilExpiry}</p>
                    <p>Estado: ${cert.status}</p>
                `;
                container.appendChild(div);
            });
        }

        function getStatusClass(days) {
            if (days < 0) return 'expired';
            if (days < 30) return 'expiring';
            return 'valid';
        }

        loadCertificates();
        setInterval(loadCertificates, 300000); // Actualizar cada 5 minutos
    </script>
</body>
</html>
EOF

    # Crear API simple para datos de certificados
    cat > "$DASHBOARD_DIR/api_certificates.sh" << 'EOF'
#!/bin/bash
echo "Content-Type: application/json"
echo ""

certificates=()

for cert_dir in /etc/letsencrypt/live/*/; do
    if [ -d "$cert_dir" ]; then
        domain=$(basename "$cert_dir")
        cert_file="$cert_dir/cert.pem"

        if [ -f "$cert_file" ]; then
            expiry_date=$(openssl x509 -in "$cert_file" -enddate -noout | cut -d= -f2)
            expiry_epoch=$(date -d "$expiry_date" +%s)
            current_epoch=$(date +%s)
            days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

            if [ $days_until_expiry -lt 0 ]; then
                status="Expirado"
            elif [ $days_until_expiry -lt 30 ]; then
                status="Expira pronto"
            else
                status="Válido"
            fi

            certificates+=("{\"domain\":\"$domain\",\"expiryDate\":\"$expiry_date\",\"daysUntilExpiry\":$days_until_expiry,\"status\":\"$status\"}")
        fi
    fi
done

echo "[${certificates[*]}]"
EOF

    chmod +x "$DASHBOARD_DIR/api_certificates.sh"

    log "Dashboard creado en $DASHBOARD_DIR"
}

# Función principal
main() {
    log "Iniciando Sistema Avanzado de SSL Manager"

    check_dependencies

    # Crear directorios necesarios
    mkdir -p "$ENCRYPTED_DATA_DIR"

    # Procesar argumentos
    case "${1:-}" in
        "generate")
            domains=$(get_domains)
            for domain in $domains; do
                # Detectar si es wildcard (simplificado)
                if [[ $domain == *"*."* ]]; then
                    generate_ssl_cert "$domain" "true"
                else
                    generate_ssl_cert "$domain" "false"
                fi
            done
            ;;
        "renew")
            renew_certificates
            ;;
        "rotate")
            rotate_keys
            ;;
        "validate")
            validate_certificates
            ;;
        "dashboard")
            create_dashboard
            ;;
        "encrypt")
            if [ -n "$2" ]; then
                encrypt_sensitive_data "$2"
            else
                log "Uso: $0 encrypt <archivo>"
            fi
            ;;
        "decrypt")
            if [ -n "$2" ]; then
                decrypt_sensitive_data "$2"
            else
                log "Uso: $0 decrypt <archivo_encriptado>"
            fi
            ;;
        *)
            log "Uso: $0 {generate|renew|rotate|validate|dashboard|encrypt <file>|decrypt <file>}"
            ;;
    esac

    log "Sistema SSL Manager completado"
}

main "$@"