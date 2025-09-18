#!/bin/bash

# Script de Soporte para Contenedores
# Genera configuración Docker/Podman para Virtualmin + Authentic Theme
# Versión: 1.0.0 - Proof of Concept

set -euo pipefail
IFS=$'\n\t'

# Directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ===== INCLUIR BIBLIOTECA COMÚN =====
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: No se encuentra la biblioteca común en ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

# Variables de configuración (configurables)
CONTAINER_NAME="${CONTAINER_NAME:-virtualmin-webmin}"
HOST_PORT_WEBMIN="${WEBMIN_PORT:-10000}"
HOST_PORT_HTTP="${HTTP_PORT:-80}"
HOST_PORT_HTTPS="${HTTPS_PORT:-443}"
CONTAINER_ENGINE="${CONTAINER_ENGINE:-docker}" # docker o podman

# Función para verificar soporte de contenedores
check_container_support() {
    log_step "Verificando soporte de contenedores..."

    if [[ "$CONTAINER_ENGINE" == "docker" ]]; then
        if ! command_exists docker; then
            log_error "Docker no está instalado"
            log_info "Instala Docker: https://docs.docker.com/get-docker/"
            return 1
        fi

        if ! docker info >/dev/null 2>&1; then
            log_error "Docker daemon no está ejecutándose"
            log_info "Inicia Docker: sudo systemctl start docker"
            return 1
        fi

        log_success "Docker está disponible"

    elif [[ "$CONTAINER_ENGINE" == "podman" ]]; then
        if ! command_exists podman; then
            log_error "Podman no está instalado"
            log_info "Instala Podman: sudo apt install podman"
            return 1
        fi

        log_success "Podman está disponible"
    else
        log_error "Motor de contenedores no soportado: $CONTAINER_ENGINE"
        log_info "Usa 'docker' o 'podman'"
        return 1
    fi

    return 0
}

# Función para generar Dockerfile
generate_dockerfile() {
    local dockerfile_path="$SCRIPT_DIR/Dockerfile"
    log_step "Generando Dockerfile..."

    cat > "$dockerfile_path" << 'EOF'
# Dockerfile para Virtualmin + Authentic Theme
FROM ubuntu:22.04

# Evitar prompts interactivos
ENV DEBIAN_FRONTEND=noninteractive
ENV WEBMIN_PORT=10000

# Instalar dependencias básicas
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    software-properties-common \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Instalar Virtualmin
RUN wget -O install.sh https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh \
    && chmod +x install.sh \
    && ./install.sh --bundle LAMP --yes --force \
    && rm install.sh

# Exponer puertos
EXPOSE 10000 80 443 21 22 25 110 143 465 587 993 995

# Configurar volúmenes persistentes
VOLUME ["/etc/webmin", "/var/webmin", "/etc/virtualmin", "/home", "/var/lib/mysql"]

# Comando de inicio
CMD ["/etc/init.d/webmin", "start", "&&", "/etc/init.d/apache2", "start", "&&", "tail", "-f", "/var/log/webmin/miniserv.log"]
EOF

    log_success "Dockerfile generado: $dockerfile_path"
}

