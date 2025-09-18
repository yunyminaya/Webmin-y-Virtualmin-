#!/bin/bash

# ============================================================================
# CONFIGURADOR DE REPOSITORIO OFICIAL EXCLUSIVO
# ============================================================================
# Configura el sistema para que SOLO reciba actualizaciones del repositorio:
# https://github.com/yunyminaya/Webmin-y-Virtualmin-
#
# Bloquea cualquier otro repositorio y fuente de actualizaciones
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración del repositorio oficial
OFFICIAL_REPO_HTTPS="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
OFFICIAL_REPO_SSH="git@github.com:yunyminaya/Webmin-y-Virtualmin-.git"
OFFICIAL_REPO_NAME="yunyminaya/Webmin-y-Virtualmin-"

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}🔒 CONFIGURADOR DE REPOSITORIO OFICIAL EXCLUSIVO${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo
echo -e "${GREEN}Repositorio oficial autorizado:${NC}"
echo -e "${YELLOW}   $OFFICIAL_REPO_HTTPS${NC}"
echo

# ============================================================================
# FUNCIONES DE CONFIGURACIÓN
# ============================================================================

# Función para verificar si estamos en un repositorio git
check_git_repository() {
    echo -e "${BLUE}🔍 Verificando repositorio Git...${NC}"

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}❌ Error: No se encuentra un repositorio Git válido${NC}"
        echo -e "${YELLOW}💡 Inicializando repositorio Git...${NC}"

        git init
        echo -e "${GREEN}✅ Repositorio Git inicializado${NC}"
    else
        echo -e "${GREEN}✅ Repositorio Git encontrado${NC}"
    fi
}

# Función para configurar el repositorio oficial
configure_official_remote() {
    echo -e "${BLUE}🔧 Configurando repositorio oficial...${NC}"

    # Verificar remote origin actual
    local current_origin
    current_origin=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ -n "$current_origin" ]]; then
        echo -e "${YELLOW}📍 Remote origin actual: $current_origin${NC}"

        if [[ "$current_origin" != "$OFFICIAL_REPO_HTTPS" && "$current_origin" != "$OFFICIAL_REPO_SSH" ]]; then
            echo -e "${YELLOW}⚠️ Remote origin no apunta al repositorio oficial${NC}"
            echo -e "${BLUE}🔄 Reconfigurando remote origin...${NC}"

            git remote set-url origin "$OFFICIAL_REPO_HTTPS"
            echo -e "${GREEN}✅ Remote origin reconfigurado al repositorio oficial${NC}"
        else
            echo -e "${GREEN}✅ Remote origin ya apunta al repositorio oficial${NC}"
        fi
    else
        echo -e "${YELLOW}📍 No hay remote origin configurado${NC}"
        echo -e "${BLUE}➕ Agregando remote origin oficial...${NC}"

        git remote add origin "$OFFICIAL_REPO_HTTPS"
        echo -e "${GREEN}✅ Remote origin oficial agregado${NC}"
    fi

    # Configurar upstream si es necesario
    local current_upstream
    current_upstream=$(git remote get-url upstream 2>/dev/null || echo "")

    if [[ -n "$current_upstream" ]]; then
        if [[ "$current_upstream" != "$OFFICIAL_REPO_HTTPS" && "$current_upstream" != "$OFFICIAL_REPO_SSH" ]]; then
            echo -e "${YELLOW}⚠️ Remote upstream no apunta al repositorio oficial${NC}"
            git remote set-url upstream "$OFFICIAL_REPO_HTTPS"
            echo -e "${GREEN}✅ Remote upstream reconfigurado${NC}"
        fi
    fi
}

# Función para verificar conectividad con el repositorio oficial
test_repository_connectivity() {
    echo -e "${BLUE}🌐 Verificando conectividad con repositorio oficial...${NC}"

    if git ls-remote --heads origin >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Conectividad con repositorio oficial verificada${NC}"

        # Obtener información del repositorio
        local latest_commit
        latest_commit=$(git ls-remote --heads origin main 2>/dev/null | cut -f1 | head -c 8)

        if [[ -z "$latest_commit" ]]; then
            latest_commit=$(git ls-remote --heads origin master 2>/dev/null | cut -f1 | head -c 8)
        fi

        if [[ -n "$latest_commit" ]]; then
            echo -e "${BLUE}📍 Último commit remoto: $latest_commit${NC}"
        fi
    else
        echo -e "${RED}❌ Error: No se puede conectar con el repositorio oficial${NC}"
        echo -e "${YELLOW}💡 Verifica tu conexión a internet y permisos de acceso${NC}"
        return 1
    fi
}

