#!/bin/bash

# Script de instalación y configuración de Google Authenticator PAM para Virtualmin Enterprise
# Este script instala y configura autenticación multifactor con Google Authenticator

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-mfa.log"
CONFIG_DIR="/opt/virtualmin-enterprise/config/mfa"

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
                libpam-google-authenticator \
                qrencode \
                libqrencode3 \
                python3-pip \
                python3-qrcode \
                python3-pil \
                oathtool
            ;;
        "redhat")
            yum update -y
            yum install -y \
                google-authenticator \
                qrencode \
                python3-pip \
                python3-qrcode \
                python3-pillow \
                oathtool
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    log_message "Dependencias instaladas"
}

# Función para configurar PAM para SSH
configure_pam_ssh() {
    log_message "Configurando PAM para SSH"
    
    # Crear directorio de configuración
    mkdir -p "$CONFIG_DIR"
    
    # Configurar PAM para SSH
    if [ -f "/etc/pam.d/sshd" ]; then
        # Hacer backup del archivo original
        cp "/etc/pam.d/sshd" "/etc/pam.d/sshd.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Añadir configuración de Google Authenticator
        cat > "/etc/pam.d/sshd" << 'EOF'
# PAM configuration for SSH
auth       required     pam_nologin.so
auth       include      system-auth
account    required     pam_nologin.so
account    include      system-auth
password   include      system-auth
session    required     pam_limits.so
session    optional     pam_keyinit.so force revoke
session    include      system-auth
session    required     pam_loginuid.so

# Google Authenticator MFA
auth       required     pam_google_authenticator.so nullok
EOF
    fi
    
    # Configurar SSH para usar PAM
    if [ -f "/etc/ssh/sshd_config" ]; then
        # Hacer backup del archivo original
        cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Habilitar autenticación PAM
        sed -i 's/#UsePAM yes/UsePAM yes/' "/etc/ssh/sshd_config"
        
        # Habilitar ChallengeResponseAuthentication
        sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/' "/etc/ssh/sshd_config"
        sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/' "/etc/ssh/sshd_config"
        
        # Habilitar PasswordAuthentication (necesario para MFA)
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "/etc/ssh/sshd_config"
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' "/etc/ssh/sshd_config"
    fi
    
    # Reiniciar servicio SSH
    systemctl restart sshd >> "$LOG_FILE" 2>&1
    
    log_message "PAM configurado para SSH"
    print_message $GREEN "PAM configurado para SSH"
}

# Función para configurar PAM para Webmin
configure_pam_webmin() {
    log_message "Configurando PAM para Webmin"
    
    # Configurar Webmin para usar PAM
    if [ -f "/etc/webmin/config" ]; then
        # Hacer backup del archivo original
        cp "/etc/webmin/config" "/etc/webmin/config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Configurar Webmin para usar PAM
        sed -i 's/passmode=0/passmode=2/' "/etc/webmin/config"
        sed -i 's/pam=webmin/pam=sshd/' "/etc/webmin/config"
    fi
    
    # Reiniciar servicio Webmin
    systemctl restart webmin >> "$LOG_FILE" 2>&1
    
    log_message "PAM configurado para Webmin"
    print_message $GREEN "PAM configurado para Webmin"
}

# Función para configurar PAM para Virtualmin
configure_pam_virtualmin() {
    log_message "Configurando PAM para Virtualmin"
    
    # Configurar Virtualmin para usar PAM
    if [ -f "/etc/webmin/virtual-server/config" ]; then
        # Hacer backup del archivo original
        cp "/etc/webmin/virtual-server/config" "/etc/webmin/virtual-server/config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Configurar Virtualmin para usar PAM
        sed -i 's/passmode=0/passmode=2/' "/etc/webmin/virtual-server/config"
        sed -i 's/pam=virtualmin/pam=sshd/' "/etc/webmin/virtual-server/config"
    fi
    
    # Reiniciar servicio Webmin
    systemctl restart webmin >> "$LOG_FILE" 2>&1
    
    log_message "PAM configurado para Virtualmin"
    print_message $GREEN "PAM configurado para Virtualmin"
}