# Función para generar docker-compose.yml
generate_docker_compose() {
    local compose_path="$SCRIPT_DIR/docker-compose.yml"
    log_step "Generando docker-compose.yml..."

    cat > "$compose_path" << EOF
version: '3.8'

services:
  virtualmin:
    build: .
    container_name: $CONTAINER_NAME
    ports:
      - "$HOST_PORT_WEBMIN:10000"    # Webmin/Virtualmin
      - "$HOST_PORT_HTTP:80"         # HTTP
      - "$HOST_PORT_HTTPS:443"       # HTTPS
      - "21:21"                      # FTP
      - "22:22"                      # SSH
      - "25:25"                      # SMTP
      - "110:110"                    # POP3
      - "143:143"                    # IMAP
      - "465:465"                    # SMTPS
      - "587:587"                    # Submission
      - "993:993"                    # IMAPS
      - "995:995"                    # POP3S
    volumes:
      - webmin_config:/etc/webmin
      - webmin_var:/var/webmin
      - virtualmin_config:/etc/virtualmin
      - user_homes:/home
      - mysql_data:/var/lib/mysql
      - apache_logs:/var/log/apache2
      - ./backups:/backups
    environment:
      - WEBMIN_PORT=10000
      - VIRTUALMIN_DOMAIN=localhost
    restart: unless-stopped
    networks:
      - virtualmin_network

  # Base de datos externa (opcional)
  mysql:
    image: mysql:8.0
    container_name: virtualmin_mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:-virtualmin_pass}
      MYSQL_DATABASE: virtualmin
      MYSQL_USER: virtualmin
      MYSQL_PASSWORD: ${MYSQL_PASSWORD:-virtualmin_pass}
    volumes:
      - mysql_data:/var/lib/mysql
    restart: unless-stopped
    networks:
      - virtualmin_network
    profiles:
      - with_db

volumes:
  webmin_config:
  webmin_var:
  virtualmin_config:
  user_homes:
  mysql_data:
  apache_logs:

networks:
  virtualmin_network:
    driver: bridge
EOF

    log_success "docker-compose.yml generado: $compose_path"
}

# Función para generar script de gestión de contenedores
generate_container_manager() {
    local manager_script="$SCRIPT_DIR/manage_container.sh"
    log_step "Generando script de gestión de contenedores..."

    cat > "$manager_script" << EOF
#!/bin/bash

# Script de Gestión de Contenedores Virtualmin
# Uso: ./manage_container.sh [start|stop|restart|status|logs|shell]

set -euo pipefail

CONTAINER_NAME="$CONTAINER_NAME"
CONTAINER_ENGINE="$CONTAINER_ENGINE"

# Función para verificar si el contenedor existe
container_exists() {
    if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
        docker ps -a --format 'table {{.Names}}' | grep -q "^\${CONTAINER_NAME}$"
    else
        podman ps -a --format 'table {{.Names}}' | grep -q "^\${CONTAINER_NAME}$"
    fi
}

# Función para verificar si el contenedor está ejecutándose
container_running() {
    if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
        docker ps --format 'table {{.Names}}' | grep -q "^\${CONTAINER_NAME}$"
    else
        podman ps --format 'table {{.Names}}' | grep -q "^\${CONTAINER_NAME}$"
    fi
}

case "\${1:-help}" in
    "start")
        echo "Iniciando contenedor Virtualmin..."
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker-compose up -d
        else
            podman-compose up -d
        fi
        ;;
    "stop")
        echo "Deteniendo contenedor Virtualmin..."
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker-compose down
        else
            podman-compose down
        fi
        ;;
    "restart")
        echo "Reiniciando contenedor Virtualmin..."
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker-compose restart
        else
            podman-compose restart
        fi
        ;;
    "status")
        echo "Estado del contenedor:"
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker ps -a --filter name=\${CONTAINER_NAME}
        else
            podman ps -a --filter name=\${CONTAINER_NAME}
        fi
        ;;
    "logs")
        echo "Logs del contenedor:"
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker-compose logs -f
        else
            podman-compose logs -f
        fi
        ;;
    "shell")
        echo "Conectando al shell del contenedor..."
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker exec -it \${CONTAINER_NAME} /bin/bash
        else
            podman exec -it \${CONTAINER_NAME} /bin/bash
        fi
        ;;
    "build")
        echo "Construyendo imagen del contenedor..."
        if [[ "\$CONTAINER_ENGINE" == "docker" ]]; then
            docker-compose build --no-cache
        else
            echo "Para Podman, construye manualmente con podman build"
        fi
        ;;
    *)
        echo "Uso: \$0 [start|stop|restart|status|logs|shell|build]"
        echo ""
        echo "Comandos disponibles:"
        echo "  start   - Iniciar el contenedor"
        echo "  stop    - Detener el contenedor"
        echo "  restart - Reiniciar el contenedor"
        echo "  status  - Mostrar estado del contenedor"
        echo "  logs    - Ver logs del contenedor"
        echo "  shell   - Conectar al shell del contenedor"
        echo "  build   - Construir imagen del contenedor"
        ;;
