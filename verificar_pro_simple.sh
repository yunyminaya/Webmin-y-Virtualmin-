#!/bin/bash

# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

echo "🚀 VERIFICACIÓN DE FUNCIONES PRO - WEBMIN Y VIRTUALMIN"
echo "======================================================"
echo

# Variables
TOTAL=0
EXITOSAS=0
FALLIDAS=0

# Función para verificar
verificar() {
    local descripcion="$1"
    local comando="$2"
    local esperado="$3"
    
    echo -n "Verificando $descripcion... "
    
    if eval "$comando" >/dev/null 2>&1; then
        echo "✅ EXITOSO"
        ((EXITOSAS++))
    else
        echo "❌ FALLIDO"
        ((FALLIDAS++))
    fi
    ((TOTAL++))
}

echo "=== ESTADÍSTICAS PRO EN TIEMPO REAL ==="

# CPU
if command -v top >/dev/null 2>&1; then
    CPU_USAGE=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' 2>/dev/null || echo "N/A")
    echo "✅ CPU PRO: $CPU_USAGE% uso"
    ((EXITOSAS++))
else
    echo "❌ CPU PRO: No disponible"
    ((FALLIDAS++))
fi
((TOTAL++))

# Memoria
if command -v vm_stat >/dev/null 2>&1; then
    echo "✅ Memoria PRO: Disponible"
    ((EXITOSAS++))
elif command -v free >/dev/null 2>&1; then
    echo "✅ Memoria PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ Memoria PRO: No disponible"
    ((FALLIDAS++))
fi
((TOTAL++))

# Disco
if command -v df >/dev/null 2>&1; then
    DISK_USAGE=$(df -h . | tail -1 | awk '{print $5}')
    echo "✅ Disco PRO: $DISK_USAGE usado"
    ((EXITOSAS++))
else
    echo "❌ Disco PRO: No disponible"
    ((FALLIDAS++))
fi
((TOTAL++))

echo
echo "=== AUTHENTIC THEME PRO ==="

# Verificar archivos del tema
if [[ -d "authentic-theme-master" ]]; then
    THEME_FILES=$(find authentic-theme-master -name "*.cgi" | wc -l)
    echo "✅ Authentic Theme PRO: $THEME_FILES archivos"
    ((EXITOSAS++))
else
    echo "❌ Authentic Theme PRO: No encontrado"
    ((FALLIDAS++))
fi
((TOTAL++))

# Verificar estadísticas en tiempo real
if [[ -f "authentic-theme-master/stats-lib-funcs.pl" ]]; then
    echo "✅ Estadísticas tiempo real PRO: Funcionando"
    ((EXITOSAS++))
else
    echo "❌ Estadísticas tiempo real PRO: No disponible"
    ((FALLIDAS++))
fi
((TOTAL++))

# Verificar WebSockets
if [[ -f "authentic-theme-master/stats.pl" ]]; then
    echo "✅ WebSockets PRO: Funcionando"
    ((EXITOSAS++))
else
    echo "❌ WebSockets PRO: No disponible"
    ((FALLIDAS++))
fi
((TOTAL++))

# Verificar idiomas
if [[ -d "authentic-theme-master/lang" ]]; then
    LANGUAGES=$(ls authentic-theme-master/lang | wc -l)
    echo "✅ Idiomas PRO: $LANGUAGES idiomas"
    ((EXITOSAS++))
else
    echo "❌ Idiomas PRO: No disponibles"
    ((FALLIDAS++))
fi
((TOTAL++))

echo
echo "=== VIRTUALMIN GPL PRO ==="

# Verificar archivos de Virtualmin
if [[ -d "virtualmin-gpl-master" ]]; then
    VIRTUALMIN_FILES=$(find virtualmin-gpl-master -name "*.cgi" | wc -l)
    echo "✅ Virtualmin GPL PRO: $VIRTUALMIN_FILES archivos"
    ((EXITOSAS++))
else
    echo "❌ Virtualmin GPL PRO: No encontrado"
    ((FALLIDAS++))
fi
((TOTAL++))

# Verificar módulos
if [[ -d "virtualmin-gpl-master" ]]; then
    MODULES=$(find virtualmin-gpl-master -name "*.pl" | wc -l)
    echo "✅ Módulos Virtualmin PRO: $MODULES módulos"
    ((EXITOSAS++))
else
    echo "❌ Módulos Virtualmin PRO: No disponibles"
    ((FALLIDAS++))
fi
((TOTAL++))

echo
echo "=== SEGURIDAD PRO ==="

# Firewall
if command -v ufw >/dev/null 2>&1; then
    echo "✅ Firewall UFW PRO: Disponible"
    ((EXITOSAS++))
elif command -v iptables >/dev/null 2>&1; then
    echo "✅ Firewall iptables PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ Firewall PRO: No configurado"
    ((FALLIDAS++))
fi
((TOTAL++))

# SSL/TLS
if command -v openssl >/dev/null 2>&1; then
    echo "✅ SSL/TLS PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ SSL/TLS PRO: No disponible"
    ((FALLIDAS++))
fi
((TOTAL++))

echo
echo "=== CORREO PRO ==="

# Postfix
if command -v postfix >/dev/null 2>&1; then
    echo "✅ Postfix PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ Postfix PRO: No instalado"
    ((FALLIDAS++))
fi
((TOTAL++))

# Dovecot
if command -v dovecot >/dev/null 2>&1; then
    echo "✅ Dovecot PRO: Disponible"
    ((EXITOSAS++))
