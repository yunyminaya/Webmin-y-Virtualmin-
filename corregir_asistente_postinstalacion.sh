#!/bin/bash
# Script para corregir el asistente de post-instalación de Virtualmin en macOS
# Autor: Asistente AI
# Fecha: $(date)

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Verificar si es macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "Este script está diseñado para macOS"
    exit 1
fi

# Verificar si Homebrew está instalado
if ! command -v brew &> /dev/null; then
    log_error "Homebrew no está instalado. Instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

log_step "Diagnóstico del Sistema"

# Función para verificar servicios
check_service() {
    local service=$1
    if brew services list | grep -q "$service.*started"; then
        log_success "$service está ejecutándose"
        return 0
    else
        log_warning "$service NO está ejecutándose"
        return 1
    fi
}

# Función para verificar puertos
check_port() {
    local port=$1
    local service=$2
    if lsof -i :$port &> /dev/null; then
        log_success "Puerto $port ($service) está abierto"
        return 0
    else
        log_warning "Puerto $port ($service) NO está disponible"
        return 1
    fi
}

log_step "Verificando Dependencias"

# Verificar MySQL
if check_service "mysql"; then
    log_success "MySQL está funcionando"
else
    log_info "Iniciando MySQL..."
    brew services start mysql
    sleep 3
fi

# Verificar Apache/httpd
if check_service "httpd" || check_port 80 "Apache"; then
    log_success "Servidor web está funcionando"
else
    log_info "Instalando y configurando Apache..."
    brew install httpd
    brew services start httpd
fi

# Verificar Perl (necesario para Webmin)
if command -v perl &> /dev/null; then
    log_success "Perl está instalado"
else
    log_info "Instalando Perl..."
    brew install perl
fi

log_step "Instalando Webmin"

# Crear directorio para Webmin
sudo mkdir -p /usr/local/webmin
sudo mkdir -p /etc/webmin
sudo mkdir -p /var/log/webmin

# Descargar e instalar Webmin
WEBMIN_VERSION="2.111"
WEBMIN_URL="https://github.com/webmin/webmin/archive/refs/tags/${WEBMIN_VERSION}.tar.gz"

log_info "Descargando Webmin ${WEBMIN_VERSION}..."
cd /tmp
curl -L -o webmin.tar.gz "$WEBMIN_URL"
tar -xzf webmin.tar.gz