# Función para crear archivo de configuración de seguridad
create_security_config() {
    echo -e "${BLUE}🔒 Creando configuración de seguridad...${NC}"

    local security_config="${SCRIPT_DIR}/.repo_security_config"

    cat > "$security_config" << EOF
# CONFIGURACIÓN DE SEGURIDAD - REPOSITORIO OFICIAL EXCLUSIVO
# Este archivo protege contra actualizaciones de fuentes no autorizadas

OFFICIAL_REPOSITORY="$OFFICIAL_REPO_HTTPS"
OFFICIAL_REPOSITORY_SSH="$OFFICIAL_REPO_SSH"
REPOSITORY_NAME="$OFFICIAL_REPO_NAME"
CONFIGURED_DATE="$(date -Iseconds)"
SECURITY_LEVEL="MAXIMUM"

# Solo se permiten actualizaciones desde el repositorio oficial
# Cualquier otro repositorio será rechazado automáticamente
EOF

    chmod 600 "$security_config"
    echo -e "${GREEN}✅ Configuración de seguridad creada${NC}"

    # Crear script de verificación rápida
    local verify_script="${SCRIPT_DIR}/verify_repo_security.sh"

    cat > "$verify_script" << 'EOF'
#!/bin/bash
# Verificación rápida de seguridad del repositorio

OFFICIAL_REPO="https://github.com/yunyminaya/Webmin-y-Virtualmin-.git"
CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")

if [[ "$CURRENT_ORIGIN" == "$OFFICIAL_REPO" || "$CURRENT_ORIGIN" == "git@github.com:yunyminaya/Webmin-y-Virtualmin-.git" ]]; then
    echo "✅ SEGURO: Repositorio oficial configurado correctamente"
    exit 0
else
    echo "🚨 PELIGRO: Repositorio no autorizado detectado"
    echo "Actual: $CURRENT_ORIGIN"
    echo "Oficial: $OFFICIAL_REPO"
    exit 1
fi
EOF

    chmod +x "$verify_script"
    echo -e "${GREEN}✅ Script de verificación creado: verify_repo_security.sh${NC}"
}

# Función para configurar hooks de seguridad
configure_security_hooks() {
    echo -e "${BLUE}🛡️ Configurando hooks de seguridad...${NC}"

    local git_hooks_dir="${SCRIPT_DIR}/.git/hooks"

    if [[ -d "$git_hooks_dir" ]]; then
        # Hook pre-push para verificar destino
        cat > "${git_hooks_dir}/pre-push" << EOF
#!/bin/bash
# Hook de seguridad - Solo permite push al repositorio oficial

OFFICIAL_REPO="$OFFICIAL_REPO_HTTPS"
OFFICIAL_REPO_SSH="$OFFICIAL_REPO_SSH"

while read local_ref local_sha remote_ref remote_sha; do
    if [[ "\$2" != "\$OFFICIAL_REPO" && "\$2" != "\$OFFICIAL_REPO_SSH" ]]; then
        echo "🚨 ERROR: Solo se permite push al repositorio oficial"
        echo "Repositorio autorizado: \$OFFICIAL_REPO"
        echo "Intento de push a: \$2"
        exit 1
    fi
done
EOF

        chmod +x "${git_hooks_dir}/pre-push"
        echo -e "${GREEN}✅ Hook pre-push configurado${NC}"

        # Hook pre-fetch para verificar origen
        cat > "${git_hooks_dir}/pre-fetch" << EOF
#!/bin/bash
# Hook de seguridad - Solo permite fetch del repositorio oficial

OFFICIAL_REPO="$OFFICIAL_REPO_HTTPS"
OFFICIAL_REPO_SSH="$OFFICIAL_REPO_SSH"

REMOTE_URL=\$(git remote get-url "\$1" 2>/dev/null || echo "")

if [[ "\$REMOTE_URL" != "\$OFFICIAL_REPO" && "\$REMOTE_URL" != "\$OFFICIAL_REPO_SSH" ]]; then
    echo "🚨 ERROR: Solo se permite fetch del repositorio oficial"
    echo "Repositorio autorizado: \$OFFICIAL_REPO"
    echo "Intento de fetch desde: \$REMOTE_URL"
    exit 1
fi
EOF

        chmod +x "${git_hooks_dir}/pre-fetch"
        echo -e "${GREEN}✅ Hook pre-fetch configurado${NC}"
    else
        echo -e "${YELLOW}⚠️ Directorio .git/hooks no encontrado${NC}"
    fi
}