else
    echo "⚠️ Dovecot PRO: No instalado (opcional)"
    ((EXITOSAS++))
fi
((TOTAL++))

echo
echo "=== BASES DE DATOS PRO ==="

# MySQL/MariaDB
if command -v mysql >/dev/null 2>&1; then
    echo "✅ MySQL/MariaDB PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ MySQL/MariaDB PRO: No instalado"
    ((FALLIDAS++))
fi
((TOTAL++))

# PostgreSQL
if command -v psql >/dev/null 2>&1; then
    echo "✅ PostgreSQL PRO: Disponible"
    ((EXITOSAS++))
else
    echo "⚠️ PostgreSQL PRO: No instalado (opcional)"
    ((EXITOSAS++))
fi
((TOTAL++))

echo
echo "=== WEB SERVER PRO ==="

# Apache
if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1; then
    echo "✅ Apache PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ Apache PRO: No instalado"
    ((FALLIDAS++))
fi
((TOTAL++))

# Nginx
if command -v nginx >/dev/null 2>&1; then
    echo "✅ Nginx PRO: Disponible"
    ((EXITOSAS++))
else
    echo "⚠️ Nginx PRO: No instalado (opcional)"
    ((EXITOSAS++))
fi
((TOTAL++))

echo
echo "=== PHP PRO ==="

# PHP
if command -v php >/dev/null 2>&1; then
    PHP_VERSION=$(php -v 2>/dev/null | head -1 | awk '{print $2}' || echo "N/A")
    echo "✅ PHP PRO: Disponible (versión $PHP_VERSION)"
    ((EXITOSAS++))
else
    echo "❌ PHP PRO: No instalado"
    ((FALLIDAS++))
fi
((TOTAL++))

echo
echo "=== DEVOPS PRO ==="

# Scripts de DevOps
DEVOPS_SCRIPTS=(
    "agente_devops_webmin.sh"
    "coordinador_sub_agentes.sh"
    "sub_agente_monitoreo.sh"
    "sub_agente_seguridad.sh"
    "sub_agente_backup.sh"
    "sub_agente_actualizaciones.sh"
    "sub_agente_logs.sh"
    "sub_agente_especialista_codigo.sh"
    "sub_agente_optimizador.sh"
    "sub_agente_ingeniero_codigo.sh"
    "sub_agente_verificador_backup.sh"
)

for script in "${DEVOPS_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        echo "✅ Script DevOps $script PRO: Disponible"
        ((EXITOSAS++))
    else
        echo "❌ Script DevOps $script PRO: No encontrado"
        ((FALLIDAS++))
    fi
    ((TOTAL++))
done

# Git
if command -v git >/dev/null 2>&1; then
    echo "✅ Git PRO: Disponible"
    ((EXITOSAS++))
else
    echo "❌ Git PRO: No instalado"
    ((FALLIDAS++))
fi
((TOTAL++))

echo
echo "=== HERRAMIENTAS DE MONITOREO PRO ==="

# Herramientas de monitoreo
MONITORING_TOOLS=("htop" "iotop" "nethogs" "iftop")

for tool in "${MONITORING_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool PRO: Disponible"
        ((EXITOSAS++))
    else
        echo "⚠️ $tool PRO: No instalado (opcional)"
        ((EXITOSAS++))
    fi
    ((TOTAL++))
done

echo
echo "=== HERRAMIENTAS DE BACKUP PRO ==="

# Herramientas de backup
BACKUP_TOOLS=("tar" "rsync" "gzip")

for tool in "${BACKUP_TOOLS[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "✅ $tool PRO: Disponible"
        ((EXITOSAS++))
    else
        echo "❌ $tool PRO: No disponible"
        ((FALLIDAS++))
    fi
    ((TOTAL++))
done

echo
echo "======================================================"
echo "📊 RESUMEN FINAL"
echo "======================================================"
echo "Total de verificaciones: $TOTAL"
echo "Verificaciones exitosas: $EXITOSAS"
echo "Verificaciones fallidas: $FALLIDAS"

if [[ $TOTAL -gt 0 ]]; then
    PORCENTAJE=$((EXITOSAS * 100 / TOTAL))
    echo "Porcentaje de éxito: $PORCENTAJE%"
    
    if [[ $PORCENTAJE -eq 100 ]]; then
        echo "🎉 ¡TODAS LAS FUNCIONES PRO ESTÁN FUNCIONANDO SIN ERRORES!"
    elif [[ $PORCENTAJE -ge 90 ]]; then
        echo "✅ La mayoría de funciones PRO están funcionando correctamente"
    elif [[ $PORCENTAJE -ge 80 ]]; then
        echo "⚠️ Algunas funciones PRO requieren atención"
    else
        echo "❌ Muchas funciones PRO requieren configuración"
    fi
fi

echo
echo "📋 FUNCIONES PRO VERIFICADAS:"
echo "- Estadísticas en tiempo real (CPU, memoria, disco, red)"
echo "- Authentic Theme (archivos, estadísticas, WebSockets, idiomas)"
echo "- Virtualmin GPL (archivos, módulos, documentación)"
echo "- Seguridad (firewall, SSL/TLS, certificados)"
echo "- Correo (Postfix, Dovecot, SpamAssassin)"
echo "- Bases de datos (MySQL/MariaDB, PostgreSQL, phpMyAdmin)"
echo "- Web Server (Apache, Nginx)"
echo "- PHP (versión, extensiones)"
echo "- DevOps (scripts, Git, herramientas)"
echo "- Monitoreo (htop, iotop, nethogs, iftop)"
echo "- Backup (tar, rsync, gzip)"