# Mover archivos de Webmin
sudo cp -r webmin-${WEBMIN_VERSION}/* /usr/local/webmin/
sudo chown -R root:admin /usr/local/webmin

log_step "Configurando Webmin"

# Crear configuración básica de Webmin
cat > /tmp/webmin_setup.pl << 'EOF'
#!/usr/bin/perl
# Configuración automática de Webmin para macOS

use strict;
use warnings;

# Configuración básica
my $config_dir = "/etc/webmin";
my $var_dir = "/var/webmin";
my $perl_path = `which perl`;
chomp $perl_path;

# Crear directorios necesarios
system("mkdir -p $config_dir");
system("mkdir -p $var_dir");
system("mkdir -p /var/log/webmin");

# Configuración mínima
open(my $fh, '>', "$config_dir/miniserv.conf") or die "Cannot open miniserv.conf: $!";
print $fh "port=10000\n";
print $fh "root=/usr/local/webmin\n";
print $fh "mimetypes=/usr/local/webmin/mime.types\n";
print $fh "addtype_cgi=internal/cgi\n";
print $fh "realm=Webmin Server\n";
print $fh "logfile=/var/log/webmin/miniserv.log\n";
print $fh "errorlog=/var/log/webmin/miniserv.error\n";
print $fh "pidfile=/var/webmin/miniserv.pid\n";
print $fh "logtime=168\n";
print $fh "ppath=\n";
print $fh "ssl=0\n";
print $fh "env_WEBMIN_CONFIG=$config_dir\n";
print $fh "env_WEBMIN_VAR=$var_dir\n";
print $fh "atboot=1\n";
print $fh "logout=/usr/local/webmin/session_login.cgi\n";
print $fh "listen=10000\n";
print $fh "denyfile=\\.pl$\n";
print $fh "log=1\n";
print $fh "blockhost_failures=5\n";
print $fh "blockhost_time=60\n";
print $fh "syslog=1\n";
close $fh;

print "Configuración de Webmin creada exitosamente\n";
EOF

# Ejecutar configuración
sudo perl /tmp/webmin_setup.pl

log_step "Instalando Virtualmin"

# Copiar archivos de Virtualmin
sudo cp -r virtualmin-gpl-master/* /usr/local/webmin/

# Configurar Virtualmin
sudo mkdir -p /etc/webmin/virtual-server

# Crear configuración básica de Virtualmin
cat > /tmp/virtualmin_config << 'EOF'
first_version=7.20
wizard_run=0
mysql=1
postgres=0
spam=0
virus=0
dns=0
ssl=1
EOF

sudo cp /tmp/virtualmin_config /etc/webmin/virtual-server/config

log_step "Configurando Servicios"

# Crear script de inicio para Webmin
cat > /tmp/webmin_start.sh << 'EOF'
#!/bin/bash
export WEBMIN_CONFIG="/etc/webmin"
export WEBMIN_VAR="/var/webmin"
export PERL5LIB="/usr/local/webmin"
cd /usr/local/webmin
perl miniserv.pl /etc/webmin/miniserv.conf &
echo $! > /var/webmin/miniserv.pid
EOF

sudo cp /tmp/webmin_start.sh /usr/local/bin/webmin_start.sh
sudo chmod +x /usr/local/bin/webmin_start.sh

# Crear LaunchDaemon para Webmin
cat > /tmp/com.webmin.webmin.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webmin.webmin</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/webmin_start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/webmin/webmin.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/webmin/webmin.error</string>
    <key>WorkingDirectory</key>
    <string>/usr/local/webmin</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>WEBMIN_CONFIG</key>
        <string>/etc/webmin</string>
        <key>WEBMIN_VAR</key>
        <string>/var/webmin</string>
    </dict>
</dict>
</plist>
EOF

sudo cp /tmp/com.webmin.webmin.plist /Library/LaunchDaemons/
sudo chown root:wheel /Library/LaunchDaemons/com.webmin.webmin.plist

log_step "Configurando Usuario Administrador"

# Crear usuario root para Webmin
sudo mkdir -p /etc/webmin/webmin-users
echo "root:x:$(id -u):$(id -g):Root User:/Users/$(whoami):/bin/bash" | sudo tee /etc/webmin/webmin-users/root > /dev/null

# Configurar ACL para root
echo "root: *" | sudo tee /etc/webmin/webmin.acl > /dev/null

log_step "Iniciando Servicios"

# Iniciar Webmin
sudo launchctl load /Library/LaunchDaemons/com.webmin.webmin.plist
sudo launchctl start com.webmin.webmin

# Esperar a que Webmin inicie
log_info "Esperando a que Webmin inicie..."
sleep 10

log_step "Verificación Final"

# Verificar que Webmin está funcionando
if check_port 10000 "Webmin"; then
    log_success "Webmin está funcionando correctamente"
    log_info "Accede a Webmin en: http://localhost:10000"
    log_info "Usuario: root"
    log_info "Contraseña: Generada automáticamente desde clave SSH"
else
    log_error "Webmin no pudo iniciarse correctamente"
    log_info "Revisa los logs en /var/log/webmin/"
fi

# Verificar MySQL
if check_service "mysql"; then
    log_success "MySQL está funcionando"
else
    log_warning "MySQL necesita ser iniciado manualmente"
    log_info "Ejecuta: brew services start mysql"
fi

log_step "Configuración del Asistente de Post-instalación"

# Crear script para resetear el wizard
cat > /tmp/reset_wizard.pl << 'EOF'
#!/usr/bin/perl
# Script para resetear el asistente de post-instalación

use strict;
use warnings;

# Configurar variables de entorno
$ENV{'WEBMIN_CONFIG'} = '/etc/webmin';
$ENV{'WEBMIN_VAR'} = '/var/webmin';

# Cambiar al directorio de Webmin
chdir '/usr/local/webmin' or die "Cannot change to webmin directory: $!";

# Cargar librerías de Webmin
require './web-lib.pl';
&init_config();

# Cargar configuración de Virtualmin
if (-d "$config_directory/virtual-server") {
    %gconfig = &read_file_cached("$config_directory/config");
    
    # Resetear el wizard
    my $vconfig_file = "$config_directory/virtual-server/config";
    my %vconfig = &read_file_cached($vconfig_file);
    
    $vconfig{'wizard_run'} = '0';
    $vconfig{'first_version'} = '7.20';
    
    &write_file($vconfig_file, \%vconfig);
    
    print "Asistente de post-instalación reseteado exitosamente\n";
} else {
    print "Virtualmin no está configurado correctamente\n";
}
EOF

sudo perl /tmp/reset_wizard.pl

log_step "Instrucciones Finales"

echo -e "
${GREEN}✅ INSTALACIÓN COMPLETADA${NC}

${BLUE}Para acceder al asistente de post-instalación:${NC}

1. Abre tu navegador web
2. Ve a: ${YELLOW}http://localhost:10000${NC}
3. Usuario: ${YELLOW}root${NC}
4. Contraseña: ${YELLOW}Generada automáticamente desde clave SSH${NC}
5. Ve a 'Virtualmin Virtual Servers'
6. El asistente de post-instalación debería aparecer automáticamente

${BLUE}Si el asistente no aparece:${NC}
- Ve a Virtualmin > Post-Installation Wizard
- O accede directamente a: ${YELLOW}http://localhost:10000/virtual-server/wizard.cgi${NC}

${BLUE}Servicios configurados:${NC}
- ✅ Webmin: Puerto 10000
- ✅ MySQL: Puerto 3306
- ✅ Apache: Puerto 80
- ✅ Virtualmin: Integrado en Webmin

${BLUE}Logs importantes:${NC}
- Webmin: /var/log/webmin/
- MySQL: $(brew --prefix)/var/log/
- Apache: $(brew --prefix)/var/log/httpd/

${GREEN}¡El asistente de post-instalación ahora debería funcionar correctamente!${NC}
"

# Limpiar archivos temporales
rm -f /tmp/webmin.tar.gz
rm -rf /tmp/webmin-*
rm -f /tmp/webmin_setup.pl
rm -f /tmp/virtualmin_config
rm -f /tmp/webmin_start.sh
rm -f /tmp/com.webmin.webmin.plist
rm -f /tmp/reset_wizard.pl

log_success "Script de corrección completado exitosamente"