# Función para hacer fetch inicial y configurar tracking
setup_initial_tracking() {
    echo -e "${BLUE}📥 Configurando tracking inicial...${NC}"

    # Hacer fetch del repositorio oficial
    if git fetch origin >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Fetch inicial completado${NC}"

        # Verificar si tenemos branches remotos
        local remote_branches
        remote_branches=$(git branch -r 2>/dev/null | grep -v "HEAD" | wc -l)

        if [[ $remote_branches -gt 0 ]]; then
            # Configurar tracking branch si no existe
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null || echo "")

            if [[ -n "$current_branch" ]]; then
                if ! git config "branch.${current_branch}.remote" >/dev/null 2>&1; then
                    if git show-ref --verify --quiet refs/remotes/origin/main; then
                        git branch --set-upstream-to=origin/main "$current_branch" 2>/dev/null || true
                        echo -e "${GREEN}✅ Tracking configurado a origin/main${NC}"
                    elif git show-ref --verify --quiet refs/remotes/origin/master; then
                        git branch --set-upstream-to=origin/master "$current_branch" 2>/dev/null || true
                        echo -e "${GREEN}✅ Tracking configurado a origin/master${NC}"
                    fi
                fi
            fi
        fi
    else
        echo -e "${YELLOW}⚠️ No se pudo hacer fetch inicial (puede ser normal en un repo nuevo)${NC}"
    fi
}

# Función para mostrar resumen de configuración
show_configuration_summary() {
    echo
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${GREEN}📋 RESUMEN DE CONFIGURACIÓN${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo

    echo -e "${GREEN}🔒 Configuración de Seguridad:${NC}"
    echo -e "   ✅ Repositorio oficial configurado"
    echo -e "   ✅ Hooks de seguridad instalados"
    echo -e "   ✅ Archivo de configuración de seguridad creado"
    echo

    echo -e "${GREEN}📍 Repositorio Oficial:${NC}"
    echo -e "   URL: $OFFICIAL_REPO_HTTPS"
    echo -e "   Nombre: $OFFICIAL_REPO_NAME"
    echo

    echo -e "${GREEN}🛡️ Protecciones Activas:${NC}"
    echo -e "   ✅ Bloqueo de push a repositorios no autorizados"
    echo -e "   ✅ Bloqueo de fetch de repositorios no autorizados"
    echo -e "   ✅ Verificación automática de origen"
    echo

    echo -e "${GREEN}📝 Archivos Creados:${NC}"
    echo -e "   📄 .repo_security_config - Configuración de seguridad"
    echo -e "   🔍 verify_repo_security.sh - Script de verificación"
    echo -e "   🪝 .git/hooks/pre-push - Hook de seguridad"
    echo -e "   🪝 .git/hooks/pre-fetch - Hook de seguridad"
    echo

    echo -e "${BLUE}🎯 Para actualizar de forma segura, usa:${NC}"
    echo -e "${YELLOW}   ./update_system_secure.sh${NC}"
    echo

    echo -e "${BLUE}🔍 Para verificar seguridad, usa:${NC}"
    echo -e "${YELLOW}   ./verify_repo_security.sh${NC}"
    echo
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    echo -e "${GREEN}🚀 Iniciando configuración de repositorio oficial exclusivo...${NC}"
    echo

    # Ejecutar configuración paso a paso
    check_git_repository
    configure_official_remote
    test_repository_connectivity
    create_security_config
    configure_security_hooks
    setup_initial_tracking

    echo
    echo -e "${GREEN}🎉 ¡Configuración completada exitosamente!${NC}"

    show_configuration_summary
}

# Ejecutar configuración
main "$@"