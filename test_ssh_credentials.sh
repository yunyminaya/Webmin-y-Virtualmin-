#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Función para logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Variables
WEBMIN_USER="root"

# Función para generar credenciales basadas en SSH
generate_ssh_credentials() {
    log_info "🔐 Generando credenciales desde clave SSH del servidor..."
    
    # Variables para el proceso de búsqueda
    local ssh_key_found=false
    local ssh_key_path=""
    
    # Buscar claves SSH del usuario actual primero
    for key_type in id_ed25519 id_rsa id_ecdsa id_dsa; do
        if [[ -f "$HOME/.ssh/$key_type" ]] && [[ -r "$HOME/.ssh/$key_type" ]]; then
            ssh_key_path="$HOME/.ssh/$key_type"
            ssh_key_found=true
            log_info "✅ Clave SSH del usuario encontrada: $ssh_key_path"
            break
        fi
    done
    
    # Si no se encuentra en el usuario, buscar claves del sistema (solo si tenemos permisos)
    if [[ "$ssh_key_found" == false ]]; then
        for key_type in ssh_host_rsa_key ssh_host_ed25519_key ssh_host_ecdsa_key ssh_host_dsa_key; do
            if [[ -f "/etc/ssh/$key_type" ]] && [[ -r "/etc/ssh/$key_type" ]]; then
                ssh_key_path="/etc/ssh/$key_type"
                ssh_key_found=true
                log_info "✅ Clave SSH del sistema encontrada: $ssh_key_path"
                break
            fi
        done
    fi
    
    # Generar credenciales basadas en la clave encontrada
    if [[ "$ssh_key_found" == true ]] && [[ -f "$ssh_key_path" ]]; then
        # Intentar leer la clave y generar hash
        if SSH_KEY_CONTENT=$(cat "$ssh_key_path" 2>/dev/null); then
            SSH_KEY_HASH=$(echo "$SSH_KEY_CONTENT" | sha256sum | cut -d' ' -f1 | head -c 16)
            WEBMIN_PASS="ssh_${SSH_KEY_HASH}"
            log_info "✅ Credenciales generadas desde: $ssh_key_path"
        else
            log_info "⚠️  No se pudo leer la clave SSH: $ssh_key_path"
            ssh_key_found=false
        fi
    fi
    
    # Si no se encontró ninguna clave válida, generar una nueva
    if [[ "$ssh_key_found" == false ]]; then
        log_info "⚠️  No se encontraron claves SSH accesibles. Generando nueva clave..."
        
        # Crear directorio .ssh si no existe
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        
        # Generar nueva clave Ed25519
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_webmin" -N "" -C "webmin-auto-generated" >/dev/null 2>&1
        
        if [[ -f "$HOME/.ssh/id_ed25519_webmin" ]]; then
            SSH_KEY_HASH=$(cat "$HOME/.ssh/id_ed25519_webmin" | sha256sum | cut -d' ' -f1 | head -c 16)
            WEBMIN_PASS="ssh_${SSH_KEY_HASH}"
            log_info "✅ Nueva clave SSH generada y credenciales configuradas"
        else
            log_info "❌ Error al generar nueva clave SSH"
            # Fallback: generar contraseña aleatoria
            WEBMIN_PASS="webmin_$(openssl rand -hex 8)"
            log_info "⚠️  Usando contraseña aleatoria como fallback"
        fi
    fi
    
    log_info "🔑 Credenciales generadas exitosamente"
    log_info "👤 Usuario: $WEBMIN_USER"
    log_info "🔐 Contraseña (primeros 8 caracteres): ${WEBMIN_PASS:0:8}..."
}

echo "═══════════════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}🧪 PRUEBA DE GENERACIÓN DE CREDENCIALES SSH${NC}"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo

generate_ssh_credentials

echo
echo "═══════════════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✅ PRUEBA COMPLETADA${NC}"
echo "═══════════════════════════════════════════════════════════════════════════════"