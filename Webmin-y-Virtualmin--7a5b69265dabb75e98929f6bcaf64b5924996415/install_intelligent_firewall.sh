#!/bin/bash
# install_intelligent_firewall.sh - Script de instalación del firewall inteligente

set -e  # Salir en caso de error

echo "Instalando Firewall Inteligente para Webmin/Virtualmin..."

# Verificar que estamos ejecutando como root
if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse como root"
    exit 1
fi

# Verificar dependencias del sistema
echo "Verificando dependencias del sistema..."

# Instalar Python y scikit-learn si no están
if ! command -v python3 &> /dev/null; then
    echo "Instalando Python3..."
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y python3 python3-pip python3-dev
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip python3-devel
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip python3-devel
    else
        echo "ERROR: No se pudo instalar Python3 - gestor de paquetes no reconocido"
        exit 1
    fi
fi

if ! python3 -c "import sklearn" &> /dev/null; then
    echo "Instalando scikit-learn y dependencias..."
    pip3 install scikit-learn pandas numpy joblib
fi

# Instalar iptables-persistent/netfilter-persistent si no está
if command -v apt-get &> /dev/null; then
    if ! dpkg -l | grep -q iptables-persistent; then
        echo "Instalando iptables-persistent..."
        apt-get install -y iptables-persistent netfilter-persistent
    fi
elif command -v yum &> /dev/null || command -v dnf &> /dev/null; then
    if ! rpm -q iptables-services &> /dev/null; then
        echo "Instalando iptables-services..."
        if command -v yum &> /dev/null; then
            yum install -y iptables-services
        else
            dnf install -y iptables-services
        fi
    fi
fi

# Instalar tcpdump para análisis de tráfico
if ! command -v tcpdump &> /dev/null; then
    echo "Instalando tcpdump..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y tcpdump
    elif command -v yum &> /dev/null; then
        yum install -y tcpdump
    elif command -v dnf &> /dev/null; then
        dnf install -y tcpdump
    else
        echo "ERROR: No se pudo instalar tcpdump - gestor de paquetes no reconocido"
        exit 1
    fi
fi

# Instalar módulos Perl adicionales si es necesario
if ! perl -MTime::HiRes -e 1 &> /dev/null; then
    echo "Instalando módulos Perl..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y libtime-hires-perl
    elif command -v yum &> /dev/null; then
        yum install -y perl-Time-HiRes
    elif command -v dnf &> /dev/null; then
        dnf install -y perl-Time-HiRes
    else
        echo "ERROR: No se pudo instalar módulos Perl - gestor de paquetes no reconocido"
        exit 1
    fi
fi

# Crear directorios con permisos correctos
echo "Creando directorios..."
mkdir -p /etc/webmin/intelligent-firewall/models
mkdir -p /var/log/intelligent-firewall
mkdir -p /usr/share/webmin/intelligent-firewall

# Establecer permisos
# Detectar usuario del servidor web
WEB_USER="www-data"
if command -v httpd &> /dev/null; then
    WEB_USER="apache"
elif command -v nginx &> /dev/null; then
    WEB_USER="nginx"
fi

chown -R $WEB_USER:$WEB_USER /etc/webmin/intelligent-firewall
chown -R $WEB_USER:$WEB_USER /var/log/intelligent-firewall
chmod 755 /etc/webmin/intelligent-firewall
chmod 755 /var/log/intelligent-firewall

# Copiar archivos del módulo
echo "Copiando archivos del módulo..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR/intelligent-firewall"/* /usr/share/webmin/intelligent-firewall/

# Configurar permisos de archivos
chmod +x /usr/share/webmin/intelligent-firewall/*.cgi
chmod +x /usr/share/webmin/intelligent-firewall/*.pl
chmod +x /usr/share/webmin/intelligent-firewall/*.py
chmod 644 /usr/share/webmin/intelligent-firewall/*.info
chmod 644 /usr/share/webmin/intelligent-firewall/config*

# Crear archivos de datos iniciales
touch /var/log/intelligent-firewall/traffic.log
touch /var/log/intelligent-firewall/traffic_data.csv
chown $WEB_USER:$WEB_USER /var/log/intelligent-firewall/*.log
chown $WEB_USER:$WEB_USER /var/log/intelligent-firewall/*.csv

# Crear datos de ejemplo para el modelo inicial
echo "timestamp,active_connections,packets_total,cpu_usage" > /var/log/intelligent-firewall/traffic_data.csv
for i in {1..200}; do
    timestamp=$(( $(date +%s) - (200 - i) * 3600 ))
    connections=$(( RANDOM % 100 + 10 ))
    packets=$(( RANDOM % 10000 + 1000 ))
    cpu=$(( RANDOM % 50 + 10 ))
    echo "$timestamp,$connections,$packets,$cpu" >> /var/log/intelligent-firewall/traffic_data.csv
done

# Configurar cron para aprendizaje continuo
echo "Configurando aprendizaje continuo..."
CRON_JOB="0 */24 * * * /usr/bin/perl /usr/share/webmin/intelligent-firewall/train_model.pl >> /var/log/intelligent-firewall/training.log 2>&1"
(crontab -l 2>/dev/null | grep -v "train_model.pl"; echo "$CRON_JOB") | crontab -

# Configurar logrotate para logs del firewall
echo "Configurando rotación de logs..."
cat > /etc/logrotate.d/intelligent-firewall << EOF
/var/log/intelligent-firewall/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $WEB_USER $WEB_USER
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF

# Inicializar firewall
echo "Inicializando firewall..."
cd /usr/share/webmin/intelligent-firewall
perl init_firewall.pl

# Verificar instalación
echo "Verificando instalación..."
if [ -f "/usr/share/webmin/intelligent-firewall/module.info" ]; then
    echo "✓ Módulo instalado correctamente"
else
    echo "✗ Error en instalación del módulo"
    exit 1
fi

if [ -f "/etc/webmin/intelligent-firewall/models/anomaly_model.pkl" ]; then
    echo "✓ Modelo ML inicial creado"
else
    echo "⚠ Modelo ML no creado (se creará en el primer entrenamiento)"
fi

# Reiniciar Webmin
echo "Reiniciando Webmin..."
systemctl restart webmin

# Mostrar información de instalación
echo ""
echo "=========================================="
echo "Instalación completada exitosamente!"
echo "=========================================="
echo ""
echo "Accede al módulo desde Webmin > Firewall Inteligente"
echo ""
echo "Archivos importantes:"
echo "  - Configuración: /etc/webmin/intelligent-firewall/config"
echo "  - Modelo ML: /etc/webmin/intelligent-firewall/models/"
echo "  - Logs: /var/log/intelligent-firewall/"
echo "  - Módulo: /usr/share/webmin/intelligent-firewall/"
echo ""
echo "Comandos útiles:"
echo "  - Ver estado: perl /usr/share/webmin/intelligent-firewall/init_firewall.pl"
echo "  - Entrenar modelo: perl /usr/share/webmin/intelligent-firewall/train_model.pl"
echo "  - Ver logs: tail -f /var/log/intelligent-firewall/traffic.log"
echo ""
echo "El aprendizaje continuo está configurado para ejecutarse diariamente."