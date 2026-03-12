#!/bin/bash

# Script de Cifrado de Datos Sensibles en Reposo
# Versión: 1.0.0
# Cifra archivos con información sensible para almacenamiento seguro

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
ENCRYPTED_DIR="$REPO_ROOT/encrypted_data"
KEY_FILE="$REPO_ROOT/.encryption_key"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_encrypt() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [ENCRYPT] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Verificar dependencias
check_dependencies() {
    log_info "Verificando dependencias..."
    
    local missing_deps=()
    
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v gpg &> /dev/null; then
        missing_deps+=("gpg")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Dependencias faltantes: ${missing_deps[*]}"
        log_info "Instale las dependencias con:"
        log_info "  sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_encrypt "Dependencias verificadas"
}

# Generar o cargar clave de encriptación
setup_encryption_key() {
    log_info "Configurando clave de encriptación..."
    
    if [[ -f "$KEY_FILE" ]]; then
        log_info "Clave de encriptación existente encontrada"
        return 0
    fi
    
    # Generar nueva clave
    log_info "Generando nueva clave de encriptación..."
    openssl rand -hex 32 > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    chown "$(whoami):$(whoami)" "$KEY_FILE"
    
    log_encrypt "Clave de encriptación generada: $KEY_FILE"
    
    # Agregar a .gitignore si no existe
    if [[ -f "$REPO_ROOT/.gitignore" ]]; then
        if ! grep -q "^\\.encryption_key$" "$REPO_ROOT/.gitignore"; then
            echo ".encryption_key" >> "$REPO_ROOT/.gitignore"
        fi
        if ! grep -q "^encrypted_data/$" "$REPO_ROOT/.gitignore"; then
            echo "encrypted_data/" >> "$REPO_ROOT/.gitignore"
        fi
    else
        echo ".encryption_key" > "$REPO_ROOT/.gitignore"
        echo "encrypted_data/" >> "$REPO_ROOT/.gitignore"
    fi
    
    log_info "Clave agregada a .gitignore"
}

# Cifrar archivo individual
encrypt_file() {
    local file_path="$1"
    local output_path="$2"
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Archivo no encontrado: $file_path"
        return 1
    fi
    
    log_encrypt "Cifrando archivo: $file_path"
    
    # Crear directorio de salida si no existe
    mkdir -p "$(dirname "$output_path")"
    
    # Cifrar archivo
    openssl enc -aes-256-cbc -salt -pass file:"$KEY_FILE" -in "$file_path" -out "$output_path"
    
    # Verificar cifrado
    if [[ $? -eq 0 ]]; then
        log_encrypt "Archivo cifrado exitosamente: $output_path"
        
        # Sobreescribir archivo original con marcador
        cat > "$file_path" << EOF
# ESTE ARCHIVO ESTÁ CIFRADO
# Para obtener el archivo original, use:
# ./security/encrypt_sensitive_data.sh decrypt $output_path $file_path
#
# Archivo cifrado: $output_path
# Fecha de cifrado: $(date)
EOF
        
        # Agregar extensión .encrypted
        mv "$output_path" "${output_path}.encrypted"
        log_info "Archivo cifrado renombrado a: ${output_path}.encrypted"
        
    else
        log_error "Error al cifrar archivo: $file_path"
        return 1
    fi
}

# Descifrar archivo
decrypt_file() {
    local encrypted_path="$1"
    local output_path="$2"
    
    if [[ ! -f "$encrypted_path" ]]; then
        log_error "Archivo cifrado no encontrado: $encrypted_path"
        return 1
    fi
    
    if [[ ! -f "$KEY_FILE" ]]; then
        log_error "Clave de encriptación no encontrada: $KEY_FILE"
        return 1
    fi
    
    log_encrypt "Descifrando archivo: $encrypted_path"
    
    # Descifrar archivo
    openssl enc -aes-256-cbc -d -salt -pass file:"$KEY_FILE" -in "$encrypted_path" -out "$output_path"
    
    # Verificar descifrado
    if [[ $? -eq 0 ]]; then
        log_encrypt "Archivo descifrado exitosamente: $output_path"
    else
        log_error "Error al descifrar archivo: $encrypted_path"
        return 1
    fi
}

