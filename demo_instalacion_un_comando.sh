#!/bin/bash

# =============================================================================
# DEMOSTRACIÓN DE INSTALACIÓN DE UN COMANDO - WEBMIN Y VIRTUALMIN
# Script para mostrar el proceso completo de instalación automática
# =============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Función para mostrar banner principal
show_main_banner() {
    clear
    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
   🚀 DEMOSTRACIÓN: INSTALACIÓN DE UN SOLO COMANDO
   
   WEBMIN + VIRTUALMIN + AUTHENTIC THEME
   Instalación Completamente Automática y A Prueba de Errores
   
   ✨ Sistema optimizado para Ubuntu 20.04 LTS
   🛡️ Configuración de seguridad automática
   📦 Stack LAMP completo incluido
   🎨 Interfaz moderna con Authentic Theme
   
═══════════════════════════════════════════════════════════════════════════════
EOF
    echo
}

# Mostrar información del sistema
show_system_info() {
    echo -e "${PURPLE}📋 INFORMACIÓN DEL SISTEMA ACTUAL${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo -e "${BLUE}Sistema Operativo:${NC} $(uname -sr)"
    echo -e "${BLUE}Distribución:${NC} $(lsb_release -d 2>/dev/null | cut -f2 || echo "Información no disponible")"
    echo -e "${BLUE}Arquitectura:${NC} $(uname -m)"
    echo -e "${BLUE}Memoria Total:${NC} $(free -h | awk 'NR==2{print $2}' 2>/dev/null || echo "N/A")"
    echo -e "${BLUE}Espacio en Disco:${NC} $(df -h / | awk 'NR==2{print $4}' 2>/dev/null || echo "N/A") disponible"
    echo -e "${BLUE}Fecha y Hora:${NC} $(date)"
    echo
}

# Mostrar comandos de instalación
show_installation_commands() {
    echo -e "${PURPLE}🚀 COMANDOS DE INSTALACIÓN DISPONIBLES${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    echo -e "${CYAN}📥 MÉTODO 1: Instalación Directa desde Internet${NC}"
    echo -e "${WHITE}curl -sSL https://raw.githubusercontent.com/tu-usuario/tu-repo/master/instalacion_un_comando.sh | sudo bash${NC}"
    echo
    
    echo -e "${CYAN}📥 MÉTODO 2: Descarga y Verificación${NC}"
    echo -e "${WHITE}wget https://raw.githubusercontent.com/tu-usuario/tu-repo/master/instalacion_un_comando.sh${NC}"
    echo -e "${WHITE}chmod +x instalacion_un_comando.sh${NC}"
    echo -e "${WHITE}sudo ./instalacion_un_comando.sh${NC}"
    echo
    
    echo -e "${CYAN}📥 MÉTODO 3: Instalación Local (Disponible Ahora)${NC}"
    echo -e "${WHITE}sudo ./instalacion_un_comando.sh${NC}"
    echo
}

# Mostrar características de la instalación
show_installation_features() {
    echo -e "${PURPLE}✨ CARACTERÍSTICAS DE LA INSTALACIÓN AUTOMÁTICA${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    echo -e "${GREEN}🛡️ SEGURIDAD Y ROBUSTEZ:${NC}"
    echo "   ✅ Detección automática del sistema operativo"
    echo "   ✅ Validación de requisitos antes de la instalación"
    echo "   ✅ Backup automático del sistema antes de cambios"
    echo "   ✅ Manejo robusto de errores con recuperación automática"
    echo "   ✅ Logs detallados de todo el proceso"
    echo
    
    echo -e "${GREEN}🔧 COMPONENTES INSTALADOS:${NC}"
    echo "   📦 Webmin - Panel de administración del servidor"
    echo "   🏢 Virtualmin GPL - Gestión completa de hosting"
    echo "   🎨 Authentic Theme - Interfaz moderna y responsive"
    echo "   🌐 Apache HTTP Server - Servidor web optimizado"
    echo "   🗄️ MySQL Server - Base de datos optimizada"
    echo "   🐘 PHP - Lenguaje de programación web"
    echo "   📧 Postfix - Servidor de correo configurado"
    echo "   🔒 SSL/TLS - Certificados automáticos"
    echo "   🛡️ UFW Firewall - Configuración de seguridad"
    echo
    
    echo -e "${GREEN}⚡ OPTIMIZACIONES INCLUIDAS:${NC}"
    echo "   🚀 Configuración optimizada para producción"
    echo "   📈 Límites del sistema ajustados automáticamente"
    echo "   🔧 MySQL optimizado para hosting múltiple"
    echo "   🌐 Apache con módulos esenciales habilitados"
    echo "   🔐 Configuración de seguridad robusta"
    echo "   💾 Gestión optimizada de memoria y recursos"
    echo
}

