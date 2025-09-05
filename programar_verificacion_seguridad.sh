#!/bin/bash

# Script para programar verificaciones periódicas de seguridad
# y enviar los resultados por correo electrónico

# Directorio de trabajo
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores para los mensajes
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

# Función para mostrar mensajes
# DUPLICADA: Función reemplazada por common_functions.sh
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
    
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Contenido de función duplicada
# Fin de función duplicada

# Función para mostrar el banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║   Programador de Verificaciones de Seguridad                  ║"
    echo "║   para Webmin y Virtualmin                                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Función para verificar dependencias
check_dependencies() {
    log "INFO" "Verificando dependencias..."
    
    local missing_deps=false
    
    # Verificar si el script de verificación de seguridad existe
    if [ ! -f "$WORK_DIR/verificar_seguridad_completa.sh" ]; then
        log "ERROR" "No se encontró el script de verificación de seguridad"
        missing_deps=true
    else
        # Verificar si el script tiene permisos de ejecución
        if [ ! -x "$WORK_DIR/verificar_seguridad_completa.sh" ]; then
            log "WARNING" "El script de verificación de seguridad no tiene permisos de ejecución"
            log "INFO" "Aplicando permisos de ejecución..."
            chmod +x "$WORK_DIR/verificar_seguridad_completa.sh"
        fi
    fi
    
    # Verificar si mailx está instalado para enviar correos
    if ! command -v mailx &> /dev/null && ! command -v mail &> /dev/null; then
        log "WARNING" "No se encontró mailx o mail para enviar correos"
        log "INFO" "Los reportes se guardarán localmente"
    fi
    
    if [ "$missing_deps" = true ]; then
        log "ERROR" "Faltan dependencias. Por favor, instale las dependencias faltantes."
        return 1
    fi
    
    log "SUCCESS" "Todas las dependencias están instaladas"
    return 0
}

