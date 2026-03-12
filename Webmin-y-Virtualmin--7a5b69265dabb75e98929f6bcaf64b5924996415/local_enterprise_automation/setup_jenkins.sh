#!/bin/bash

# Script de instalación y configuración de Jenkins autoalojado para Virtualmin Enterprise
# Este script instala Jenkins y configura pipelines CI/CD

set -e

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuración
JENKINS_HOME="/var/lib/jenkins"
JENKINS_PORT="8080"
JENKINS_USER="jenkins"
JENKINS_GROUP="jenkins"
INSTALL_DIR="/opt/virtualmin-enterprise"
LOG_FILE="/var/log/virtualmin-enterprise-jenkins-install.log"

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

# Función para instalar Java
install_java() {
    log_message "Instalando Java"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            apt-get update
            apt-get install -y openjdk-11-jdk
            ;;
        "redhat")
            yum update -y
            yum install -y java-11-openjdk-devel
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    # Verificar instalación
    if java -version 2>&1 | head -1 | grep -q "openjdk"; then
        log_message "Java instalado correctamente"
        print_message $GREEN "Java instalado correctamente"
    else
        log_message "ERROR: Falló la instalación de Java"
        print_message $RED "ERROR: Falló la instalación de Java"
        exit 1
    fi
}

# Función para agregar repositorio de Jenkins
add_jenkins_repository() {
    log_message "Agregando repositorio de Jenkins"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            # Importar clave GPG
            wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
            
            # Agregar repositorio
            echo "deb https://pkg.jenkins.io/debian binary/" > /etc/apt/sources.list.d/jenkins.list
            
            # Actualizar lista de paquetes
            apt-get update
            ;;
        "redhat")
            # Importar clave GPG
            rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
            
            # Agregar repositorio
            cat > /etc/yum.repos.d/jenkins.repo << EOF
[jenkins]
name=Jenkins
baseurl=http://pkg.jenkins.io/redhat
gpgcheck=1
EOF
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    log_message "Repositorio de Jenkins agregado"
}

# Función para instalar Jenkins
install_jenkins() {
    log_message "Instalando Jenkins"
    
    local distribution=$(detect_distribution)
    
    case $distribution in
        "debian")
            apt-get install -y jenkins
            ;;
        "redhat")
            yum install -y jenkins
            ;;
        *)
            print_message $RED "Distribución no soportada"
            exit 1
            ;;
    esac
    
    # Habilitar y iniciar Jenkins
    systemctl enable jenkins
    systemctl start jenkins
    
    # Verificar instalación
    if systemctl is-active --quiet jenkins; then
        log_message "Jenkins instalado y iniciado correctamente"
        print_message $GREEN "Jenkins instalado y iniciado correctamente"
    else
        log_message "ERROR: Falló la instalación de Jenkins"
        print_message $RED "ERROR: Falló la instalación de Jenkins"
        exit 1
    fi
}

# Función para configurar firewall para Jenkins
configure_firewall() {
    log_message "Configurando firewall para Jenkins"
    
    # Verificar si ufw está disponible (Debian/Ubuntu)
    if command -v ufw &> /dev/null; then
        ufw allow $JENKINS_PORT/tcp
        log_message "Firewall configurado con ufw para el puerto $JENKINS_PORT"
    # Verificar si firewall-cmd está disponible (RHEL/CentOS)
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=$JENKINS_PORT/tcp
        firewall-cmd --reload
        log_message "Firewall configurado con firewall-cmd para el puerto $JENKINS_PORT"
    # Usar iptables directamente
    else
        iptables -A INPUT -p tcp --dport $JENKINS_PORT -j ACCEPT
        # Guardar reglas iptables
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4
        fi
        log_message "Firewall configurado con iptables para el puerto $JENKINS_PORT"
    fi
    
    print_message $GREEN "Firewall configurado para Jenkins en el puerto $JENKINS_PORT"
}

# Función para obtener contraseña inicial de Jenkins
get_initial_password() {
    log_message "Obteniendo contraseña inicial de Jenkins"
    
    # Esperar a que Jenkins genere la contraseña
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if [ -f "$JENKINS_HOME/secrets/initialAdminPassword" ]; then
            local password=$(cat "$JENKINS_HOME/secrets/initialAdminPassword")
            log_message "Contraseña inicial de Jenkins obtenida"
            echo "$password"
            return 0
        fi
        
        log_message "Esperando generación de contraseña inicial (intento $((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log_message "ERROR: No se pudo obtener la contraseña inicial de Jenkins"
    print_message $RED "ERROR: No se pudo obtener la contraseña inicial de Jenkins"
    return 1
}

