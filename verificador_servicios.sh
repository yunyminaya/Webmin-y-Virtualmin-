#!/bin/bash

# Verificador de Servicios Webmin/Virtualmin
# Verifica estado de todos los servicios sin necesidad de permisos root

STRICT=0 # --strict hace que el script salga con código !=0 si hay problemas
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
  esac
done

# Configuración de colores
# Cargar biblioteca de funciones comunes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    echo "❌ Error: No se encontró lib/common_functions.sh"
    exit 1
fi

# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh
# Colores definidos en common_functions.sh

echo -e "${BLUE}=== VERIFICADOR DE SERVICIOS WEBMIN/VIRTUALMIN ===${NC}"
echo "Fecha: $(date)"
echo "Sistema: $(uname -s) $(uname -r)"
echo "Hostname: $(hostname)"
echo ""

# Función para verificar servicios
check_service() {
    local service_name="$1"
    local display_name="$2"
    local port="$3"
    
    echo -n "Verificando $display_name... "
    
    # Verificar si el servicio existe
    if ! systemctl list-unit-files | grep -q "^${service_name}\.service" 2>/dev/null; then
        echo -e "${YELLOW}NO INSTALADO${NC}"
        return 1
    fi
    
    # Verificar si está activo
    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        echo -e "${GREEN}ACTIVO${NC}"
        
        # Verificar puerto si se especifica
        if [[ -n "$port" ]]; then
            # Preferir ss sobre netstat
            if ss -tuln 2>/dev/null | grep -q ":${port} " || netstat -tuln 2>/dev/null | grep -q ":${port} "; then
                echo "  └─ Puerto $port: ${GREEN}ABIERTO${NC}"
            else
                echo "  └─ Puerto $port: ${RED}CERRADO${NC}"
            fi
        fi
        
        # Verificar errores recientes
        local errors=$(journalctl -u "$service_name" --since "1 hour ago" --priority=err --no-pager -q 2>/dev/null | wc -l)
        if [[ "$errors" -gt 0 ]]; then
            echo "  └─ Errores recientes: ${RED}$errors${NC}"
        else
            echo "  └─ Sin errores recientes: ${GREEN}OK${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}INACTIVO${NC}"
        
        # Verificar si está habilitado
        if systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
            echo "  └─ Estado: ${YELLOW}Habilitado pero no iniciado${NC}"
        else
            echo "  └─ Estado: ${RED}Deshabilitado${NC}"
        fi
        
        return 1
    fi
}

# Función para verificar comandos
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

# Función para verificar puertos
check_port() {
    local port="$1"
    local service_name="$2"
    
    echo -n "Puerto $port ($service_name)... "
    
    if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
        echo -e "${GREEN}ABIERTO${NC}"
        
        # Mostrar procesos escuchando en el puerto
        local process
        if command -v ss >/dev/null 2>&1; then
            process=$(ss -tulnp 2>/dev/null | grep ":${port} " | awk -F'users:' '{print $2}' | head -1)
        elif command -v netstat >/dev/null 2>&1; then
            process=$(netstat -tulnp 2>/dev/null | grep ":${port} " | awk '{print $7}' | head -1)
        fi
        
        if [[ -n "$process" && "$process" != "-" ]]; then
            echo "  └─ Proceso: $process"
        fi
        
        return 0
    else
        echo -e "${RED}CERRADO${NC}"
        return 1
    fi
}

echo -e "${BLUE}=== VERIFICACIÓN DE COMANDOS PRINCIPALES ===${NC}"
check_command "webmin" "Webmin"
check_command "virtualmin" "Virtualmin"
check_command "apache2" "Apache Web Server"
check_command "nginx" "Nginx Web Server"
check_command "mysql" "MySQL Database"
check_command "postgresql" "PostgreSQL Database"
check_command "postfix" "Postfix Mail Server"
check_command "dovecot" "Dovecot IMAP/POP3"
check_command "named" "BIND DNS Server"

echo ""
echo -e "${BLUE}=== VERIFICACIÓN DE SERVICIOS ===${NC}"

# Servicios principales
services=(
    "webmin:Webmin:10000"
    "apache2:Apache Web Server:80"
    "nginx:Nginx Web Server:80"
    "mysql:MySQL Database:3306"
    "postgresql:PostgreSQL Database:5432"
    "postfix:Postfix Mail:25"
    "dovecot:Dovecot IMAP/POP3:993"
    "named:BIND DNS:53"
    "bind9:BIND9 DNS:53"
    "ssh:SSH Server:22"
    "fail2ban:Fail2Ban:"
    "ufw:Firewall UFW:"
    "cron:Cron Scheduler:"
    "rsyslog:System Logging:"
)

active_services=0
total_services=0

for service_info in "${services[@]}"; do
    IFS=':' read -r service display port <<< "$service_info"
    total_services=$((total_services + 1))
    
    if check_service "$service" "$display" "$port"; then
        active_services=$((active_services + 1))
    fi
done

echo ""
echo -e "${BLUE}=== VERIFICACIÓN DE PUERTOS CRÍTICOS ===${NC}"

# Puertos importantes
ports=(
    "22:SSH"
    "25:SMTP"
    "53:DNS"
    "80:HTTP"
    "110:POP3"
    "143:IMAP"
    "443:HTTPS"
    "587:SMTP Submission"
    "993:IMAPS"
    "995:POP3S"
    "10000:Webmin"
    "20000:Usermin"
)