# Cifrar directorio completo
encrypt_directory() {
    local dir_path="$1"
    local output_dir="$2"
    
    if [[ ! -d "$dir_path" ]]; then
        log_error "Directorio no encontrado: $dir_path"
        return 1
    fi
    
    log_encrypt "Cifrando directorio: $dir_path"
    
    # Crear directorio de salida
    mkdir -p "$output_dir"
    
    # Crear archivo temporal con lista de archivos
    local temp_filelist="/tmp/filelist_$(date +%s).txt"
    find "$dir_path" -type f ! -name "*.encrypted" ! -name "ENCRYPTED*" > "$temp_filelist"
    
    # Cifrar archivos en un tar cifrado
    tar -czf - -T "$dir_path" --files-from="$temp_filelist" | \
    openssl enc -aes-256-cbc -salt -pass file:"$KEY_FILE" -out "$output_dir/encrypted_archive.tar.gz.enc"
    
    # Verificar cifrado
    if [[ $? -eq 0 ]]; then
        log_encrypt "Directorio cifrado exitosamente: $output_dir/encrypted_archive.tar.gz.enc"
        
        # Crear manifiesto
        cat > "$output_dir/MANIFESTO.txt" << EOF
MANIFIESTO DE ARCHIVOS CIFRADOS
========================================
Directorio original: $dir_path
Directorio cifrado: $output_dir
Fecha de cifrado: $(date)
Archivos incluidos:
$(find "$dir_path" -type f ! -name "*.encrypted" ! -name "ENCRYPTED*" | sed 's/^/  - /')
========================================

Para descifrar:
./security/encrypt_sensitive_data.sh decrypt_directory "$output_dir/encrypted_archive.tar.gz.enc" "$dir_path"
EOF
        
        # Limpiar archivo temporal
        rm -f "$temp_filelist"
        
        # Marcar archivos originales
        find "$dir_path" -type f ! -name "*.encrypted" ! -name "ENCRYPTED*" | while read -r file; do
            cat > "$file" << EOF
# ESTE ARCHIVO ESTÁ CIFRADO
# Pertenece al directorio cifrado: $output_dir
# Para obtener el archivo original, use:
# ./security/encrypt_sensitive_data.sh decrypt_directory "$output_dir/encrypted_archive.tar.gz.enc" "$(dirname "$file")"
#
# Archivo cifrado: $output_dir/encrypted_archive.tar.gz.enc
# Fecha de cifrado: $(date)
EOF
        done
        
        log_info "Archivos marcados como cifrados en: $dir_path"
    else
        log_error "Error al cifrar directorio: $dir_path"
        return 1
    fi
}

# Descifrar directorio completo
decrypt_directory() {
    local encrypted_archive="$1"
    local output_dir="$2"
    
    if [[ ! -f "$encrypted_archive" ]]; then
        log_error "Archivo cifrado no encontrado: $encrypted_archive"
        return 1
    fi
    
    if [[ ! -f "$KEY_FILE" ]]; then
        log_error "Clave de encriptación no encontrada: $KEY_FILE"
        return 1
    fi
    
    log_encrypt "Descifrando directorio: $encrypted_archive"
    
    # Descifrar archivo
    openssl enc -aes-256-cbc -d -salt -pass file:"$KEY_FILE" -in "$encrypted_archive" | \
    tar -xzf - -C "$output_dir"
    
    # Verificar descifrado
    if [[ $? -eq 0 ]]; then
        log_encrypt "Directorio descifrado exitosamente en: $output_dir"
    else
        log_error "Error al descifrar directorio: $encrypted_archive"
        return 1
    fi
}