esac
EOF

    chmod +x "$manager_script"
    log_success "Script de gestión generado: $manager_script"
}

# Función para generar archivo .env de ejemplo
generate_env_example() {
    local env_path="$SCRIPT_DIR/.env.example"
    log_step "Generando archivo .env de ejemplo..."

    cat > "$env_path" << 'EOF'
# Configuración de Virtualmin en Contenedor
# Copia este archivo como .env y ajusta los valores

# === CONFIGURACIÓN DE PUERTOS ===
WEBMIN_PORT=10000
HTTP_PORT=80
HTTPS_PORT=443

# === CONFIGURACIÓN DE BASE DE DATOS ===
MYSQL_ROOT_PASSWORD=cambiar_esta_contraseña_segura
MYSQL_PASSWORD=cambiar_esta_contraseña_segura

# === CONFIGURACIÓN DE VIRTUALMIN ===
VIRTUALMIN_DOMAIN=tu-dominio.com
WEBMIN_ADMIN_PASS=cambiar_esta_contraseña_admin

# === CONFIGURACIÓN DE SSL ===
SSL_CERT_PATH=/ruta/a/certificado.pem
SSL_KEY_PATH=/ruta/a/clave.pem

# === CONFIGURACIÓN DE BACKUPS ===
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE=daily

# === CONFIGURACIÓN DE MONITOREO ===
ENABLE_MONITORING=true
MONITORING_INTERVAL=60

# === CONFIGURACIÓN DE LOGS ===
LOG_LEVEL=INFO
LOG_ROTATION_SIZE=10MB
LOG_BACKUP_COUNT=5
EOF

    log_success "Archivo .env de ejemplo generado: $env_path"
}

# Función para mostrar instrucciones finales
show_instructions() {
    log_success "Configuración de contenedores generada exitosamente"
    echo
    log_info "=== INSTRUCCIONES DE USO ==="
    echo
    log_info "1. Revisa y ajusta la configuración en docker-compose.yml"
    log_info "2. Copia .env.example a .env y configura las variables"
    log_info "3. Construye la imagen:"
    echo "   $CONTAINER_ENGINE-compose build"
    log_info "4. Inicia el contenedor:"
    echo "   $CONTAINER_ENGINE-compose up -d"
    log_info "5. Accede a Virtualmin en: https://localhost:$HOST_PORT_WEBMIN"
    echo
    log_info "=== COMANDOS ÚTILES ==="
    echo
    log_info "Gestión del contenedor:"
    echo "  ./manage_container.sh start    # Iniciar"
    echo "  ./manage_container.sh stop     # Detener"
    echo "  ./manage_container.sh logs     # Ver logs"
    echo "  ./manage_container.sh shell    # Acceder al shell"
    echo
    log_info "=== NOTAS IMPORTANTES ==="
    echo
    log_warning "• La primera ejecución puede tomar tiempo (descarga de dependencias)"
    log_warning "• Los datos persistirán en volúmenes Docker nombrados"
    log_warning "• Configura backups regulares para los volúmenes"
    log_warning "• Revisa los logs si hay problemas de conectividad"
}

# Función principal
main() {
    echo
    echo "=========================================="
    echo "  GENERADOR DE CONFIGURACIÓN DOCKER"
    echo "  Virtualmin + Authentic Theme"
    echo "=========================================="
    echo

    # Verificar soporte de contenedores
    if ! check_container_support; then
        exit 1
    fi

    # Generar archivos de configuración
    generate_dockerfile
    generate_docker_compose
    generate_container_manager
    generate_env_example

    # Mostrar instrucciones
    show_instructions
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
