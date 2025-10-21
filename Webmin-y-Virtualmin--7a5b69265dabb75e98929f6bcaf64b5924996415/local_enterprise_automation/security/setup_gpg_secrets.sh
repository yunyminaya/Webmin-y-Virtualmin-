#!/bin/bash

# Script de instalación y configuración de gestión de secretos con GPG para Virtualmin Enterprise
# Este script instala y configura un sistema de gestión de secretos cifrados con GPG

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-gpg.log"
CONFIG_DIR="/opt/virtualmin-enterprise/config/secrets"
SECRETS_DIR="/opt/virtualmin-enterprise/secrets"
GPG_KEY_ID="virtualmin-enterprise@$(hostname -f)"

# Función para imprimir mensajes con colores
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Función para registrar mensajes en el log
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para verificar si el script se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Este script debe ejecutarse como root" >&2
        exit 1
    fi
}

# Función para detectar distribución del sistema operativo
detect_distribution() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# Función para instalar dependencias
install_dependencies() {
    log_message "Instalando dependencias"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            apt-get update
            apt-get install -y \
                gnupg \
                gnupg2 \
                gpg \
                gpg-agent \
                pinentry-curses \
                pinentry-tty \
                haveged \
                rng-tools \
                python3 \
                python3-pip \
                python3-gpg \
                libgpgme-dev \
                gpgmepp-dev
            ;;
        "redhat")
            yum update -y
            yum install -y \
                gnupg \
                gnupg2 \
                gpg \
                gpg-agent \
                pinentry-curses \
                pinentry-tty \
                haveged \
                rng-tools \
                python3 \
                python3-pip \
                python3-gpg \
                gpgme-devel
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    log_message "Dependencias instaladas"
}

# Función para configurar GPG
configure_gpg() {
    log_message "Configurando GPG"
    
    # Crear directorios necesarios
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SECRETS_DIR"
    mkdir -p "/root/.gnupg"
    
    # Configurar permisos
    chmod 700 "/root/.gnupg"
    chmod 700 "$CONFIG_DIR"
    chmod 700 "$SECRETS_DIR"
    
    # Crear archivo de configuración de GPG
    cat > "/root/.gnupg/gpg.conf" << 'EOF'
# Configuración de GPG para Virtualmin Enterprise

# Preferir algoritmos seguros
personal-digest-preferences SHA512 SHA384 SHA256 SHA224
personal-cipher-preferences AES256 AES192 AES128 CAST5
default-keyserver hkp://pool.sks-keyservers.net
keyserver-options timeout=10
cert-digest-algo SHA512
s2k-digest-algo SHA512
s2k-cipher-algo AES256
charset utf-8
fixed-list-mode no
no-comments
no-emit-version
keyid-format 0xlong
list-options show-uid-validity
verify-options show-uid-validity
with-fingerprint
use-agent
EOF
    
    # Crear archivo de configuración de gpg-agent
    cat > "/root/.gnupg/gpg-agent.conf" << 'EOF'
# Configuración de gpg-agent para Virtualmin Enterprise

default-cache-ttl 3600
max-cache-ttl 7200
pinentry-program /usr/bin/pinentry-curses
allow-loopback-pinentry
EOF
    
    # Iniciar gpg-agent
    gpgconf --launch gpg-agent >> "$LOG_FILE" 2>&1
    
    log_message "GPG configurado"
    print_message $GREEN "GPG configurado"
}

# Función para generar clave GPG
generate_gpg_key() {
    log_message "Generando clave GPG"
    
    # Verificar si ya existe una clave
    if gpg --list-keys | grep -q "$GPG_KEY_ID"; then
        log_message "La clave GPG ya existe"
        print_message $YELLOW "La clave GPG ya existe"
        return
    fi
    
    # Generar clave GPG
    cat > "$CONFIG_DIR/gpg-key-config" << EOF
%echo Generating GPG key for Virtualmin Enterprise
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Virtualmin Enterprise
Name-Email: $GPG_KEY_ID
Expire-Date: 5y
%no-protection
%commit
%echo done
EOF
    
    # Generar clave
    gpg --batch --generate-key "$CONFIG_DIR/gpg-key-config" >> "$LOG_FILE" 2>&1
    
    # Limpiar archivo de configuración
    rm "$CONFIG_DIR/gpg-key-config"
    
    # Obtener ID de la clave
    local key_id=$(gpg --list-keys --with-colons "$GPG_KEY_ID" | grep "^pub:" | cut -d: -f5)
    
    if [ -n "$key_id" ]; then
        # Guardar ID de la clave
        echo "$key_id" > "$CONFIG_DIR/gpg-key-id"
        
        # Exportar clave pública
        gpg --armor --export "$key_id" > "$CONFIG_DIR/public-key.asc"
        
        # Establecer confianza en la clave
        echo "$key_id:6:" | gpg --import-ownertrust >> "$LOG_FILE" 2>&1
        
        log_message "Clave GPG generada: $key_id"
        print_message $GREEN "Clave GPG generada: $key_id"
    else
        log_message "ERROR: Falló la generación de clave GPG"
        print_message $RED "ERROR: Falló la generación de clave GPG"
        exit 1
    fi
}