# Buscar archivos sensibles
find_sensitive_files() {
    log_info "Buscando archivos sensibles..."
    
    local sensitive_files=()
    
    # Patrones de archivos sensibles
    local patterns=(
        "*.key"
        "*.pem"
        "*.crt"
        "*.p12"
        "*.pfx"
        "*password*"
        "*secret*"
        "*credential*"
        "*config*"
        "*.conf"
        "*.env"
        "id_rsa*"
        "id_dsa*"
        "id_ecdsa*"
        "id_ed25519*"
        "known_hosts"
        "authorized_keys"
    )
    
    # Buscar archivos que coincidan con los patrones
    for pattern in "${patterns[@]}"; do
        while IFS= read -r -d '' file; do
            if [[ -f "$file" && "$file" == $pattern ]]; then
                # Excluir archivos ya cifrados o del sistema de seguridad
                if [[ ! "$file" =~ \.encrypted$ ]] && [[ ! "$file" =~ security/ ]]; then
                    sensitive_files+=("$file")
                fi
            fi
        done < <(find "$REPO_ROOT" -name "$pattern" -type f 2>/dev/null)
    done
    
    # Buscar archivos con contenido sensible
    local content_patterns=(
        "password"
        "secret"
        "key"
        "token"
        "api_key"
        "credential"
        "auth"
    )
    
    for pattern in "${content_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            if [[ -f "$file" && ! "$file" =~ \.encrypted$ ]] && ! "$file" =~ security/ ]]; then
                if grep -q -i "$pattern" "$file" 2>/dev/null; then
                    # Verificar que no sea un falso positivo
                    if grep -q -i "$pattern.*=" "$file" 2>/dev/null; then
                        sensitive_files+=("$file")
                    fi
                fi
            fi
        done < <(find "$REPO_ROOT" -type f 2>/dev/null)
    done
    
    # Eliminar duplicados
    local unique_files=($(printf '%s\n' "${sensitive_files[@]}" | sort -u))
    
    echo "${unique_files[@]}"
}