# Mostrar el proceso paso a paso
show_installation_process() {
    echo -e "${PURPLE}📋 PROCESO DE INSTALACIÓN PASO A PASO${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    echo -e "${BLUE}🔍 FASE 1: Verificaciones Iniciales (2-3 minutos)${NC}"
    echo "   • Verificación de privilegios root"
    echo "   • Detección del sistema operativo y versión"
    echo "   • Verificación de conectividad de red"
    echo "   • Verificación de requisitos mínimos"
    echo "   • Creación de backup de seguridad"
    echo
    
    echo -e "${BLUE}🔄 FASE 2: Preparación del Sistema (3-5 minutos)${NC}"
    echo "   • Actualización de repositorios de paquetes"
    echo "   • Instalación de dependencias esenciales"
    echo "   • Configuración básica de seguridad"
    echo "   • Optimización de configuraciones del sistema"
    echo "   • Preparación de directorios temporales"
    echo
    
    echo -e "${BLUE}📦 FASE 3: Instalación de Componentes (8-12 minutos)${NC}"
    echo "   • Configuración de repositorio oficial de Webmin"
    echo "   • Instalación de Webmin desde fuentes oficiales"
    echo "   • Descarga e instalación de Virtualmin GPL"
    echo "   • Configuración del stack LAMP completo"
    echo "   • Instalación y configuración de Authentic Theme"
    echo
    
    echo -e "${BLUE}🔧 FASE 4: Configuración Final (2-3 minutos)${NC}"
    echo "   • Generación de certificados SSL automáticos"
    echo "   • Configuración del firewall UFW"
    echo "   • Aplicación de optimizaciones de producción"
    echo "   • Verificación completa del sistema"
    echo "   • Limpieza de archivos temporales"
    echo
    
    echo -e "${GREEN}⏱️ TIEMPO TOTAL ESTIMADO: 15-23 minutos${NC}"
    echo
}

# Mostrar resultados esperados
show_expected_results() {
    echo -e "${PURPLE}🎯 RESULTADOS DESPUÉS DE LA INSTALACIÓN${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    echo -e "${GREEN}📡 ACCESO AL PANEL:${NC}"
    echo "   🌐 URL: https://$(hostname -I | awk '{print $1}' 2>/dev/null || echo "TU-IP-SERVIDOR"):10000"
    echo "   👤 Usuario: root"
    echo "   🔐 Contraseña: [tu contraseña de root del sistema]"
    echo
    
    echo -e "${GREEN}🔧 SERVICIOS ACTIVOS:${NC}"
    echo "   ✅ Webmin (puerto 10000) - Panel de administración"
    echo "   ✅ Apache (puertos 80, 443) - Servidor web"
    echo "   ✅ MySQL (puerto 3306) - Base de datos"
    echo "   ✅ Postfix (puerto 25) - Servidor de correo"
    echo "   ✅ SSH (puerto 22) - Acceso remoto seguro"
    echo
    
    echo -e "${GREEN}🎨 INTERFAZ MODERNA:${NC}"
    echo "   🖥️ Authentic Theme activado automáticamente"
    echo "   📱 Interfaz responsive para móviles y tablets"
    echo "   🌍 Soporte multiidioma (español incluido)"
    echo "   📊 Gráficos y estadísticas en tiempo real"
    echo
    
    echo -e "${GREEN}🏢 VIRTUALMIN LISTO:${NC}"
    echo "   🌐 Gestión completa de dominios virtuales"
    echo "   📧 Configuración automática de correo electrónico"
    echo "   🗄️ Gestión de bases de datos MySQL"
    echo "   📂 Administración de archivos web"
    echo "   🔒 Certificados SSL automáticos"
    echo
}

# Mostrar comandos de verificación
show_verification_commands() {
    echo -e "${PURPLE}🔍 VERIFICACIÓN POST-INSTALACIÓN${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    echo -e "${CYAN}🚀 Verificación Automática Completa:${NC}"
    echo -e "${WHITE}sudo ./verificar_instalacion_un_comando.sh${NC}"
    echo
    
    echo -e "${CYAN}🔧 Verificaciones Manuales Básicas:${NC}"
    echo -e "${WHITE}# Estado de servicios${NC}"
    echo -e "${WHITE}sudo systemctl status webmin apache2 mysql${NC}"
    echo
    echo -e "${WHITE}# Verificar puertos abiertos${NC}"
    echo -e "${WHITE}sudo netstat -tlnp | grep -E ':(10000|80|443)'${NC}"
    echo
    echo -e "${WHITE}# Acceso a Webmin${NC}"
    echo -e "${WHITE}curl -k https://localhost:10000${NC}"
    echo
    echo -e "${WHITE}# Verificar Virtualmin${NC}"
    echo -e "${WHITE}sudo virtualmin list-domains${NC}"
    echo
}