# Función para crear script de gestión de secretos
create_management_script() {
    log_message "Creando script de gestión de secretos"
    
    cat > "$INSTALL_DIR/scripts/manage_secrets.sh" << 'EOF'
#!/bin/bash

# Script de gestión de secretos cifrados con GPG para Virtualmin Enterprise

CONFIG_DIR="/opt/virtualmin-enterprise/config/secrets"
SECRETS_DIR="/opt/virtualmin-enterprise/secrets"
LOG_FILE="/var/log/virtualmin-enterprise-gpg.log"

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para obtener ID de clave GPG
get_gpg_key_id() {
    if [ -f "$CONFIG_DIR/gpg-key-id" ]; then
        cat "$CONFIG_DIR/gpg-key-id"
    else
        echo "ERROR: No se encontró ID de clave GPG"
        return 1
    fi
}

# Función para cifrar un secreto
encrypt_secret() {
    local secret_name=$1
    local secret_value=$2
    
    if [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
        echo "Error: Se requiere nombre y valor del secreto"
        return 1
    fi
    
    log_message "Cifrando secreto: $secret_name"
    
    # Obtener ID de clave GPG
    local key_id=$(get_gpg_key_id)
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Cifrar secreto
    echo "$secret_value" | gpg --batch --yes --encrypt --armor --recipient "$key_id" > "$SECRETS_DIR/$secret_name.gpg"
    
    if [ $? -eq 0 ]; then
        echo "Secreto cifrado: $secret_name"
        log_message "Secreto cifrado: $secret_name"
    else
        echo "Error al cifrar secreto: $secret_name"
        log_message "Error al cifrar secreto: $secret_name"
        return 1
    fi
}

# Función para descifrar un secreto
decrypt_secret() {
    local secret_name=$1
    
    if [ -z "$secret_name" ]; then
        echo "Error: Se requiere nombre del secreto"
        return 1
    fi
    
    if [ ! -f "$SECRETS_DIR/$secret_name.gpg" ]; then
        echo "Error: No existe el secreto: $secret_name"
        return 1
    fi
    
    log_message "Descifrando secreto: $secret_name"
    
    # Descifrar secreto
    gpg --batch --yes --decrypt "$SECRETS_DIR/$secret_name.gpg" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "Secreto descifrado: $secret_name"
    else
        echo "Error al descifrar secreto: $secret_name"
        log_message "Error al descifrar secreto: $secret_name"
        return 1
    fi
}

# Función para listar secretos
list_secrets() {
    echo "Secretos cifrados:"
    
    if [ -d "$SECRETS_DIR" ] && [ "$(ls -A $SECRETS_DIR)" ]; then
        for secret_file in "$SECRETS_DIR"/*.gpg; do
            if [ -f "$secret_file" ]; then
                local secret_name=$(basename "$secret_file" .gpg)
                echo "- $secret_name"
            fi
        done
    else
        echo "No hay secretos cifrados"
    fi
}

# Función para eliminar un secreto
delete_secret() {
    local secret_name=$1
    
    if [ -z "$secret_name" ]; then
        echo "Error: Se requiere nombre del secreto"
        return 1
    fi
    
    if [ ! -f "$SECRETS_DIR/$secret_name.gpg" ]; then
        echo "Error: No existe el secreto: $secret_name"
        return 1
    fi
    
    # Hacer backup del secreto
    cp "$SECRETS_DIR/$secret_name.gpg" "$SECRETS_DIR/$secret_name.gpg.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Eliminar secreto
    rm "$SECRETS_DIR/$secret_name.gpg"
    
    echo "Secreto eliminado: $secret_name"
    log_message "Secreto eliminado: $secret_name"
}

# Función para renombrar un secreto
rename_secret() {
    local old_name=$1
    local new_name=$2
    
    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        echo "Error: Se requieren nombre antiguo y nuevo del secreto"
        return 1
    fi
    
    if [ ! -f "$SECRETS_DIR/$old_name.gpg" ]; then
        echo "Error: No existe el secreto: $old_name"
        return 1
    fi
    
    if [ -f "$SECRETS_DIR/$new_name.gpg" ]; then
        echo "Error: Ya existe el secreto: $new_name"
        return 1
    fi
    
    # Renombrar secreto
    mv "$SECRETS_DIR/$old_name.gpg" "$SECRETS_DIR/$new_name.gpg"
    
    echo "Secreto renombrado: $old_name -> $new_name"
    log_message "Secreto renombrado: $old_name -> $new_name"
}

# Función para exportar un secreto a un archivo
export_secret() {
    local secret_name=$1
    local output_file=$2
    
    if [ -z "$secret_name" ] || [ -z "$output_file" ]; then
        echo "Error: Se requiere nombre del secreto y archivo de salida"
        return 1
    fi
    
    if [ ! -f "$SECRETS_DIR/$secret_name.gpg" ]; then
        echo "Error: No existe el secreto: $secret_name"
        return 1
    fi
    
    # Descifrar secreto y exportar a archivo
    decrypt_secret "$secret_name" > "$output_file"
    
    if [ $? -eq 0 ]; then
        echo "Secreto exportado: $secret_name -> $output_file"
        log_message "Secreto exportado: $secret_name -> $output_file"
        
        # Establecer permisos seguros
        chmod 600 "$output_file"
    else
        echo "Error al exportar secreto: $secret_name"
        return 1
    fi
}

# Función para importar un secreto desde un archivo
import_secret() {
    local secret_name=$1
    local input_file=$2
    
    if [ -z "$secret_name" ] || [ -z "$input_file" ]; then
        echo "Error: Se requiere nombre del secreto y archivo de entrada"
        return 1
    fi
    
    if [ ! -f "$input_file" ]; then
        echo "Error: No existe el archivo: $input_file"
        return 1
    fi
    
    # Leer valor del secreto
    local secret_value=$(cat "$input_file")
    
    # Cifrar secreto
    encrypt_secret "$secret_name" "$secret_value"
}

# Función para generar un secreto aleatorio
generate_random_secret() {
    local secret_name=$1
    local length=${2:-32}
    
    if [ -z "$secret_name" ]; then
        echo "Error: Se requiere nombre del secreto"
        return 1
    fi
    
    # Generar secreto aleatorio
    local secret_value=$(openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length)
    
    # Cifrar secreto
    encrypt_secret "$secret_name" "$secret_value"
    
    if [ $? -eq 0 ]; then
        echo "Secreto aleatorio generado: $secret_name"
        echo "Valor: $secret_value"
        echo "ADVERTENCIA: Este es el único momento en que se muestra el valor del secreto. Guárdelo en un lugar seguro."
    fi
}

# Función para generar una contraseña segura
generate_secure_password() {
    local secret_name=$1
    local length=${2:-16}
    
    if [ -z "$secret_name" ]; then
        echo "Error: Se requiere nombre del secreto"
        return 1
    fi
    
    # Generar contraseña segura
    local password=$(openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length)
    
    # Asegurar que la contraseña contenga mayúsculas, minúsculas, números y caracteres especiales
    if [[ ! "$password" =~ [A-Z] ]]; then
        password="${password:0:-1}$(tr -dc 'A-Z' < /dev/urandom | head -c 1)"
    fi
    
    if [[ ! "$password" =~ [a-z] ]]; then
        password="${password:0:-1}$(tr -dc 'a-z' < /dev/urandom | head -c 1)"
    fi
    
    if [[ ! "$password" =~ [0-9] ]]; then
        password="${password:0:-1}$(tr -dc '0-9' < /dev/urandom | head -c 1)"
    fi
    
    if [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        password="${password:0:-1}$(tr -dc '!@#$%^&*()_+-=' < /dev/urandom | head -c 1)"
    fi
    
    # Cifrar contraseña
    encrypt_secret "$secret_name" "$password"
    
    if [ $? -eq 0 ]; then
        echo "Contraseña segura generada: $secret_name"
        echo "Contraseña: $password"
        echo "ADVERTENCIA: Esta es la única ocasión en que se muestra la contraseña. Guárdela en un lugar seguro."
    fi
}

# Función para backup de secretos
backup_secrets() {
    local backup_dir=$1
    
    if [ -z "$backup_dir" ]; then
        backup_dir="/opt/virtualmin-enterprise/backups/secrets-$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Crear directorio de backup
    mkdir -p "$backup_dir"
    
    # Copiar secretos
    if [ -d "$SECRETS_DIR" ] && [ "$(ls -A $SECRETS_DIR)" ]; then
        cp -r "$SECRETS_DIR"/* "$backup_dir/"
        
        # Copiar clave pública
        if [ -f "$CONFIG_DIR/public-key.asc" ]; then
            cp "$CONFIG_DIR/public-key.asc" "$backup_dir/"
        fi
        
        # Copiar archivo de configuración
        if [ -f "$CONFIG_DIR/gpg-key-id" ]; then
            cp "$CONFIG_DIR/gpg-key-id" "$backup_dir/"
        fi
        
        echo "Backup de secretos creado en: $backup_dir"
        log_message "Backup de secretos creado en: $backup_dir"
    else
        echo "No hay secretos para hacer backup"
    fi
}

# Función para restaurar secretos desde backup
restore_secrets() {
    local backup_dir=$1
    
    if [ -z "$backup_dir" ]; then
        echo "Error: Se requiere directorio de backup"
        return 1
    fi
    
    if [ ! -d "$backup_dir" ]; then
        echo "Error: No existe el directorio de backup: $backup_dir"
        return 1
    fi
    
    # Restaurar secretos
    if [ -d "$backup_dir" ] && [ "$(ls -A $backup_dir)" ]; then
        cp -r "$backup_dir"/* "$SECRETS_DIR/"
        
        echo "Secretos restaurados desde: $backup_dir"
        log_message "Secretos restaurados desde: $backup_dir"
    else
        echo "El directorio de backup está vacío: $backup_dir"
    fi
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  encrypt_secret <NOMBRE> <VALOR>     Cifrar un secreto"
    echo "  decrypt_secret <NOMBRE>             Descifrar un secreto"
    echo "  list_secrets                       Listar todos los secretos"
    echo "  delete_secret <NOMBRE>             Eliminar un secreto"
    echo "  rename_secret <NOMBRE_ANTIGUO> <NOMBRE_NUEVO>  Renombrar un secreto"
    echo "  export_secret <NOMBRE> <ARCHIVO>    Exportar un secreto a un archivo"
    echo "  import_secret <NOMBRE> <ARCHIVO>    Importar un secreto desde un archivo"
    echo "  generate_random_secret <NOMBRE> [LONGITUD]  Generar un secreto aleatorio"
    echo "  generate_secure_password <NOMBRE> [LONGITUD]  Generar una contraseña segura"
    echo "  backup_secrets [DIRECTORIO]         Hacer backup de secretos"
    echo "  restore_secrets <DIRECTORIO>        Restaurar secretos desde backup"
    echo "  show_help                          Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 encrypt_secret db_password \"my_secure_password\""
    echo "  $0 decrypt_secret db_password"
    echo "  $0 list_secrets"
    echo "  $0 delete_secret db_password"
    echo "  $0 rename_secret db_password new_db_password"
    echo "  $0 export_secret db_password /tmp/db_password.txt"
    echo "  $0 import_secret db_password /tmp/db_password.txt"
    echo "  $0 generate_random_secret api_key 64"
    echo "  $0 generate_secure_password admin_password 20"
    echo "  $0 backup_secrets"
    echo "  $0 restore_secrets /opt/virtualmin-enterprise/backups/secrets-20230101_120000"
}

# Procesar argumentos
case "$1" in
    "encrypt_secret")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requiere nombre y valor del secreto"
            show_help
            exit 1
        fi
        encrypt_secret "$2" "$3"
        ;;
    "decrypt_secret")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre del secreto"
            show_help
            exit 1
        fi
        decrypt_secret "$2"
        ;;
    "list_secrets")
        list_secrets
        ;;
    "delete_secret")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre del secreto"
            show_help
            exit 1
        fi
        delete_secret "$2"
        ;;
    "rename_secret")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requieren nombre antiguo y nuevo del secreto"
            show_help
            exit 1
        fi
        rename_secret "$2" "$3"
        ;;
    "export_secret")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requiere nombre del secreto y archivo de salida"
            show_help
            exit 1
        fi
        export_secret "$2" "$3"
        ;;
    "import_secret")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requiere nombre del secreto y archivo de entrada"
            show_help
            exit 1
        fi
        import_secret "$2" "$3"
        ;;
    "generate_random_secret")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre del secreto"
            show_help
            exit 1
        fi
        generate_random_secret "$2" "$3"
        ;;
    "generate_secure_password")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre del secreto"
            show_help
            exit 1
        fi
        generate_secure_password "$2" "$3"
        ;;
    "backup_secrets")
        backup_secrets "$2"
        ;;
    "restore_secrets")
        if [ -z "$2" ]; then
            echo "Error: Se requiere directorio de backup"
            show_help
            exit 1
        fi
        restore_secrets "$2"
        ;;
    "show_help"|*)
        show_help
        ;;
esac
EOF
    
    # Hacer ejecutable el script
    chmod +x "$INSTALL_DIR/scripts/manage_secrets.sh"
    
    log_message "Script de gestión de secretos creado"
    print_message $GREEN "Script de gestión de secretos creado"
}

# Función para crear script de integración con Virtualmin
create_integration_script() {
    log_message "Creando script de integración con Virtualmin"
    
    cat > "$INSTALL_DIR/scripts/integrate_secrets_virtualmin.sh" << 'EOF'
#!/bin/bash

# Script de integración de gestión de secretos con Virtualmin

SECRETS_SCRIPT="/opt/virtualmin-enterprise/scripts/manage_secrets.sh"
LOG_FILE="/var/log/virtualmin-enterprise-secrets-integration.log"

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para generar y cifrar contraseña de base de datos
setup_database_password() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo "Error: Se requiere nombre de dominio"
        return 1
    fi
    
    log_message "Configurando contraseña de base de datos para $domain"
    
    # Generar contraseña segura
    local db_password_name="db_password_$domain"
    $SECRETS_SCRIPT generate_secure_password "$db_password_name" 20
    
    if [ $? -eq 0 ]; then
        # Obtener contraseña
        local db_password=$($SECRETS_SCRIPT decrypt_secret "$db_password_name")
        
        # Configurar contraseña en Virtualmin
        virtualmin set-database --domain "$domain" --pass "$db_password" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            echo "Contraseña de base de datos configurada para $domain"
            log_message "Contraseña de base de datos configurada para $domain"
        else
            echo "Error al configurar contraseña de base de datos para $domain"
            log_message "Error al configurar contraseña de base de datos para $domain"
        fi
    else
        echo "Error al generar contraseña de base de datos para $domain"
        log_message "Error al generar contraseña de base de datos para $domain"
    fi
}

# Función para generar y cifrar clave API
setup_api_key() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo "Error: Se requiere nombre de dominio"
        return 1
    fi
    
    log_message "Configurando clave API para $domain"
    
    # Generar clave API
    local api_key_name="api_key_$domain"
    $SECRETS_SCRIPT generate_random_secret "$api_key_name" 64
    
    if [ $? -eq 0 ]; then
        echo "Clave API configurada para $domain"
        log_message "Clave API configurada para $domain"
    else
        echo "Error al generar clave API para $domain"
        log_message "Error al generar clave API para $domain"
    fi
}

# Función para configurar SSL/TLS
setup_ssl_certificate() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo "Error: Se requiere nombre de dominio"
        return 1
    fi
    
    log_message "Configurando certificado SSL/TLS para $domain"
    
    # Generar clave privada
    local ssl_key_name="ssl_key_$domain"
    $SECRETS_SCRIPT generate_random_secret "$ssl_key_name" 4096
    
    if [ $? -eq 0 ]; then
        # Obtener clave privada
        local ssl_key=$($SECRETS_SCRIPT decrypt_secret "$ssl_key_name")
        
        # Guardar clave privada en archivo
        echo "$ssl_key" > "/etc/ssl/private/$domain.key"
        chmod 600 "/etc/ssl/private/$domain.key"
        
        # Generar CSR
        openssl req -new -key "/etc/ssl/private/$domain.key" -out "/etc/ssl/certs/$domain.csr" -subj "/C=US/ST=State/L=City/O=Organization/CN=$domain" >> "$LOG_FILE" 2>&1
        
        # Configurar SSL en Virtualmin
        virtualmin set-ssl --domain "$domain" --key "/etc/ssl/private/$domain.key" --csr "/etc/ssl/certs/$domain.csr" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            echo "Certificado SSL/TLS configurado para $domain"
            log_message "Certificado SSL/TLS configurado para $domain"
        else
            echo "Error al configurar certificado SSL/TLS para $domain"
            log_message "Error al configurar certificado SSL/TLS para $domain"
        fi
    else
        echo "Error al generar clave privada SSL/TLS para $domain"
        log_message "Error al generar clave privada SSL/TLS para $domain"
    fi
}

# Función para configurar todos los secretos para un dominio
setup_domain_secrets() {
    local domain=$1
    
    if [ -z "$domain" ]; then
        echo "Error: Se requiere nombre de dominio"
        return 1
    fi
    
    echo "Configurando secretos para dominio: $domain"
    
    # Configurar contraseña de base de datos
    setup_database_password "$domain"
    
    # Configurar clave API
    setup_api_key "$domain"
    
    # Configurar certificado SSL/TLS
    setup_ssl_certificate "$domain"
    
    echo "Secretos configurados para dominio: $domain"
    log_message "Secretos configurados para dominio: $domain"
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  setup_database_password <DOMINIO>  Configurar contraseña de base de datos"
    echo "  setup_api_key <DOMINIO>           Configurar clave API"
    echo "  setup_ssl_certificate <DOMINIO>   Configurar certificado SSL/TLS"
    echo "  setup_domain_secrets <DOMINIO>    Configurar todos los secretos para un dominio"
    echo "  show_help                         Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 setup_database_password example.com"
    echo "  $0 setup_api_key example.com"
    echo "  $0 setup_ssl_certificate example.com"
    echo "  $0 setup_domain_secrets example.com"
}

# Procesar argumentos
case "$1" in
    "setup_database_password")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de dominio"
            show_help
            exit 1
        fi
        setup_database_password "$2"
        ;;
    "setup_api_key")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de dominio"
            show_help
            exit 1
        fi
        setup_api_key "$2"
        ;;
    "setup_ssl_certificate")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de dominio"
            show_help
            exit 1
        fi
        setup_ssl_certificate "$2"
        ;;
    "setup_domain_secrets")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de dominio"
            show_help
            exit 1
        fi
        setup_domain_secrets "$2"
        ;;
    "show_help"|*)
        show_help
        ;;
esac
EOF
    
    # Hacer ejecutable el script
    chmod +x "$INSTALL_DIR/scripts/integrate_secrets_virtualmin.sh"
    
    log_message "Script de integración con Virtualmin creado"
    print_message $GREEN "Script de integración con Virtualmin creado"
}

# Función para configurar tarea cron de backup
setup_backup_cron() {
    log_message "Configurando tarea cron de backup de secretos"
    
    # Configurar tarea cron para backup diario de secretos
    local cron_entry="0 3 * * * $INSTALL_DIR/scripts/manage_secrets.sh backup_secrets >> $LOG_FILE 2>&1"
    
    # Verificar si la tarea ya existe
    if ! crontab -l 2>/dev/null | grep -q "manage_secrets.sh backup_secrets"; then
        # Agregar tarea cron
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        log_message "Tarea cron configurada para backup diario de secretos"
    fi
}

# Función principal
main() {
    print_message $GREEN "Iniciando instalación y configuración de gestión de secretos con GPG..."
    log_message "Iniciando instalación y configuración de gestión de secretos con GPG"
    
    check_root
    install_dependencies
    configure_gpg
    generate_gpg_key
    create_management_script
    create_integration_script
    setup_backup_cron
    
    print_message $GREEN "Instalación y configuración de gestión de secretos con GPG completada"
    log_message "Instalación y configuración de gestión de secretos con GPG completada"
    
    print_message $BLUE "Información de configuración:"
    print_message $BLUE "- Script de gestión: $INSTALL_DIR/scripts/manage_secrets.sh"
    print_message $BLUE "- Script de integración: $INSTALL_DIR/scripts/integrate_secrets_virtualmin.sh"
    print_message $BLUE "- Directorio de secretos: $SECRETS_DIR"
    print_message $BLUE "- Clave pública: $CONFIG_DIR/public-key.asc"
    print_message $YELLOW "Para gestionar secretos, ejecute:"
    print_message $YELLOW "$INSTALL_DIR/scripts/manage_secrets.sh show_help"
    print_message $YELLOW "Para integrar secretos con Virtualmin, ejecute:"
    print_message $YELLOW "$INSTALL_DIR/scripts/integrate_secrets_virtualmin.sh show_help"
    print_message $YELLOW "Los secretos se cifrarán automáticamente todos los días a las 3 AM"
}

# Ejecutar función principal
main "$@"