# Función para crear script de gestión de MFA
create_management_script() {
    log_message "Creando script de gestión de MFA"
    
    cat > "$INSTALL_DIR/scripts/manage_mfa.sh" << 'EOF'
#!/bin/bash

# Script de gestión de Google Authenticator MFA para Virtualmin Enterprise

CONFIG_DIR="/opt/virtualmin-enterprise/config/mfa"
LOG_FILE="/var/log/virtualmin-enterprise-mfa.log"

# Función para registrar mensajes
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Función para generar código QR para usuario
generate_qr_code() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se requiere nombre de usuario"
        return 1
    fi
    
    echo "Generando código QR para usuario: $username"
    
    # Obtener directorio home del usuario
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [ -z "$user_home" ]; then
        echo "Error: No se encontró directorio home para el usuario $username"
        return 1
    fi
    
    # Verificar si ya existe archivo de configuración de Google Authenticator
    if [ -f "$user_home/.google_authenticator" ]; then
        echo "El usuario $username ya tiene configurado Google Authenticator"
        return 1
    fi
    
    # Cambiar al usuario y ejecutar google-authenticator
    sudo -u "$username" google-authenticator -t -d -f -r 3 -R 30 -W >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        # Generar código QR
        local secret=$(grep "Your new secret key is:" "$user_home/.google_authenticator" | cut -d' ' -f6)
        local qr_code_data="otpauth://totp/Virtualmin%20Enterprise%20-$username?secret=$secret&issuer=Virtualmin%20Enterprise"
        
        # Generar imagen QR con qrencode
        qrencode -o "$CONFIG_DIR/$username.png" "$qr_code_data" >> "$LOG_FILE" 2>&1
        
        echo "Código QR generado para $username: $CONFIG_DIR/$username.png"
        echo "Secreto: $secret"
        
        # Mostrar código QR en texto (opcional)
        echo "Código QR (texto):"
        qrencode -t ANSI "$qr_code_data"
        
        log_message "Código QR generado para $username"
    else
        echo "Error al generar código QR para $username"
        log_message "Error al generar código QR para $username"
        return 1
    fi
}

# Función para verificar código de un usuario
verify_code() {
    local username=$1
    local code=$2
    
    if [ -z "$username" ] || [ -z "$code" ]; then
        echo "Error: Se requiere nombre de usuario y código"
        return 1
    fi
    
    # Obtener directorio home del usuario
    local user_home=$(getent_passwd "$username" | cut -d: -f6)
    
    if [ ! -f "$user_home/.google_authenticator" ]; then
        echo "Error: El usuario $username no tiene configurado Google Authenticator"
        return 1
    fi
    
    # Verificar código con oathtool
    local secret=$(grep "Your new secret key is:" "$user_home/.google_authenticator" | cut -d' ' -f6)
    local expected_code=$(oathtool --totp -b "$secret")
    
    if [ "$code" = "$expected_code" ]; then
        echo " Código válido para $username"
        log_message "Código válido para $username"
        return 0
    else
        echo " Código inválido para $username"
        log_message "Código inválido para $username"
        return 1
    fi
}

# Función para configurar MFA para usuario
setup_user_mfa() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se requiere nombre de usuario"
        return 1
    fi
    
    echo "Configurando MFA para usuario: $username"
    
    # Obtener directorio home del usuario
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [ -z "$user_home" ]; then
        echo "Error: No se encontró directorio home para el usuario $username"
        return 1
    fi
    
    # Verificar si ya existe archivo de configuración de Google Authenticator
    if [ -f "$user_home/.google_authenticator" ]; then
        echo "El usuario $username ya tiene configurado Google Authenticator"
        return 1
    fi
    
    # Cambiar al usuario y ejecutar google-authenticator con opciones predeterminadas
    sudo -u "$username" bash -c 'echo -e "y\ny\ny\ny\ny\ny" | google-authenticator -t -d -f -r 3 -R 30 -W' >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        # Generar código QR
        local secret=$(grep "Your new secret key is:" "$user_home/.google_authenticator" | cut -d' ' -f6)
        local qr_code_data="otpauth://totp/Virtualmin%20Enterprise%20-$username?secret=$secret&issuer=Virtualmin%20Enterprise"
        
        # Generar imagen QR con qrencode
        qrencode -o "$CONFIG_DIR/$username.png" "$qr_code_data" >> "$LOG_FILE" 2>&1
        
        echo "MFA configurado para $username"
        echo "Código QR generado: $CONFIG_DIR/$username.png"
        echo "Secreto: $secret"
        
        # Mostrar códigos de recuperación
        echo "Códigos de recuperación:"
        grep "Your recovery codes are:" "$user_home/.google_authenticator" | cut -d' ' -f5-
        
        log_message "MFA configurado para $username"
    else
        echo "Error al configurar MFA para $username"
        log_message "Error al configurar MFA para $username"
        return 1
    fi
}