# Cifrar todos los archivos sensibles encontrados
encrypt_all_sensitive() {
    log_info "Iniciando cifrado de todos los archivos sensibles..."
    
    # Crear directorio para archivos cifrados
    mkdir -p "$ENCRYPTED_DIR"
    
    local sensitive_files
    readarray -t sensitive_files < <(find_sensitive_files)
    
    if [[ ${#sensitive_files[@]} -eq 0 ]]; then
        log_warning "No se encontraron archivos sensibles para cifrar"
        return 0
    fi
    
    log_info "Se encontraron ${#sensitive_files[@]} archivos sensibles"
    
    # Cifrar cada archivo individualmente
    local encrypted_count=0
    for file in "${sensitive_files[@]}"; do
        local relative_path="${file#$REPO_ROOT/}"
        local encrypted_path="$ENCRYPTED_DIR/${relative_path}.encrypted"
        
        # Crear directorio si es necesario
        mkdir -p "$(dirname "$encrypted_path")"
        
        if encrypt_file "$file" "$encrypted_path"; then
            ((encrypted_count++))
        fi
    done
    
    # Crear manifiesto general
    cat > "$ENCRYPTED_DIR/MANIFESTO_GENERAL.txt" << EOF
MANIFIESTO GENERAL DE CIFRADO
========================================
Fecha de cifrado: $(date)
Total de archivos cifrados: $encrypted_count
Clave de encriptación: $KEY_FILE

Lista de archivos cifrados:
EOF
    
    for file in "${sensitive_files[@]}"; do
        local relative_path="${file#$REPO_ROOT/}"
        echo "  - $relative_path -> encrypted_data/${relative_path}.encrypted" >> "$ENCRYPTED_DIR/MANIFESTO_GENERAL.txt"
    done
    
    cat >> "$ENCRYPTED_DIR/MANIFESTO_GENERAL.txt" << EOF

Para descifrar todos los archivos:
./security/encrypt_sensitive_data.sh decrypt_all "$ENCRYPTED_DIR"

Para descifrar un archivo específico:
./security/encrypt_sensitive_data.sh decrypt "encrypted_data/archivo.encrypted" "ruta/del/archivo/original"
========================================
EOF
    
    log_encrypt "Cifrado completado. $encrypted_count archivos procesados"
    log_info "Manifiesto creado: $ENCRYPTED_DIR/MANIFESTO_GENERAL.txt"
}

# Descifrar todos los archivos
decrypt_all_sensitive() {
    local encrypted_dir="$1"
    
    if [[ ! -d "$encrypted_dir" ]]; then
        log_error "Directorio cifrado no encontrado: $encrypted_dir"
        return 1
    fi
    
    if [[ ! -f "$KEY_FILE" ]]; then
        log_error "Clave de encriptación no encontrada: $KEY_FILE"
        return 1
    fi
    
    log_info "Iniciando descifrado de todos los archivos..."
    
    # Leer manifiesto si existe
    local manifest_file="$encrypted_dir/MANIFESTO_GENERAL.txt"
    if [[ -f "$manifest_file" ]]; then
        log_info "Manifiesto encontrado: $manifest_file"
        
        # Procesar cada archivo del manifiesto
        while IFS= read -r line; do
            if [[ "$line" =~ ^\ -\ (.+)\ -\>\ (.+)$ ]]; then
                local original_file="${BASH_REMATCH[1]}"
                local encrypted_file="${BASH_REMATCH[2]}"
                
                # Descifrar archivo
                if decrypt_file "$encrypted_dir/$encrypted_file" "$REPO_ROOT/$original_file"; then
                    log_encrypt "Archivo descifrado: $original_file"
                fi
            fi
        done < "$manifest_file"
    else
        log_warning "No se encontró manifiesto. Descifrando todos los archivos .encrypted"
        
        # Descifrar todos los archivos .encrypted
        find "$encrypted_dir" -name "*.encrypted" -type f | while read -r encrypted_file; do
            local relative_path="${encrypted_file#$encrypted_dir/}"
            relative_path="${relative_path%.encrypted}"
            
            decrypt_file "$encrypted_file" "$REPO_ROOT/$relative_path"
        done
    fi
    
    log_info "Descifrado completado"
}

# Mostrar ayuda
show_help() {
    cat << EOF
Script de Cifrado de Datos Sensibles para Reposo

Uso: $0 <comando> [opciones]

Comandos:
    setup                    Configura clave de encriptación
    encrypt <archivo> <salida> Cifra un archivo específico
    decrypt <archivo_cifrado> <salida> Descifra un archivo
    encrypt_directory <directorio> <salida> Cifra un directorio completo
    decrypt_directory <archivo_cifrado> <salida> Descifra un directorio
    encrypt_all               Cifra todos los archivos sensibles encontrados
    decrypt_all <directorio>   Descifra todos los archivos cifrados
    find                     Busca archivos sensibles en el repositorio
    help                     Muestra esta ayuda

Ejemplos:
    # Configurar clave
    $0 setup
    
    # Cifrar archivo específico
    $0 encrypt configs/mysql/my.cnf encrypted_data/my.cnf.encrypted
    
    # Cifrar directorio
    $0 encrypt_directory configs/ encrypted_data/configs
    
    # Cifrar todos los archivos sensibles
    $0 encrypt_all
    
    # Descifrar archivo
    $0 decrypt encrypted_data/my.cnf.encrypted configs/mysql/my.cnf
    
    # Descifrar directorio
    $0 decrypt_directory encrypted_data/configs.tar.gz.enc configs/

EOF
}

# Función principal
main() {
    case "${1:-}" in
        setup)
            check_dependencies
            setup_encryption_key
            ;;
        encrypt)
            if [[ $# -ne 3 ]]; then
                log_error "Uso: $0 encrypt <archivo> <salida>"
                exit 1
            fi
            check_dependencies
            setup_encryption_key
            encrypt_file "$2" "$3"
            ;;
        decrypt)
            if [[ $# -ne 3 ]]; then
                log_error "Uso: $0 decrypt <archivo_cifrado> <salida>"
                exit 1
            fi
            check_dependencies
            decrypt_file "$2" "$3"
            ;;
        encrypt_directory)
            if [[ $# -ne 3 ]]; then
                log_error "Uso: $0 encrypt_directory <directorio> <salida>"
                exit 1
            fi
            check_dependencies
            setup_encryption_key
            encrypt_directory "$2" "$3"
            ;;
        decrypt_directory)
            if [[ $# -ne 3 ]]; then
                log_error "Uso: $0 decrypt_directory <archivo_cifrado> <salida>"
                exit 1
            fi
            check_dependencies
            decrypt_directory "$2" "$3"
            ;;
        encrypt_all)
            check_dependencies
            setup_encryption_key
            encrypt_all_sensitive
            ;;
        decrypt_all)
            if [[ $# -ne 2 ]]; then
                log_error "Uso: $0 decrypt_all <directorio_cifrado>"
                exit 1
            fi
            check_dependencies
            decrypt_all_sensitive "$2"
            ;;
        find)
            check_dependencies
            find_sensitive_files
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Comando no reconocido: ${1:-}"
            show_help
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"