# Función para ejecutar la verificación de seguridad
run_security_check() {
    log "INFO" "Ejecutando verificación de seguridad..."
    
    # Ejecutar el script de verificación de seguridad
    "$WORK_DIR/verificar_seguridad_completa.sh"
    
    # Obtener el último reporte generado
    local report_dir="$WORK_DIR/reportes"
    local latest_report=$(find "$report_dir" -name "reporte_seguridad_*.md" -type f -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$latest_report" ]; then
        log "SUCCESS" "Verificación de seguridad completada"
        log "INFO" "Reporte guardado en: $latest_report"
        echo "$latest_report"
    else
        log "ERROR" "No se encontró el reporte de seguridad"
        return 1
    fi
    
    return 0
}

# Función para enviar el reporte por correo electrónico
send_report_by_email() {
    local report_file="$1"
    local email="$2"
    local server_name="$3"
    
    if [ -z "$email" ]; then
        log "ERROR" "No se especificó una dirección de correo electrónico"
        return 1
    fi
    
    if [ ! -f "$report_file" ]; then
        log "ERROR" "No se encontró el archivo de reporte: $report_file"
        return 1
    fi
    
    log "INFO" "Enviando reporte por correo electrónico a $email..."
    
    # Extraer la puntuación de seguridad del reporte
    local security_score=$(grep -E "^## Puntuación de Seguridad:" "$report_file" | sed 's/^## Puntuación de Seguridad: //')
    
    # Determinar el asunto del correo según la puntuación
    local subject="Reporte de Seguridad de Webmin/Virtualmin"
    
    if [ -n "$security_score" ]; then
        if [ "$server_name" != "" ]; then
            subject="[$server_name] $subject - Puntuación: $security_score"
        else
            subject="$subject - Puntuación: $security_score"
        fi
    elif [ "$server_name" != "" ]; then
        subject="[$server_name] $subject"
    fi
    
    # Enviar el correo
    if command -v mailx &> /dev/null; then
        mailx -s "$subject" "$email" < "$report_file"
    elif command -v mail &> /dev/null; then
        mail -s "$subject" "$email" < "$report_file"
    else
        log "ERROR" "No se encontró mailx o mail para enviar correos"
        return 1
    fi
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Reporte enviado por correo electrónico a $email"
    else
        log "ERROR" "Error al enviar el reporte por correo electrónico"
        return 1
    fi
    
    return 0
}

# Función para configurar la programación de verificaciones
configure_schedule() {
    log "INFO" "Configurando programación de verificaciones..."
    
    # Solicitar información al usuario
    echo -e "\n${CYAN}Configuración de programación de verificaciones${NC}\n"
    
    # Solicitar dirección de correo electrónico
    read -p "Dirección de correo electrónico para recibir reportes: " email
    
    # Solicitar nombre del servidor
    read -p "Nombre del servidor (para identificar en los reportes): " server_name
    
    # Solicitar frecuencia de verificación
    echo -e "\nFrecuencia de verificación:"
    echo "1) Diaria"
    echo "2) Semanal"
    echo "3) Mensual"
    read -p "Seleccione una opción (1-3): " frequency_option
    
    # Determinar la expresión cron según la frecuencia seleccionada
    case "$frequency_option" in
        1)
            frequency="diaria"
            cron_expression="0 3 * * *" # Todos los días a las 3:00 AM
            ;;
        2)
            frequency="semanal"
            cron_expression="0 3 * * 0" # Todos los domingos a las 3:00 AM
            ;;
        3)
            frequency="mensual"
            cron_expression="0 3 1 * *" # El primer día de cada mes a las 3:00 AM
            ;;
        *)
            log "ERROR" "Opción no válida"
            return 1
            ;;
    esac
    
    # Crear el archivo de configuración
    local config_file="$WORK_DIR/security_check_config.conf"
    
    echo "# Configuración de verificación de seguridad" > "$config_file"
    echo "EMAIL=$email" >> "$config_file"
    echo "SERVER_NAME=$server_name" >> "$config_file"
    echo "FREQUENCY=$frequency" >> "$config_file"
    echo "CRON_EXPRESSION=$cron_expression" >> "$config_file"
    
    log "SUCCESS" "Configuración guardada en: $config_file"
    
    # Preguntar si desea instalar la tarea cron
    echo -e "\n${YELLOW}¿Desea instalar la tarea cron para programar las verificaciones?${NC}"
    read -p "(S/N): " install_cron
    
    if [[ "$install_cron" =~ ^[Ss]$ ]]; then
        install_cron_job "$cron_expression"
    else
        echo -e "\n${CYAN}Comando para programar manualmente:${NC}"
        echo "$cron_expression $WORK_DIR/programar_verificacion_seguridad.sh --run"
    fi
    
    return 0
}

# Función para instalar la tarea cron
install_cron_job() {
    local cron_expression="$1"
    
    log "INFO" "Instalando tarea cron..."
    
    # Crear un archivo temporal para el crontab
    local temp_cron=$(mktemp)
    
    # Obtener el crontab actual
    crontab -l > "$temp_cron" 2>/dev/null || echo "" > "$temp_cron"
    
    # Verificar si la tarea ya está instalada
    if grep -q "programar_verificacion_seguridad.sh --run" "$temp_cron"; then
        # Actualizar la tarea existente
        sed -i "s|.* programar_verificacion_seguridad.sh --run.*|$cron_expression $WORK_DIR/programar_verificacion_seguridad.sh --run|" "$temp_cron"
    else
        # Agregar la nueva tarea
        echo "$cron_expression $WORK_DIR/programar_verificacion_seguridad.sh --run" >> "$temp_cron"
    fi
    
    # Instalar el nuevo crontab
    crontab "$temp_cron"
    
    # Eliminar el archivo temporal
    rm -f "$temp_cron"
    
    if [ $? -eq 0 ]; then
        log "SUCCESS" "Tarea cron instalada correctamente"
    else
        log "ERROR" "Error al instalar la tarea cron"
        return 1
    fi
    
    return 0
}