# Función para desconfigurar MFA para usuario
disable_user_mfa() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se requiere nombre de usuario"
        return 1
    fi
    
    # Obtener directorio home del usuario
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [ -f "$user_home/.google_authenticator" ]; then
        # Hacer backup del archivo
        cp "$user_home/.google_authenticator" "$user_home/.google_authenticator.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Eliminar archivo de configuración
        rm "$user_home/.google_authenticator"
        
        # Eliminar código QR
        if [ -f "$CONFIG_DIR/$username.png" ]; then
            rm "$CONFIG_DIR/$username.png"
        fi
        
        echo "MFA desactivado para $username"
        log_message "MFA desactivado para $username"
    else
        echo "El usuario $username no tiene MFA configurado"
    fi
}

# Función para regenerar secretos para usuario
regenerate_user_mfa() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se requiere nombre de usuario"
        return 1
    fi
    
    # Desactivar MFA actual
    disable_user_mfa "$username"
    
    # Configurar nuevo MFA
    setup_user_mfa "$username"
}

# Función para mostrar códigos de recuperación de un usuario
show_recovery_codes() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se requiere nombre de usuario"
        return 1
    fi
    
    # Obtener directorio home del usuario
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [ -f "$user_home/.google_authenticator" ]; then
        echo "Códigos de recuperación para $username:"
        grep "Your recovery codes are:" "$user_home/.google_authenticator" | cut -d' ' -f5-
    else
        echo "El usuario $username no tiene MFA configurado"
    fi
}

# Función para mostrar estado de MFA para usuario
show_user_mfa_status() {
    local username=$1
    
    if [ -z "$username" ]; then
        echo "Error: Se requiere nombre de usuario"
        return 1
    fi
    
    # Obtener directorio home del usuario
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    
    if [ -f "$user_home/.google_authenticator" ]; then
        local secret=$(grep "Your new secret key is:" "$user_home/.google_authenticator" | cut -d' ' -f6)
        echo "MFA activo para $username"
        echo "Secreto: $secret"
        echo "Archivo de configuración: $user_home/.google_authenticator"
        echo "Código QR: $CONFIG_DIR/$username.png"
        
        # Mostrar opciones de configuración
        echo "Opciones de configuración:"
        grep "Verification options:" "$user_home/.google_authenticator" | cut -d' ' -f4-
    else
        echo "MFA no configurado para $username"
    fi
}

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [OPCIÓN] [ARGUMENTOS]"
    echo ""
    echo "Opciones:"
    echo "  setup_user_mfa <USUARIO>         Configurar MFA para usuario"
    echo "  disable_user_mfa <USUARIO>      Desactivar MFA para usuario"
    echo "  generate_qr_code <USUARIO>      Generar código QR para usuario"
    echo "  verify_code <USUARIO> <CÓDIGO>  Verificar código de usuario"
    echo "  regenerate_user_mfa <USUARIO>   Regenerar secretos para usuario"
    echo "  show_recovery_codes <USUARIO>   Mostrar códigos de recuperación de usuario"
    echo "  show_user_mfa_status <USUARIO>  Mostrar estado de MFA para usuario"
    echo "  show_help                      Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 setup_user_mfa admin"
    echo "  $0 disable_user_mfa admin"
    echo "  $0 generate_qr_code admin"
    echo "  $0 verify_code admin 123456"
    echo "  $0 regenerate_user_mfa admin"
    echo "  $0 show_recovery_codes admin"
    echo "  $0 show_user_mfa_status admin"
}

# Crear directorio de configuración si no existe
mkdir -p "$CONFIG_DIR"