# Mostrar información de soporte
show_support_info() {
    echo -e "${PURPLE}🆘 SOPORTE Y RESOLUCIÓN DE PROBLEMAS${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    echo -e "${BLUE}📋 Archivos de Log Importantes:${NC}"
    echo "   📄 /var/log/webmin-virtualmin-install.log"
    echo "   📄 /var/webmin/miniserv.error"
    echo "   📄 /var/log/apache2/error.log"
    echo "   📄 /var/log/mysql/error.log"
    echo
    
    echo -e "${BLUE}💾 Ubicaciones de Backup:${NC}"
    echo "   📁 /root/webmin-virtualmin-backup-[timestamp]/"
    echo "   📁 /etc/webmin/ (configuración principal)"
    echo "   📁 /etc/apache2/ (configuración de Apache)"
    echo
    
    echo -e "${BLUE}🔧 Comandos de Recuperación:${NC}"
    echo "   🔄 sudo systemctl restart webmin"
    echo "   🔄 sudo systemctl restart apache2"
    echo "   🔄 sudo systemctl restart mysql"
    echo "   🛡️ sudo ufw status"
    echo
}

# Función para simular instalación (modo demo)
demo_installation() {
    echo -e "${PURPLE}🎬 SIMULACIÓN DE INSTALACIÓN${NC}"
    echo "─────────────────────────────────────────────────────────────────────────────"
    echo
    
    local steps=(
        "🔍 Verificando privilegios de root..."
        "🖥️ Detectando sistema operativo: Ubuntu 20.04 LTS"
        "🌐 Verificando conectividad de red..."
        "💾 Creando backup del sistema..."
        "🔄 Actualizando repositorios de paquetes..."
        "📦 Instalando dependencias esenciales..."
        "🎛️ Configurando repositorio de Webmin..."
        "⬇️ Descargando e instalando Webmin..."
        "🏢 Descargando script de Virtualmin..."
        "⚙️ Instalando Virtualmin GPL con stack LAMP..."
        "🎨 Instalando Authentic Theme..."
        "🔒 Generando certificados SSL..."
        "🛡️ Configurando firewall UFW..."
        "⚡ Aplicando optimizaciones de producción..."
        "✅ Verificando instalación completa..."
        "🧹 Limpiando archivos temporales..."
    )
    
    for step in "${steps[@]}"; do
        echo -e "${GREEN}$step${NC}"
        sleep 1
    done
    
    echo
    echo -e "${GREEN}🎉 ¡INSTALACIÓN SIMULADA COMPLETADA!${NC}"
    echo
}

# Menú interactivo
show_interactive_menu() {
    while true; do
        echo -e "${PURPLE}📋 MENÚ DE DEMOSTRACIÓN${NC}"
        echo "─────────────────────────────────────────────────────────────────────────────"
        echo
        echo "1) 🔍 Ver información del sistema"
        echo "2) 🚀 Mostrar comandos de instalación"
        echo "3) ✨ Ver características de la instalación"
        echo "4) 📋 Ver proceso paso a paso"
        echo "5) 🎯 Ver resultados esperados"
        echo "6) 🔍 Ver comandos de verificación"
        echo "7) 🆘 Ver información de soporte"
        echo "8) 🎬 Ejecutar simulación de instalación"
        echo "9) 🚀 Ejecutar instalación real (requiere sudo)"
        echo "0) ❌ Salir"
        echo
        echo -n "Selecciona una opción (0-9): "
        
        read -r choice
        echo
        
        case $choice in
            1) show_system_info ;;
            2) show_installation_commands ;;
            3) show_installation_features ;;
            4) show_installation_process ;;
            5) show_expected_results ;;
            6) show_verification_commands ;;
            7) show_support_info ;;
            8) demo_installation ;;
            9) 
                echo -e "${YELLOW}⚠️ ATENCIÓN: Esto ejecutará la instalación real${NC}"
                echo -n "¿Estás seguro? (y/N): "
                read -r confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Ejecutando instalación real...${NC}"
                    sudo ./instalacion_un_comando.sh
                else
                    echo -e "${BLUE}Instalación cancelada${NC}"
                fi
                ;;
            0) 
                echo -e "${GREEN}¡Gracias por usar la demostración!${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Opción inválida. Por favor selecciona 0-9.${NC}"
                ;;
        esac
        
        echo
        echo -e "${BLUE}Presiona Enter para continuar...${NC}"
        read -r
        clear
        show_main_banner
    done
}

# Función principal
main() {
    show_main_banner
    
    # Verificar si estamos en el directorio correcto
    if [[ ! -f "instalacion_un_comando.sh" ]]; then
        echo -e "${RED}❌ Error: No se encuentra el archivo instalacion_un_comando.sh${NC}"
        echo -e "${BLUE}Asegúrate de estar en el directorio correcto${NC}"
        exit 1
    fi
    
    # Mostrar información inicial
    show_system_info
    
    echo -e "${CYAN}🎯 Esta demostración te mostrará todas las características de la instalación${NC}"
    echo -e "${CYAN}   automática de Webmin y Virtualmin con un solo comando.${NC}"
    echo
    echo -e "${BLUE}Presiona Enter para comenzar...${NC}"
    read -r
    
    # Mostrar menú interactivo
    show_interactive_menu
}

# Ejecutar función principal
main "$@"