# Función para mostrar la configuración actual
show_current_config() {
    local config_file="$WORK_DIR/security_check_config.conf"
    
    if [ ! -f "$config_file" ]; then
        log "WARNING" "No se encontró el archivo de configuración"
        return 1
    fi
    
    log "INFO" "Configuración actual:"
    
    # Cargar la configuración
    source "$config_file"
    
    echo -e "\n${CYAN}Configuración de verificación de seguridad${NC}"
    echo "Email: $EMAIL"
    echo "Nombre del servidor: $SERVER_NAME"
    echo "Frecuencia: $FREQUENCY"
    echo "Expresión cron: $CRON_EXPRESSION"
    
    # Verificar si la tarea cron está instalada
    if crontab -l 2>/dev/null | grep -q "programar_verificacion_seguridad.sh --run"; then
        echo -e "${GREEN}Estado: Programado${NC}"
    else
        echo -e "${YELLOW}Estado: No programado${NC}"
    fi
    
    return 0
}

# Función para ejecutar una verificación manual
run_manual_check() {
    local config_file="$WORK_DIR/security_check_config.conf"
    
    if [ -f "$config_file" ]; then
        # Cargar la configuración
        source "$config_file"
    fi
    
    # Ejecutar la verificación de seguridad
    local report_file=$(run_security_check)
    
    if [ $? -eq 0 ] && [ -n "$report_file" ]; then
        # Preguntar si desea enviar el reporte por correo electrónico
        if [ -z "$EMAIL" ]; then
            echo -e "\n${YELLOW}¿Desea enviar el reporte por correo electrónico?${NC}"
            read -p "(S/N): " send_email
            
            if [[ "$send_email" =~ ^[Ss]$ ]]; then
                read -p "Dirección de correo electrónico: " email
                read -p "Nombre del servidor (opcional): " server_name
                
                send_report_by_email "$report_file" "$email" "$server_name"
            fi
        else
            echo -e "\n${YELLOW}¿Desea enviar el reporte a $EMAIL?${NC}"
            read -p "(S/N): " send_email
            
            if [[ "$send_email" =~ ^[Ss]$ ]]; then
                send_report_by_email "$report_file" "$EMAIL" "$SERVER_NAME"
            fi
        fi
    fi
    
    return 0
}

# Función para ejecutar la verificación programada
run_scheduled_check() {
    local config_file="$WORK_DIR/security_check_config.conf"
    
    if [ ! -f "$config_file" ]; then
        log "ERROR" "No se encontró el archivo de configuración"
        return 1
    fi
    
    # Cargar la configuración
    source "$config_file"
    
    if [ -z "$EMAIL" ]; then
        log "WARNING" "No se ha configurado una dirección de correo electrónico"
        log "INFO" "Ejecutando verificación sin envío de correo"
    fi
    
    # Ejecutar la verificación de seguridad
    local report_file=$(run_security_check)
    
    if [ $? -eq 0 ] && [ -n "$report_file" ] && [ -n "$EMAIL" ]; then
        send_report_by_email "$report_file" "$EMAIL" "$SERVER_NAME"
    fi
    
    return 0
}

# Función para mostrar el menú principal
show_menu() {
    clear
    show_banner
    
    echo -e "\n${CYAN}Menú Principal${NC}\n"
    echo "1) Ejecutar verificación de seguridad manual"
    echo "2) Configurar programación de verificaciones"
    echo "3) Mostrar configuración actual"
    echo "4) Salir"
    
    read -p "Seleccione una opción (1-4): " option
    
    case "$option" in
        1)
            run_manual_check
            ;;
        2)
            configure_schedule
            ;;
        3)
            show_current_config
            ;;
        4)
            log "INFO" "Saliendo..."
            exit 0
            ;;
        *)
            log "ERROR" "Opción no válida"
            ;;
    esac
    
    echo -e "\nPresione Enter para continuar..."
    read
    
    show_menu
}

# Función principal
main() {
    # Verificar dependencias
    check_dependencies
    
    # Procesar argumentos
    if [ "$1" = "--run" ]; then
        # Modo programado
        run_scheduled_check
    else
        # Modo interactivo
        show_menu
    fi
    
    return 0
}

# Ejecutar la función principal con los argumentos proporcionados
main "$@"