# Procesar argumentos
case "$1" in
    "setup_user_mfa")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de usuario"
            show_help
            exit 1
        fi
        setup_user_mfa "$2"
        ;;
    "disable_user_mfa")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de usuario"
            show_help
            exit 1
        fi
        disable_user_mfa "$2"
        ;;
    "generate_qr_code")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de usuario"
            show_help
            exit 1
        fi
        generate_qr_code "$2"
        ;;
    "verify_code")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Error: Se requiere nombre de usuario y código"
            show_help
            exit 1
        fi
        verify_code "$2" "$3"
        ;;
    "regenerate_user_mfa")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de usuario"
            show_help
            exit 1
        fi
        regenerate_user_mfa "$2"
        ;;
    "show_recovery_codes")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de usuario"
            show_help
            exit 1
        fi
        show_recovery_codes "$2"
        ;;
    "show_user_mfa_status")
        if [ -z "$2" ]; then
            echo "Error: Se requiere nombre de usuario"
            show_help
            exit 1
        fi
        show_user_mfa_status "$2"
        ;;
    "show_help"|*)
        show_help
        ;;
esac
EOF
    
    # Hacer ejecutable el script
    chmod +x "$INSTALL_DIR/scripts/manage_mfa.sh"
    
    log_message "Script de gestión de MFA creado"
    print_message $GREEN "Script de gestión de MFA creado"
}

# Función para crear script de configuración inicial
create_setup_script() {
    log_message "Creando script de configuración inicial de MFA"
    
    cat > "$CONFIG_DIR/setup_initial_mfa.sh" << 'EOF'
#!/bin/bash

# Script de configuración inicial de MFA para usuarios existentes

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Este script configurará MFA para usuarios existentes"
echo "Se generará un código QR para cada usuario que deberá escanear con Google Authenticator"
echo ""

# Lista de usuarios del sistema
USERS=$(grep -E "/bin/bash|/bin/sh" /etc/passwd | cut -d: -f1 | grep -v root)

# Configurar MFA para cada usuario
for user in $USERS; do
    echo "Configurando MFA para $user..."
    
    # Ejecutar script de gestión de MFA
    /opt/virtualmin-enterprise/scripts/manage_mfa.sh setup_user_mfa "$user"
    
    if [ $? -eq 0 ]; then
        echo "✓ MFA configurado para $user"
        echo "  Código QR guardado en: /opt/virtualmin-enterprise/config/mfa/$user.png"
        echo "  El usuario $user debe escanear este código QR con Google Authenticator"
        echo ""
        
        # Esperar confirmación
        read -p "Presione Enter para continuar con el siguiente usuario..."
    else
        echo "✗ Error al configurar MFA para $user"
        echo ""
    fi
done

echo "Configuración inicial de MFA completada"
echo ""
echo "IMPORTANTE:"
echo "1. Cada usuario debe escanear su código QR con Google Authenticator"
echo "2. Los usuarios deben guardar sus códigos de recuperación en un lugar seguro"
echo "3. Para gestionar MFA de usuarios, use: /opt/virtualmin-enterprise/scripts/manage_mfa.sh"
EOF
    
    # Hacer ejecutable el script
    chmod +x "$CONFIG_DIR/setup_initial_mfa.sh"
    
    log_message "Script de configuración inicial de MFA creado"
    print_message $GREEN "Script de configuración inicial de MFA creado"
}

# Función principal
main() {
    print_message $GREEN "Iniciando instalación y configuración de Google Authenticator MFA..."
    log_message "Iniciando instalación y configuración de Google Authenticator MFA"
    
    check_root
    install_dependencies
    configure_pam_ssh
    configure_pam_webmin
    configure_pam_virtualmin
    create_management_script
    create_setup_script
    
    print_message $GREEN "Instalación y configuración de Google Authenticator MFA completada"
    log_message "Instalación y configuración de Google Authenticator MFA completada"
    
    print_message $BLUE "Información de configuración:"
    print_message $BLUE "- Script de gestión: $INSTALL_DIR/scripts/manage_mfa.sh"
    print_message $BLUE "- Script de configuración inicial: $CONFIG_DIR/setup_initial_mfa.sh"
    print_message $BLUE "- Directorio de códigos QR: $CONFIG_DIR"
    print_message $YELLOW "Para configurar MFA para usuarios existentes, ejecute:"
    print_message $YELLOW "$CONFIG_DIR/setup_initial_mfa.sh"
    print_message $YELLOW "Para gestionar MFA de usuarios, ejecute:"
    print_message $YELLOW "$INSTALL_DIR/scripts/manage_mfa.sh show_help"
}

# Ejecutar función principal
main "$@"