open_ports=0
total_ports=${#ports[@]}

for port_info in "${ports[@]}"; do
    IFS=':' read -r port service <<< "$port_info"
    
    if check_port "$port" "$service"; then
        open_ports=$((open_ports + 1))
    fi
done

echo ""
echo -e "${BLUE}=== VERIFICACIÓN DE CONFIGURACIONES ===${NC}"

# Verificar archivos de configuración importantes
config_errors=0
configs=(
    "/etc/webmin/miniserv.conf:Configuración Webmin"
    "/etc/webmin/config:Configuración base Webmin"
    "/etc/apache2/apache2.conf:Configuración Apache"
    "/etc/nginx/nginx.conf:Configuración Nginx"
    "/etc/postfix/main.cf:Configuración Postfix"
    "/etc/mysql/mysql.conf.d/mysqld.cnf:Configuración MySQL"
    "/etc/dovecot/dovecot.conf:Configuración Dovecot"
)

for config_info in "${configs[@]}"; do
    IFS=':' read -r config_file config_name <<< "$config_info"
    
    echo -n "Verificando $config_name... "
    
    if [[ -f "$config_file" ]]; then
        echo -e "${GREEN}EXISTE${NC}"
        
        # Verificar permisos
        local perms=$(stat -c "%a" "$config_file" 2>/dev/null || echo "N/A")
        echo "  └─ Permisos: $perms"
        
        # Verificar tamaño
        local size=$(stat -c "%s" "$config_file" 2>/dev/null || echo "0")
        if [[ "$size" -eq 0 ]]; then
            echo "  └─ ${RED}ARCHIVO VACÍO${NC}"
            config_errors=$((config_errors + 1))
        else
            echo "  └─ Tamaño: $(( size / 1024 ))KB"
        fi
    else
        echo -e "${RED}NO EXISTE${NC}"
        config_errors=$((config_errors + 1))
    fi
done

echo ""
echo -e "${BLUE}=== VERIFICACIÓN DE CONECTIVIDAD ===${NC}"

# Verificar conectividad
echo -n "Conectividad externa (download.webmin.com)... "
if curl -fsSIL --connect-timeout 5 "https://download.webmin.com/" >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FALLO${NC}"
fi

echo -n "Loopback (localhost)... "
if getent hosts localhost >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FALLO${NC}"
fi

# Verificar acceso a Webmin
echo -n "Acceso a Webmin (HTTPS)... "
if curl -k -s --connect-timeout 5 "https://localhost:10000" >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
elif curl -k -s --connect-timeout 5 "http://localhost:10000" >/dev/null 2>&1; then
    echo -e "${YELLOW}OK (HTTP)${NC}"
else
    echo -e "${RED}FALLO${NC}"
fi

echo ""
echo -e "${BLUE}=== RESUMEN DEL SISTEMA ===${NC}"

# Información del sistema
echo "Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
echo "Load Average: $(uptime | awk -F'load average: ' '{print $2}')"
echo "Memoria libre: $(free -h | grep '^Mem:' | awk '{print $7}')"
echo "Espacio en disco: $(df -h / | awk 'NR==2 {print $4 " libre de " $2}')"
echo "Procesos activos: $(ps aux | wc -l)"

echo ""
echo -e "${BLUE}=== ESTADO GENERAL ===${NC}"

echo "Servicios activos: ${active_services}/${total_services}"
echo "Puertos abiertos: ${open_ports}/${total_ports}"
echo "Configs OK: $(( ${#configs[@]} - config_errors ))/${#configs[@]}"

# Calcular porcentaje de salud del sistema
health_score=$(( (active_services * 100 / total_services + open_ports * 100 / total_ports) / 2 ))

if [[ $health_score -ge 80 ]]; then
    echo -e "Estado del sistema: ${GREEN}EXCELENTE ($health_score%)${NC}"
elif [[ $health_score -ge 60 ]]; then
    echo -e "Estado del sistema: ${YELLOW}BUENO ($health_score%)${NC}"
elif [[ $health_score -ge 40 ]]; then
    echo -e "Estado del sistema: ${YELLOW}REGULAR ($health_score%)${NC}"
else
    echo -e "Estado del sistema: ${RED}NECESITA ATENCIÓN ($health_score%)${NC}"
fi

echo ""
echo -e "${BLUE}=== RECOMENDACIONES ===${NC}"

if [[ $active_services -lt $total_services ]]; then
    echo "• Revisar servicios inactivos y habilitarlos si es necesario"
fi

if [[ $open_ports -lt 5 ]]; then
    echo "• Verificar configuración de firewall - pocos puertos abiertos"
fi

if ! systemctl is-active --quiet webmin 2>/dev/null; then
    echo "• Webmin no está activo - revisar instalación"
fi

if ! command -v virtualmin >/dev/null 2>&1; then
    echo "• Virtualmin no está instalado o no está en PATH"
fi

echo "• Para reparar problemas automáticamente:"
echo "  ./coordinador_sub_agentes.sh repair-all"

echo ""
echo -e "${GREEN}Verificación completada.${NC}"

# Salir con código según modo estricto
if [[ $STRICT -eq 1 ]]; then
    if [[ $active_services -lt $total_services ]] || [[ $open_ports -lt $total_ports ]] || [[ $config_errors -gt 0 ]]; then
        exit 1
    fi
fi
exit 0
