#!/bin/bash

# Integración SSL con Virtualmin
# Extiende advanced_ssl_manager.sh para trabajar con Virtualmin

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/advanced_ssl_manager.sh"

# Función para obtener dominios de Virtualmin con más detalles
get_virtualmin_domains() {
    log "Obteniendo dominios detallados de Virtualmin..."
    virtualmin list-domains --multiline | grep -E "(Domain|SSL|Features)" | paste - - - | while read -r line; do
        domain=$(echo "$line" | cut -d: -f2 | tr -d ' ')
        ssl_enabled=$(echo "$line" | grep -o "SSL.*" | cut -d: -f2 | tr -d ' ')
        features=$(echo "$line" | grep -o "Features.*" | cut -d: -f2 | tr -d ' ')

        if [[ $ssl_enabled == "Yes" ]]; then
            echo "$domain:SSL_ENABLED"
        else
            echo "$domain:NO_SSL"
        fi
    done
}

# Función para instalar certificado en Virtualmin
install_ssl_virtualmin() {
    local domain=$1
    local cert_path="/etc/letsencrypt/live/$domain"

    log "Instalando certificado SSL en Virtualmin para $domain"

    if [ -f "$cert_path/fullchain.pem" ] && [ -f "$cert_path/privkey.pem" ]; then
        virtualmin install-cert --domain "$domain" --cert "$cert_path/fullchain.pem" --key "$cert_path/privkey.pem" --ca "$cert_path/chain.pem"

        if [ $? -eq 0 ]; then
            log "Certificado instalado exitosamente en Virtualmin para $domain"
            return 0
        else
            log "ERROR: Falló instalación de certificado en Virtualmin para $domain"
            return 1
        fi
    else
        log "ERROR: Certificados no encontrados para $domain"
        return 1
    fi
}

# Función para verificar estado SSL en Virtualmin
check_ssl_status_virtualmin() {
    log "Verificando estado SSL en Virtualmin..."

    get_virtualmin_domains | while read -r line; do
        domain=$(echo "$line" | cut -d: -f1)
        status=$(echo "$line" | cut -d: -f2)

        if [[ $status == "NO_SSL" ]]; then
            log "ADVERTENCIA: $domain no tiene SSL habilitado"
        else
            log "OK: $domain tiene SSL habilitado"
        fi
    done
}

# Función para renovar certificados usando Virtualmin
renew_ssl_virtualmin() {
    log "Renovando certificados SSL usando Virtualmin..."

    get_virtualmin_domains | while read -r line; do
        domain=$(echo "$line" | cut -d: -f1)
        status=$(echo "$line" | cut -d: -f2)

        if [[ $status == "SSL_ENABLED" ]]; then
            log "Renovando certificado para $domain"
            virtualmin renew-cert --domain "$domain"

            if [ $? -eq 0 ]; then
                log "Certificado renovado exitosamente para $domain"
            else
                log "ERROR: Falló renovación para $domain"
            fi
        fi
    done
}

# Función para configurar SSL automático en nuevos dominios
setup_auto_ssl_virtualmin() {
    log "Configurando SSL automático para nuevos dominios en Virtualmin..."

    # Crear script post-creación de dominio
    cat > /etc/webmin/virtual-server/post-domain-create.pl << 'EOF'
#!/usr/bin/perl
# Script post-creación de dominio para SSL automático

use strict;
use warnings;

my $domain = $ARGV[0];
my $script_path = '/usr/local/bin/advanced_ssl_manager.sh';

# Esperar un momento para que el dominio se configure completamente
sleep(10);

# Ejecutar generación de SSL
system("$script_path generate-domain $domain");

# Instalar certificado en Virtualmin
system("virtualmin_ssl_integration.sh install $domain");

print "SSL configurado automáticamente para $domain\n";
EOF

    chmod +x /etc/webmin/virtual-server/post-domain-create.pl
    log "Script post-creación configurado"
}

# Función principal de integración
main() {
    case "${1:-}" in
        "check")
            check_ssl_status_virtualmin
            ;;
        "renew")
            renew_ssl_virtualmin
            ;;
        "install")
            if [ -n "$2" ]; then
                install_ssl_virtualmin "$2"
            else
                log "Uso: $0 install <domain>"
            fi
            ;;
        "setup-auto")
            setup_auto_ssl_virtualmin
            ;;
        "list")
            get_virtualmin_domains
            ;;
        *)
            log "Uso: $0 {check|renew|install <domain>|setup-auto|list}"
            ;;
    esac
}

# Importar funciones del script principal
source "$MAIN_SCRIPT" 2>/dev/null || log "ADVERTENCIA: No se pudo cargar el script principal"

main "$@"