# Función para instalar plugins de Jenkins
install_jenkins_plugins() {
    log_message "Instalando plugins de Jenkins"
    
    # Lista de plugins a instalar
    local plugins=(
        "git"
        "pipeline"
        "pipeline-stage-view"
        "pipeline-graph-analysis"
        "workflow-aggregator"
        "workflow-step-api"
        "workflow-multibranch"
        "workflow-scm-step"
        "github"
        "github-branch-source"
        "docker-plugin"
        "docker-workflow"
        "ansible"
        "blueocean"
        "email-ext"
        "matrix-project"
        "ssh-agent"
        "credentials"
        "credentials-binding"
        "timestamper"
        "ws-cleanup"
        "parameterized-trigger"
        "build-timeout"
        "htmlpublisher"
        "junit"
        "cobertura"
        "sonar"
        "prometheus"
        "nodejs"
        "maven-plugin"
        "gradle"
    )
    
    # Crear script para instalar plugins
    cat > /tmp/install-jenkins-plugins.sh << 'EOF'
#!/bin/bash

JENKINS_HOME="/var/lib/jenkins"
JENKINS_PLUGINS_DIR="$JENKINS_HOME/plugins"
JENKINS_WAR="/usr/share/jenkins/jenkins.war"

# Esperar a que Jenkins esté disponible
echo "Esperando a que Jenkins esté disponible..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -s -f http://localhost:8080 > /dev/null; then
        echo "Jenkins está disponible"
        break
    fi
    
    echo "Esperando a Jenkins (intento $((attempt + 1))/$max_attempts)"
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "ERROR: Jenkins no está disponible después de esperar"
    exit 1
fi

# Instalar plugins
echo "Instalando plugins de Jenkins..."

# Descargar CLI de Jenkins
wget -q -O /tmp/jenkins-cli.jar http://updates.jenkins-ci.org/latest/jenkins-cli.jar

# Instalar cada plugin
for plugin in "$@"; do
    echo "Instalando plugin: $plugin"
    java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth @/tmp/jenkins-credentials install-plugin "$plugin" -deploy
done

# Reiniciar Jenkins después de instalar plugins
echo "Reiniciando Jenkins..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth @/tmp/jenkins-credentials safe-restart

echo "Instalación de plugins completada"
EOF
    
    # Hacer ejecutable el script
    chmod +x /tmp/install-jenkins-plugins.sh
    
    # Crear archivo de credenciales para Jenkins CLI
    local initial_password=$(get_initial_password)
    echo "admin:$initial_password" > /tmp/jenkins-credentials
    
    # Ejecutar script de instalación de plugins
    bash /tmp/install-jenkins-plugins.sh "${plugins[@]}" >> "$LOG_FILE" 2>&1
    
    # Limpiar archivos temporales
    rm -f /tmp/jenkins-cli.jar /tmp/jenkins-credentials /tmp/install-jenkins-plugins.sh
    
    log_message "Instalación de plugins completada"
    print_message $GREEN "Instalación de plugins completada"
}

# Función para crear pipelines de Jenkins
create_jenkins_pipelines() {
    log_message "Creando pipelines de Jenkins"
    
    # Crear directorio para pipelines
    mkdir -p "$JENKINS_HOME/workflows"
    
    # Crear pipeline para pruebas unitarias
    cat > "$JENKINS_HOME/workflows/unit-tests.groovy" << 'EOF'
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/virtualmin/virtualmin-enterprise.git'
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh 'cd tests && bash run_unit_tests.sh'
            }
        }
        
        stage('Report Results') {
            steps {
                junit 'tests/unit-test-results/**/*.xml'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        
        success {
            echo 'Unit tests passed successfully!'
        }
        
        failure {
            echo 'Unit tests failed!'
            mail to: 'admin@example.com',
                 subject: 'Unit Tests Failed',
                 body: "Unit tests failed for ${env.JOB_NAME} (${env.BUILD_NUMBER})"
        }
    }
}
EOF
    
    # Crear pipeline para pruebas de integración
    cat > "$JENKINS_HOME/workflows/integration-tests.groovy" << 'EOF'
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/virtualmin/virtualmin-enterprise.git'
            }
        }
        
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh 'cd tests && bash run_integration_tests.sh'
            }
        }
        
        stage('Report Results') {
            steps {
                junit 'tests/integration-test-results/**/*.xml'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        
        success {
            echo 'Integration tests passed successfully!'
        }
        
        failure {
            echo 'Integration tests failed!'
            mail to: 'admin@example.com',
                 subject: 'Integration Tests Failed',
                 body: "Integration tests failed for ${env.JOB_NAME} (${env.BUILD_NUMBER})"
        }
    }
}
EOF
    
    # Crear pipeline para despliegue
    cat > "$JENKINS_HOME/workflows/deploy.groovy" << 'EOF'
pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['staging', 'production'], description: 'Target environment')
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip tests?')
    }

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/virtualmin/virtualmin-enterprise.git'
            }
        }
        
        stage('Run Tests') {
            when {
                not { params.SKIP_TESTS }
            }
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'cd tests && bash run_unit_tests.sh'
                    }
                }
                
                stage('Integration Tests') {
                    steps {
                        sh 'cd tests && bash run_integration_tests.sh'
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            when {
                expression { params.ENVIRONMENT == 'staging' }
            }
            steps {
                sh 'cd deploy && bash deploy.sh staging'
            }
        }
        
        stage('Deploy to Production') {
            when {
                expression { params.ENVIRONMENT == 'production' }
            }
            steps {
                input message: 'Deploy to production?', ok: 'Deploy'
                sh 'cd deploy && bash deploy.sh production'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        
        success {
            echo "Deployment to ${params.ENVIRONMENT} completed successfully!"
            
            // Notificar al equipo
            slackSend(
                channel: '#deployments',
                color: 'good',
                message: "Successfully deployed ${env.JOB_NAME} (${env.BUILD_NUMBER}) to ${params.ENVIRONMENT}"
            )
        }
        
        failure {
            echo "Deployment to ${params.ENVIRONMENT} failed!"
            
            // Notificar al equipo
            slackSend(
                channel: '#deployments',
                color: 'danger',
                message: "Failed to deploy ${env.JOB_NAME} (${env.BUILD_NUMBER}) to ${params.ENVIRONMENT}"
            )
            
            mail to: 'admin@example.com',
                 subject: "Deployment to ${params.ENVIRONMENT} Failed",
                 body: "Deployment to ${params.ENVIRONMENT} failed for ${env.JOB_NAME} (${env.BUILD_NUMBER})"
        }
    }
}
EOF
    
    log_message "Pipelines de Jenkins creados"
    print_message $GREEN "Pipelines de Jenkins creados"
}

# Función para configurar integración con Git
configure_git_integration() {
    log_message "Configurando integración con Git"
    
    # Crear directorio para claves SSH
    mkdir -p "$JENKINS_HOME/.ssh"
    
    # Generar clave SSH para Jenkins
    ssh-keygen -t rsa -N "" -f "$JENKINS_HOME/.ssh/id_rsa"
    
    # Cambiar permisos
    chown -R $JENKINS_USER:$JENKINS_GROUP "$JENKINS_HOME/.ssh"
    chmod 700 "$JENKINS_HOME/.ssh"
    chmod 600 "$JENKINS_HOME/.ssh/id_rsa"
    chmod 644 "$JENKINS_HOME/.ssh/id_rsa.pub"
    
    # Mostrar clave pública para agregar a repositorios Git
    local public_key=$(cat "$JENKINS_HOME/.ssh/id_rsa.pub")
    
    log_message "Integración con Git configurada"
    print_message $GREEN "Integración con Git configurada"
    print_message $BLUE "Clave pública SSH de Jenkins:"
    print_message $YELLOW "$public_key"
    print_message $BLUE "Agregue esta clave a sus repositorios Git"
}

# Función para mostrar información de acceso
show_access_info() {
    local initial_password=$(get_initial_password)
    local server_ip=$(hostname -I | awk '{print $1}')
    
    print_message $GREEN "Jenkins instalado y configurado exitosamente"
    print_message $BLUE "Información de acceso:"
    print_message $BLUE "URL: http://$server_ip:$JENKINS_PORT"
    print_message $BLUE "Usuario: admin"
    print_message $BLUE "Contraseña: $initial_password"
    print_message $YELLOW "IMPORTANTE: Cambie la contraseña inicial después del primer inicio de sesión"
}

# Función principal
main() {
    print_message $GREEN "Iniciando instalación de Jenkins autoalojado..."
    log_message "Iniciando instalación de Jenkins autoalojado"
    
    check_root
    install_java
    add_jenkins_repository
    install_jenkins
    configure_firewall
    
    # Esperar a que Jenkins esté completamente iniciado
    print_message $BLUE "Esperando a que Jenkins se inicie completamente..."
    sleep 30
    
    # Obtener contraseña inicial
    local initial_password=$(get_initial_password)
    
    if [ -n "$initial_password" ]; then
        # Instalar plugins
        install_jenkins_plugins
        
        # Crear pipelines
        create_jenkins_pipelines
        
        # Configurar integración con Git
        configure_git_integration
        
        # Mostrar información de acceso
        show_access_info
        
        log_message "Instalación de Jenkins completada exitosamente"
    else
        log_message "ERROR: No se pudo completar la instalación de Jenkins"
        print_message $RED "ERROR: No se pudo completar la instalación de Jenkins"
        exit 1
    fi
}

# Ejecutar función principal
main "$@"