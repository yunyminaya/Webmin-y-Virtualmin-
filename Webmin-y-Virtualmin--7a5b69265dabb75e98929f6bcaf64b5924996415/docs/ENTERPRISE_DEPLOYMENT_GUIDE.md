
# Guía de Despliegue y Operación de Virtualmin Enterprise

## Tabla de Contenido

1. [Introducción](#introducción)
2. [Requisitos del Sistema](#requisitos-del-sistema)
3. [Arquitectura del Sistema](#arquitectura-del-sistema)
4. [Instalación y Configuración](#instalación-y-configuración)
5. [Configuración de Componentes](#configuración-de-componentes)
6. [Operación y Mantenimiento](#operación-y-mantenimiento)
7. [Monitoreo y Alertas](#monitoreo-y-alertas)
8. [Seguridad y Hardening](#seguridad-y-hardening)
9. [Respaldo y Recuperación](#respaldo-y-recuperación)
10. [Solución de Problemas](#solución-de-problemas)
11. [Preguntas Frecuentes](#preguntas-frecuentes)

## Introducción

Virtualmin Enterprise es una plataforma de gestión de servidores web de nivel empresarial que proporciona un conjunto completo de herramientas para la administración, monitoreo, seguridad y automatización de infraestructuras de hosting.

Esta guía proporciona instrucciones detalladas para el despliegue, configuración y operación de Virtualmin Enterprise en entornos de producción.

### Características Principales

- **Gestión Centralizada**: Administración de múltiples servidores desde una única interfaz
- **Automatización Avanzada**: Scripts de despliegue, actualización y mantenimiento automático
- **Seguridad Empresarial**: Sistema integral de seguridad con análisis de vulnerabilidades
- **Monitoreo Completo**: Métricas y alertas centralizadas con Prometheus y Grafana
- **Alta Disponibilidad**: Sistema de failover y recuperación automática
- **Multi-Nube**: Soporte para despliegue en AWS, GCP, Azure y entornos híbridos
- **Inteligencia Artificial**: Optimización automática y análisis predictivo

## Requisitos del Sistema

### Requisitos Mínimos

- **Sistema Operativo**: Ubuntu 20.04 LTS o superior, CentOS 8, RHEL 8, Debian 10+
- **CPU**: 2 núcleos
- **RAM**: 4 GB
- **Almacenamiento**: 40 GB de espacio libre
- **Red**: Conexión a internet estable

### Requisitos Recomendados

- **Sistema Operativo**: Ubuntu 22.04 LTS
- **CPU**: 4 núcleos o más
- **RAM**: 8 GB o más
- **Almacenamiento**: 100 GB de espacio libre (SSD recomendado)
- **Red**: Conexión a internet de alta velocidad

### Requisitos de Software

- **Python**: 3.8 o superior
- **Node.js**: 14.x o superior
- **Docker**: 20.10 o superior
- **Git**: 2.25 o superior
- **Ansible**: 2.9 o superior (para automatización)
- **Terraform**: 1.0 o superior (para infraestructura como código)

## Arquitectura del Sistema

Virtualmin Enterprise sigue una arquitectura modular y escalable que permite desplegar componentes de forma independiente según las necesidades de cada organización.

### Componentes Principales

1. **Panel de Control Virtualmin**: Interfaz web principal para administración
2. **Sistema de Automatización**: Scripts y herramientas para despliegue y mantenimiento
3. **Sistema de Monitoreo**: Prometheus, Grafana y Node Exporter
4. **Sistema de Seguridad**: Análisis de vulnerabilidades y hardening automático
5. **Sistema de Respaldos**: Copias de seguridad automáticas con cifrado
6. **Sistema de Alertas**: Notificaciones por correo electrónico, Slack y SMS
7. **Sistema de Multi-Nube**: Gestión de recursos en diferentes proveedores de nube

### Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    Virtualmin Enterprise                    │
├─────────────────────────────────────────────────────────────┤
│  Panel de Control  │  API REST  │  CLI  │  Webhooks        │
├─────────────────────────────────────────────────────────────┤
│  Sistema de Automatización  │  CI/CD  │  Orquestación        │
├─────────────────────────────────────────────────────────────┤
│  Monitoreo  │  Métricas  │  Alertas  │  Dashboards          │
├─────────────────────────────────────────────────────────────┤
│  Seguridad  │  Hardening  │  Análisis  │  Cumplimiento         │
├─────────────────────────────────────────────────────────────┤
│  Respaldos  │  Recuperación  │  Replicación  │  Archivado      │
├─────────────────────────────────────────────────────────────┤
│  Multi-Nube  │  AWS  │  GCP  │  Azure  │  Híbrido            │
├─────────────────────────────────────────────────────────────┤
│  Infraestructura  │  Servidores  │  Red  │  Almacenamiento      │
└─────────────────────────────────────────────────────────────┘
```

## Instalación y Configuración

### Método 1: Instalación Automática (Recomendado)

El método más sencillo para desplegar Virtualmin Enterprise es utilizando el script de instalación automática:

```bash
# Descargar el script de instalación
wget https://github.com/virtualmin/virtualmin-enterprise/releases/latest/download/install.sh

# Hacer el script ejecutable
chmod +x install.sh

# Ejecutar el script de instalación
sudo ./install.sh
```

El script de instalación realizará las siguientes tareas:
1. Verificar los requisitos del sistema
2. Instalar dependencias necesarias
3. Configurar el repositorio de Virtualmin Enterprise
4. Instalar y configurar todos los componentes
5. Realizar la configuración inicial
6. Iniciar los servicios necesarios

### Método 2: Instalación Manual

Para entornos con requisitos específicos, puede realizar una instalación manual:

#### Paso 1: Preparación del Sistema

```bash
# Actualizar el sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependencias básicas
sudo apt install -y curl wget git python3 python3-pip nodejs npm docker.io docker-compose

# Instalar Python y Node.js adicionales si es necesario
sudo apt install -y python3-venv python3-dev
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs
```

#### Paso 2: Descargar Virtualmin Enterprise

```bash
# Clonar el repositorio
git clone https://github.com/virtualmin/virtualmin-enterprise.git
cd virtualmin-enterprise

# Cambiar a la rama estable
git checkout stable
```

#### Paso 3: Ejecutar el Script de Instalación

```bash
# Ejecutar el script de instalación
sudo ./install.sh --mode manual
```

#### Paso 4: Configuración Inicial

```bash
# Ejecutar el asistente de configuración
sudo /opt/virtualmin-enterprise/bin/configure.sh

# Seguir las instrucciones del asistente para configurar:
# - Contraseña de administrador
# - Configuración de red
# - Certificados SSL
# - Servicios a habilitar
```

### Método 3: Despliegue con Ansible

Para despliegues en múltiples servidores o entornos de nube:

```bash
# Instalar Ansible
sudo apt install -y ansible

# Descargar el playbook de Ansible
wget https://github.com/virtualmin/virtualmin-enterprise/releases/latest/download/ansible-playbook.yml

# Crear archivo de inventario
cat > inventory.ini << EOF
[virtualmin_servers]
server1 ansible_host=192.168.1.10 ansible_user=root
server2 ansible_host=192.168.1.11 ansible_user=root
EOF

# Ejecutar el playbook
ansible-playbook -i inventory.ini ansible-playbook.yml
```

### Método 4: Despliegue con Terraform

Para despliegues en entornos de nube:

```bash
# Descargar la configuración de Terraform
wget https://github.com/virtualmin/virtualmin-enterprise/releases/latest/download/terraform-config.tar.gz

# Extraer la configuración
tar -xzf terraform-config.tar.gz
cd terraform-config

# Configurar las variables de entorno
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con sus credenciales y configuración

# Inicializar Terraform
terraform init

# Planificar el despliegue
terraform plan

# Ejecutar el despliegue
terraform apply
```

## Configuración de Componentes

### Configuración del Panel de Control

El panel de control de Virtualmin Enterprise se configura a través del archivo `/opt/virtualmin-enterprise/config/config.json`:

```json
{
  "system": {
    "hostname": "virtualmin.example.com",
    "timezone": "America/New_York",
    "language": "es"
  },
  "security": {
    "enable_2fa": true,
    "session_timeout": 3600,
    "max_login_attempts": 5,
    "lockout_time": 900
  },
  "notifications": {
    "email": {
      "enabled": true,
      "smtp_server": "smtp.example.com",
      "smtp_port": 587,
      "smtp_username": "notifications@example.com",
      "smtp_password": "password"
    },
    "slack": {
      "enabled": true,
      "webhook_url": "https://hooks.slack.com/services/..."
    }
  }
}
```

### Configuración del Sistema de Monitoreo

El sistema de monitoreo se configura a través del archivo `/opt/virtualmin-enterprise/monitoring/config.json`:

```json
{
  "prometheus": {
    "port": 9090,
    "retention": "15d",
    "scrape_interval": "15s"
  },
  "grafana": {
    "port": 3000,
    "admin_user": "admin",
    "admin_password": "secure_password"
  },
  "alertmanager": {
    "port": 9093,
    "smtp_from": "alerts@virtualmin.example.com"
  },
  "targets": {
    "web_server": {
      "host": "localhost",
      "port": 80,
      "metrics_path": "/metrics"
    },
    "database": {
      "host": "localhost",
      "port": 3306,
      "metrics_path": "/metrics"
    }
  }
}
```

### Configuración del Sistema de Seguridad

El sistema de seguridad se configura a través del archivo `/opt/virtualmin-enterprise/security/config.json`:

```json
{
  "scanners": {
    "nmap": {
      "enabled": true,
      "scan_interval": "daily"
    },
    "lynis": {
      "enabled": true,
      "scan_interval": "weekly"
    },
    "nikto": {
      "enabled": true,
      "scan_interval": "weekly"
    },
    "sslscan": {
      "enabled": true,
      "scan_interval": "daily"
    }
  },
  "hardening": {
    "auto_apply": true,
    "backup_before_changes": true,
    "categories": ["ssh", "system", "network", "services"]
  },
  "compliance": {
    "standards": ["cis", "pci-dss", "hipaa"],
    "scan_interval": "monthly"
  }
}
```

### Configuración del Sistema de Respaldos

El sistema de respaldos se configura a través del archivo `/opt/virtualmin-enterprise/backup/config.json`:

```json
{
  "schedule": {
    "daily": "02:00",
    "weekly": "sunday 03:00",
    "monthly": "1 04:00"
  },
  "retention": {
    "daily": 7,
    "weekly": 4,
    "monthly": 12
  },
  "storage": {
    "local": {
      "enabled": true,
      "path": "/opt/virtualmin-enterprise/backups"
    },
    "s3": {
      "enabled": true,
      "bucket": "virtualmin-backups",
      "region": "us-east-1",
      "access_key": "AKIA...",
      "secret_key": "..."
    },
    "encryption": {
      "enabled": true,
      "algorithm": "AES-256",
      "key": "base64_encoded_key"
    }
  }
}
```

### Configuración del Sistema de Multi-Nube

El sistema de multi-nube se configura a través del archivo `/opt/virtualmin-enterprise/cloud/config.json`:

```json
{
  "providers": {
    "aws": {
      "enabled": true,
      "access_key": "AKIA...",
      "secret_key": "...",
      "region": "us-east-1"
    },
    "gcp": {
      "enabled": true,
      "project_id": "virtualmin-enterprise",
      "credentials_file": "/opt/virtualmin-enterprise/cloud/gcp-credentials.json"
    },
    "azure": {
      "enabled": true,
      "subscription_id": "...",
      "client_id": "...",
      "client_secret": "...",
      "tenant_id": "..."
    }
  },
  "load_balancer": {
    "enabled": true,
    "algorithm": "round_robin",
    "health_check": {
      "interval": 30,
      "timeout": 5,
      "healthy_threshold": 2,
      "unhealthy_threshold": 3
    }
  },
  "auto_scaling": {
    "enabled": true,
    "min_instances": 2,
    "max_instances": 10,
    "scale_up_threshold": 80,
    "scale_down_threshold": 20,
    "scale_up_cooldown": 300,
    "scale_down_cooldown": 300
  }
}
```

## Operación y Mantenimiento

### Tareas Diarias

1. **Verificación de Estado**: Comprobar el estado de todos los servicios
2. **Revisión de Logs**: Analizar logs en busca de errores o anomalías
3. **Monitoreo de Recursos**: Verificar el uso de CPU, memoria y disco
4. **Verificación de Respaldos**: Confirmar que los respaldos se realizaron correctamente
5. **Revisión de Alertas**: Atender cualquier alerta generada por el sistema

### Tareas Semanales

1. **Actualización de Seguridad**: Aplicar actualizaciones de seguridad
2. **Análisis de Vulnerabilidades**: Ejecutar escaneos de seguridad
3. **Optimización de Rendimiento**: Revisar métricas y optimizar configuraciones
4. **Limpieza de Logs**: Rotar y limpiar logs antiguos
5. **Verificación de Certificados SSL**: Comprobar la validez de los certificados

### Tareas Mensuales

1. **Actualización del Sistema**: Aplicar actualizaciones del sistema operativo
2. **Análisis de Cumplimiento**: Verificar el cumplimiento de estándares de seguridad
3. **Revisión de Políticas**: Actualizar políticas de seguridad y acceso
4. **Pruebas de Recuperación**: Realizar pruebas de recuperación de desastres
5. **Informe de Rendimiento**: Generar informes de rendimiento y disponibilidad

### Comandos de Operación

#### Verificación de Estado

```bash
# Verificar estado de todos los servicios
sudo /opt/virtualmin-enterprise/bin/status.sh

# Verificar estado de un servicio específico
sudo /opt/virtualmin-enterprise/bin/status.sh --service monitoring

# Verificar estado de la infraestructura
sudo /opt/virtualmin-enterprise/bin/status.sh --infrastructure
```

#### Gestión de Servicios

```bash
# Iniciar un servicio
sudo /opt/virtualmin-enterprise/bin/service.sh start monitoring

# Detener un servicio
sudo /opt/virtualmin-enterprise/bin/service.sh stop monitoring

# Reiniciar un servicio
sudo /opt/virtualmin-enterprise/bin/service.sh restart monitoring

# Recargar la configuración de un servicio
sudo /opt/virtualmin-enterprise/bin/service.sh reload monitoring
```

#### Actualización del Sistema

```bash
# Actualizar Virtualmin Enterprise
sudo /opt/virtualmin-enterprise/bin/update.sh

# Actualizar un componente específico
sudo /opt/virtualmin-enterprise/bin/update.sh --component monitoring

# Verificar actualizaciones disponibles
sudo /opt/virtualmin-enterprise/bin/update.sh --check
```

#### Gestión de Respaldos

```bash
# Crear un respaldo manual
sudo /opt/virtualmin-enterprise/bin/backup.sh create

# Restaurar un respaldo
sudo /opt/virtualmin-enterprise/bin/backup.sh restore 2023-10-15

# Listar respaldos disponibles
sudo /opt/virtualmin-enterprise/bin/backup.sh list

# Verificar integridad de respaldos
sudo /opt/virtualmin-enterprise/bin/backup.sh verify
```

#### Gestión de Seguridad

```bash
# Ejecutar un escaneo de seguridad completo
sudo /opt/virtualmin-enterprise/bin/security.sh scan

# Ejecutar un escaneo específico
sudo /opt/virtualmin-enterprise/bin/security.sh scan --type vulnerability

# Aplicar reglas de hardening
sudo /opt/virtualmin-enterprise/bin/security.sh harden

# Generar informe de seguridad
sudo /opt/virtualmin-enterprise/bin/security.sh report
```

## Monitoreo y Alertas

Virtualmin Enterprise incluye un sistema completo de monitoreo y alertas basado en Prometheus y Grafana.

### Métricas Disponibles

#### Métricas del Sistema

- **Uso de CPU**: Porcentaje de CPU utilizado por cada proceso
- **Uso de Memoria**: Memoria utilizada vs. memoria disponible
- **Uso de Disco**: Espacio utilizado en cada partición
- **Uso de Red**: Tráfico de red entrante y saliente
- **Conexiones de Red**: Número de conexiones activas

#### Métricas de Aplicaciones

- **Servidor Web**: Solicitudes por segundo, tiempo de respuesta, códigos de estado
- **Base de Datos**: Conexiones, consultas por segundo, tiempo de consulta
- **Virtualmin**: Sesiones activas, operaciones realizadas, tiempo de respuesta

#### Métricas de Seguridad

- **Intentos de Inicio de Sesión**: Exitosos y fallidos
- **Eventos de Seguridad**: Bloqueos, alertas, detecciones
- **Vulnerabilidades**: Número de vulnerabilidades detectadas
- **Estado del Firewall**: Reglas aplicadas, tráfico bloqueado

### Configuración de Alertas

Las alertas se configuran a través del archivo `/opt/virtualmin-enterprise/monitoring/alerts.yml`:

```yaml
groups:
  - name: virtualmin_alerts
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de CPU en {{ $labels.instance }}"
          description: "El uso de CPU es superior al 80% en {{ $labels.instance }} durante más de 5 minutos"
      
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Alto uso de memoria en {{ $labels.instance }}"
          description: "El uso de memoria es superior al 80% en {{ $labels.instance }} durante más de 5 minutos"
      
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 20
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Espacio en disco bajo en {{ $labels.instance }}"
          description: "El espacio disponible en disco es inferior al 20% en {{ $labels.instance }}: {{ $labels.mountpoint }}"
      
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Servicio caído: {{ $labels.job }}"
          description: "El servicio {{ $labels.job }} está caído en {{ $labels.instance }}"
```

### Canales de Notificación

Las alertas pueden enviarse a través de múltiples canales:

#### Correo Electrónico

```yaml
email_configs:
  - to: admin@example.com
    from: alerts@virtualmin.example.com
    smarthost: smtp.example.com:587
    auth_username: alerts@virtualmin.example.com
    auth_password: password
    require_tls: true
```

#### Slack

```yaml
slack_configs:
  - api_url: YOUR_SLACK_WEBHOOK_URL_HERE
    channel: #alerts
    title: 'Virtualmin Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### Webhook

```yaml
webhook_configs:
  - url: https://api.example.com/webhooks/alerts
    send_resolved: true
```

## Seguridad y Hardening

Virtualmin Enterprise incluye un sistema integral de seguridad y hardening para proteger la infraestructura.

### Escaneo de Vulnerabilidades

El sistema realiza escaneos automáticos de vulnerabilidades utilizando múltiples herramientas:

#### Nmap

```bash
# Ejecutar escaneo de red
sudo /opt/virtualmin-enterprise/bin/nmap_scan.sh --target 192.168.1.0/24

# Ejecutar escaneo de puertos
sudo /opt/virtualmin-enterprise/bin/nmap_scan.sh --target 192.168.1.10 --ports 1-1000

# Ejecutar escaneo de scripts
sudo /opt/virtualmin-enterprise/bin/nmap_scan.sh --target 192.168.1.10 --scripts
```

#### Lynis

```bash
# Ejecutar escaneo de seguridad del sistema
sudo /opt/virtualmin-enterprise/bin/lynis_scan.sh

# Generar informe detallado
sudo /opt/virtualmin-enterprise/bin/lynis_scan.sh --report-file /tmp/lynis_report.html
```

#### Nikto

```bash
# Ejecutar escaneo de seguridad web
sudo /opt/virtualmin-enterprise/bin/nikto_scan.sh --target https://virtualmin.example.com

# Escanear con opciones específicas
sudo /opt/virtualmin-enterprise/bin/nikto_scan.sh --target https://virtualmin.example.com --Tuning 9
```

#### SSLScan

```bash
# Ejecutar escaneo de certificados SSL
sudo /opt/virtualmin-enterprise/bin/ssls