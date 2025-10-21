#!/usr/bin/env python3

# Script de integración de Wazuh SIEM con Virtualmin Enterprise
# Este script configura la centralización de logs y alertas de seguridad

import json
import os
import sys
import time
import logging
import requests
import subprocess
from datetime import datetime
from pathlib import Path

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/wazuh_integration.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class WazuhIntegration:
    def __init__(self, config_file=None):
        """Inicializar la integración con Wazuh"""
        self.config = self.load_config(config_file)
        self.wazuh_manager_url = self.config.get('wazuh', {}).get('manager_url', 'https://wazuh-manager.local')
        self.wazuh_api_user = self.config.get('wazuh', {}).get('api_user', 'wazuh')
        self.wazuh_api_password = self.config.get('wazuh', {}).get('api_password', 'wazuh')
        self.virtualmin_log_path = self.config.get('virtualmin', {}).get('log_path', '/var/log/virtualmin')
        self.webmin_log_path = self.config.get('webmin', {}).get('log_path', '/var/log/webmin')
        self.apache_log_path = self.config.get('apache', {}).get('log_path', '/var/log/apache2')
        self.nginx_log_path = self.config.get('nginx', {}).get('log_path', '/var/log/nginx')
        self.mysql_log_path = self.config.get('mysql', {}).get('log_path', '/var/log/mysql')
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Obtener token de API de Wazuh
        self.wazuh_api_token = self.get_wazuh_api_token()
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "wazuh": {
                "manager_url": "https://wazuh-manager.local",
                "api_user": "wazuh",
                "api_password": "wazuh",
                "agent_name_prefix": "virtualmin-enterprise"
            },
            "virtualmin": {
                "log_path": "/var/log/virtualmin",
                "logs": ["access_log", "error_log", "audit_log"]
            },
            "webmin": {
                "log_path": "/var/log/webmin",
                "logs": ["miniserv.log", "webmin.log"]
            },
            "apache": {
                "log_path": "/var/log/apache2",
                "logs": ["access.log", "error.log"]
            },
            "nginx": {
                "log_path": "/var/log/nginx",
                "logs": ["access.log", "error.log"]
            },
            "mysql": {
                "log_path": "/var/log/mysql",
                "logs": ["error.log", "slow.log"]
            },
            "alerts": {
                "slack_webhook": "",
                "email_recipients": [],
                "critical_threshold": 3
            }
        }
        
        if config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    user_config = json.load(f)
                
                # Fusionar configuración por defecto con configuración de usuario
                for section in default_config:
                    if section in user_config:
                        default_config[section].update(user_config[section])
                
                return default_config
            except (json.JSONDecodeError, IOError) as e:
                logger.error(f"Error al cargar configuración: {e}")
                return default_config
        else:
            return default_config
    
    def create_directories(self):
        """Crear directorios necesarios"""
        directories = [
            '/var/log/virtualmin-enterprise',
            '/opt/virtualmin-enterprise/wazuh',
            '/opt/virtualmin-enterprise/wazuh/rules',
            '/opt/virtualmin-enterprise/wazuh/decoders',
            '/opt/virtualmin-enterprise/wazuh/agents'
        ]
        
        for directory in directories:
            try:
                os.makedirs(directory, exist_ok=True)
                logger.info(f"Directorio creado: {directory}")
            except OSError as e:
                logger.error(f"Error al crear directorio {directory}: {e}")
    
    def get_wazuh_api_token(self):
        """Obtener token de API de Wazuh"""
        try:
            auth_url = f"{self.wazuh_manager_url}/security/user/authenticate"
            headers = {
                'Content-Type': 'application/json'
            }
            auth_data = {
                'username': self.wazuh_api_user,
                'password': self.wazuh_api_password
            }
            
            response = requests.post(auth_url, headers=headers, json=auth_data, verify=False)
            response.raise_for_status()
            
            token = response.json().get('data', {}).get('token')
            if token:
                logger.info("Token de API de Wazuh obtenido exitosamente")
                return token
            else:
                logger.error("No se pudo obtener el token de API de Wazuh")
                return None
        except Exception as e:
            logger.error(f"Error al obtener token de API de Wazuh: {e}")
            return None
    
    def create_wazuh_rules(self):
        """Crear reglas personalizadas para Wazuh"""
        rules_file = "/opt/virtualmin-enterprise/wazuh/rules/virtualmin_rules.xml"
        
        rules_content = """<?xml version="1.0" encoding="UTF-8"?>
<group name="virtualmin,">
    <rule id="100001" level="12">
        <if_sid>5501</if_sid>
        <field name="program">^virtualmin$</field>
        <description>Virtualmin: Authentication failure</description>
        <group>authentication_failures,pci_dss_10.2.4,pci_dss_10.2.5,</group>
    </rule>
    
    <rule id="100002" level="5">
        <if_sid>5501</if_sid>
        <field name="program">^virtualmin$</field>
        <match>successful login</match>
        <description>Virtualmin: Successful authentication</description>
        <group>authentication_success,</group>
    </rule>
    
    <rule id="100003" level="10">
        <if_sid>5710</if_sid>
        <field name="url">^/virtual-server/</field>
        <match>save.cgi</match>
        <description>Virtualmin: Virtual server configuration modified</description>
        <group>config_changed,</group>
    </rule>
    
    <rule id="100004" level="8">
        <if_sid>5501</if_sid>
        <field name="program">^webmin$</field>
        <match>Authentication failed</match>
        <description>Webmin: Authentication failure</description>
        <group>authentication_failures,pci_dss_10.2.4,pci_dss_10.2.5,</group>
    </rule>
    
    <rule id="100005" level="5">
        <if_sid>5501</if_sid>
        <field name="program">^webmin$</field>
        <match>successful login</match>
        <description>Webmin: Successful authentication</description>
        <group>authentication_success,</group>
    </rule>
    
    <rule id="100006" level="7">
        <decoded_as>apache-accesslog</decoded_as>
        <field name="url">^/virtualmin/</field>
        <match>POST</match>
        <description>Virtualmin: Administrative action performed</description>
        <group>access_control,</group>
    </rule>
    
    <rule id="100007" level="9">
        <decoded_as>mysql</decoded_as>
        <match>error|denied|failed</match>
        <description>MySQL: Database error or access denied</description>
        <group>database_errors,access_denied,</group>
    </rule>
    
    <rule id="100008" level="8">
        <decoded_as>nginx</decoded_as>
        <field name="status_code">^[45]</field>
        <description>Nginx: HTTP error response</description>
        <group>web_errors,</group>
    </rule>
    
    <rule id="100009" level="10">
        <if_sid>100001</if_sid>
        <time>5</time>
        <same_source_ip />
        <description>Virtualmin: Multiple authentication failures from same IP</description>
        <group>authentication_failures,pci_dss_10.2.4,pci_dss_10.2.5,</group>
    </rule>
    
    <rule id="100010" level="12">
        <if_sid>100009</if_sid>
        <time>10</time>
        <same_source_ip />
        <description>Virtualmin: Brute force attack detected</description>
        <group>authentication_failures,pci_dss_10.2.4,pci_dss_10.2.5,</group>
    </rule>
</group>
"""
        
        try:
            with open(rules_file, 'w') as f:
                f.write(rules_content)
            logger.info(f"Reglas de Wazuh creadas: {rules_file}")
            return True
        except IOError as e:
            logger.error(f"Error al crear reglas de Wazuh: {e}")
            return False
    
    def create_wazuh_decoders(self):
        """Crear decoders personalizados para Wazuh"""
        decoders_file = "/opt/virtualmin-enterprise/wazuh/decoders/virtualmin_decoders.xml"
        
        decoders_content = """<?xml version="1.0" encoding="UTF-8"?>
<decoder name="virtualmin">
    <prematch>^virtualmin: </prematch>
</decoder>

<decoder name="webmin">
    <prematch>^webmin: </prematch>
</decoder>

<decoder name="virtualmin-access">
    <parent>apache-accesslog</parent>
    <prematch>^\\S+ \\S+ \\S+ \\[\\S+ \\S+\\] "\\w+ /virtualmin/</prematch>
    <order>url,method,status</order>
</decoder>

<decoder name="virtualmin-error">
    <parent>syslog</parent>
    <prematch>^\\S+ \\d+ \\d+:\\d+:\\d+ \\S+ virtualmin\\[</prematch>
    <regex offset="after_prematch">^\\S+: (\\S+) (.+)$</regex>
    <order>level,message</order>
</decoder>

<decoder name="webmin-error">
    <parent>syslog</parent>
    <prematch>^\\S+ \\d+ \\d+:\\d+:\\d+ \\S+ webmin\\[</prematch>
    <regex offset="after_prematch">^(\\S+) (.+)$</regex>
    <order>level,message</order>
</decoder>
"""
        
        try:
            with open(decoders_file, 'w') as f:
                f.write(decoders_content)
            logger.info(f"Decoders de Wazuh creados: {decoders_file}")
            return True
        except IOError as e:
            logger.error(f"Error al crear decoders de Wazuh: {e}")
            return False
    
    def register_wazuh_agent(self, hostname):
        """Registrar un agente en Wazuh"""
        if not self.wazuh_api_token:
            logger.error("No se dispone de token de API de Wazuh")
            return False
        
        try:
            agent_name = f"{self.config['wazuh']['agent_name_prefix']}-{hostname}"
            
            # Verificar si el agente ya existe
            agents_url = f"{self.wazuh_manager_url}/agents"
            headers = {
                'Authorization': f'Bearer {self.wazuh_api_token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(agents_url, headers=headers, verify=False)
            response.raise_for_status()
            
            agents = response.json().get('data', {}).get('affected_items', [])
            agent_exists = False
            
            for agent in agents:
                if agent.get('name') == agent_name:
                    agent_exists = True
                    agent_id = agent.get('id')
                    logger.info(f"Agente {agent_name} ya existe con ID: {agent_id}")
                    break
            
            # Si el agente no existe, crearlo
            if not agent_exists:
                agent_data = {
                    'name': agent_name,
                    'ip': hostname
                }
                
                response = requests.post(agents_url, headers=headers, json=agent_data, verify=False)
                response.raise_for_status()
                
                agent_id = response.json().get('data', {}).get('id')
                logger.info(f"Agente {agent_name} creado con ID: {agent_id}")
            
            # Generar clave del agente
            key_url = f"{self.wazuh_manager_url}/agents/{agent_id}/key"
            response = requests.get(key_url, headers=headers, verify=False)
            response.raise_for_status()
            
            agent_key = response.json().get('data', {}).get('key')
            
            # Guardar clave del agente
            key_file = f"/opt/virtualmin-enterprise/wazuh/agents/{hostname}.key"
            with open(key_file, 'w') as f:
                f.write(agent_key)
            
            logger.info(f"Clave del agente guardada: {key_file}")
            return True
        except Exception as e:
            logger.error(f"Error al registrar agente Wazuh: {e}")
            return False
    
    def install_wazuh_agent(self, hostname):
        """Instalar el agente de Wazuh"""
        try:
            # Obtener clave del agente
            key_file = f"/opt/virtualmin-enterprise/wazuh/agents/{hostname}.key"
            if not os.path.exists(key_file):
                logger.error(f"No se encontró la clave del agente: {key_file}")
                return False
            
            with open(key_file, 'r') as f:
                agent_key = f.read().strip()
            
            # Descargar e instalar el agente de Wazuh
            install_script = "/tmp/install_wazuh_agent.sh"
            
            with open(install_script, 'w') as f:
                f.write(f"""#!/bin/bash
# Script de instalación del agente de Wazuh

set -e

# Configuración
WAZUH_MANAGER="{self.wazuh_manager_url.replace('https://', '').replace('http://', '').split(':')[0]}"
WAZUH_AGENT_KEY="{agent_key}"
AGENT_NAME="{self.config['wazuh']['agent_name_prefix']}-{hostname}"

# Detectar distribución
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
else
    DISTRO="unknown"
    VERSION="unknown"
fi

# Instalar agente según distribución
case $DISTRO in
    ubuntu|debian)
        # Agregar repositorio de Wazuh
        curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add -
        echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
        apt-get update
        apt-get install -y wazuh-agent
        ;;
    centos|rhel|fedora)
        # Agregar repositorio de Wazuh
        rpm --import https://packages.wazuh.com/key/GPG-KEY-WAZUH
        cat > /etc/yum.repos.d/wazuh.repo << EOF
[wazuh]
gpgcheck=1
gpgkey=https://packages.wazuh.com/key/GPG-KEY-WAZUH
enabled=1
name=Wazuh repository
baseurl=https://packages.wazuh.com/4.x/yum/
protect=1
EOF
        yum install -y wazuh-agent
        ;;
    *)
        echo "Distribución no soportada: $DISTRO"
        exit 1
        ;;
esac

# Configurar agente
sed -i "s/<address>MANAGER_IP<\\/address>/<address>$WAZUH_MANAGER<\\/address>/" /var/ossec/etc/ossec.conf
sed -i "s/<\\/client>/<client>\\n  <server>\\n    <address>$WAZUH_MANAGER<\\/address>\\n  <\\/server>\\n<\\/client>/" /var/ossec/etc/ossec.conf

# Añadir clave del agente
echo $WAZUH_AGENT_KEY > /var/ossec/etc/client.keys

# Habilitar e iniciar servicio
systemctl enable wazuh-agent
systemctl restart wazuh-agent

echo "Agente de Wazuh instalado y configurado"
""")
            
            # Hacer ejecutable el script
            os.chmod(install_script, 0o755)
            
            # Ejecutar script de instalación
            subprocess.run([install_script], check=True)
            
            # Limpiar
            os.remove(install_script)
            
            logger.info(f"Agente de Wazuh instalado en {hostname}")
            return True
        except Exception as e:
            logger.error(f"Error al instalar agente de Wazuh: {e}")
            return False
    
    def configure_log_forwarding(self):
        """Configurar el reenvío de logs al agente de Wazuh"""
        try:
            # Configurar ossec.conf para monitorear logs específicos
            ossec_config = "/var/ossec/etc/ossec.conf"
            
            # Leer configuración actual
            with open(ossec_config, 'r') as f:
                config_content = f.read()
            
            # Sección de monitoreo de logs a añadir
            logs_to_monitor = """
  <!-- Virtualmin logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/virtualmin/access_log</location>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/virtualmin/error_log</location>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/virtualmin/audit_log</location>
  </localfile>
  
  <!-- Webmin logs -->
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/webmin/miniserv.log</location>
  </localfile>
  
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/webmin/webmin.log</location>
  </localfile>
  
  <!-- Apache logs -->
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/access.log</location>
  </localfile>
  
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/error.log</location>
  </localfile>
  
  <!-- Nginx logs -->
  <localfile>
    <log_format>nginx</log_format>
    <location>/var/log/nginx/access.log</location>
  </localfile>
  
  <localfile>
    <log_format>nginx</log_format>
    <location>/var/log/nginx/error.log</location>
  </localfile>
  
  <!-- MySQL logs -->
  <localfile>
    <log_format>mysql</log_format>
    <location>/var/log/mysql/error.log</location>
  </localfile>
  
  <localfile>
    <log_format>mysql</log_format>
    <location>/var/log/mysql/slow.log</location>
  </localfile>
"""
            
            # Insertar configuración de logs antes de la etiqueta </ossec_config>
            if "</ossec_config>" in config_content:
                config_content = config_content.replace("</ossec_config>", logs_to_monitor + "\n</ossec_config>")
                
                # Escribir configuración actualizada
                with open(ossec_config, 'w') as f:
                    f.write(config_content)
                
                logger.info("Configuración de monitoreo de logs actualizada")
                
                # Reiniciar agente de Wazuh
                subprocess.run(["systemctl", "restart", "wazuh-agent"], check=True)
                
                return True
            else:
                logger.error("No se encontró la etiqueta </ossec_config> en el archivo de configuración")
                return False
        except Exception as e:
            logger.error(f"Error al configurar reenvío de logs: {e}")
            return False
    
    def setup_alerts(self):
        """Configurar alertas personalizadas"""
        try:
            # Crear script de alertas
            alert_script = "/opt/virtualmin-enterprise/wazuh/alerts.py"
            
            with open(alert_script, 'w') as f:
                f.write(f"""#!/usr/bin/env python3

import json
import requests
import logging
from datetime import datetime

# Configuración
SLACK_WEBHOOK = "{self.config['alerts'].get('slack_webhook', '')}"
EMAIL_RECIPIENTS = {self.config['alerts'].get('email_recipients', [])}
CRITICAL_THRESHOLD = {self.config['alerts'].get('critical_threshold', 3)}
WAZUH_API = "{self.wazuh_manager_url}/api/v1"
WAZUH_TOKEN = "{self.wazuh_api_token}"

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/wazuh_alerts.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def get_wazuh_alerts():
    """Obtener alertas de Wazuh"""
    try:
        headers = {{
            'Authorization': f'Bearer {{WAZUH_TOKEN}}',
            'Content-Type': 'application/json'
        }}
        
        # Obtener alertas de las últimas 24 horas
        params = {{
            'rule_level': '5,8,10,12',
            'date': '24h'
        }}
        
        response = requests.get(
            f"{{WAZUH_API}}/alerts",
            headers=headers,
            params=params,
            verify=False
        )
        response.raise_for_status()
        
        return response.json().get('data', {}).get('affected_items', [])
    except Exception as e:
        logger.error(f"Error al obtener alertas de Wazuh: {{e}}")
        return []

def send_slack_alert(alert):
    """Enviar alerta a Slack"""
    if not SLACK_WEBHOOK:
        return False
    
    try:
        payload = {{
            "text": f"🚨 Virtualmin Enterprise Security Alert",
            "attachments": [
                {{
                    "color": "danger" if alert.get('rule', {}).get('level', 0) >= 10 else "warning",
                    "title": alert.get('rule', {}).get('description', 'Unknown Alert'),
                    "fields": [
                        {{
                            "title": "Level",
                            "value": alert.get('rule', {}).get('level', 0),
                            "short": True
                        }},
                        {{
                            "title": "Agent",
                            "value": alert.get('agent', {}).get('name', 'Unknown'),
                            "short": True
                        }},
                        {{
                            "title": "Timestamp",
                            "value": alert.get('timestamp', 'Unknown'),
                            "short": True
                        }},
                        {{
                            "title": "Rule ID",
                            "value": alert.get('rule', {}).get('id', 0),
                            "short": True
                        }},
                        {{
                            "title": "Full Log",
                            "value": alert.get('full_log', 'No details'),
                            "short": False
                        }}
                    ],
                    "footer": "Virtualmin Enterprise SIEM",
                    "ts": int(datetime.now().timestamp())
                }}
            ]
        }}
        
        response = requests.post(SLACK_WEBHOOK, json=payload)
        response.raise_for_status()
        
        logger.info(f"Alerta enviada a Slack: {{alert.get('rule', {{}}).get('description', 'Unknown')}}")
        return True
    except Exception as e:
        logger.error(f"Error al enviar alerta a Slack: {{e}}")
        return False

def send_email_alert(alert):
    """Enviar alerta por correo electrónico"""
    # Implementación de envío de correo electrónico
    # Esto requeriría una librería como smtplib
    pass

def analyze_alerts():
    """Analizar alertas y enviar notificaciones"""
    alerts = get_wazuh_alerts()
    
    if not alerts:
        logger.info("No se encontraron alertas")
        return
    
    # Contar alertas por nivel
    alert_counts = {{}}
    for alert in alerts:
        level = alert.get('rule', {}).get('level', 0)
        alert_counts[level] = alert_counts.get(level, 0) + 1
    
    # Enviar alertas críticas
    for alert in alerts:
        level = alert.get('rule', {}).get('level', 0)
        if level >= 10:  # Nivel crítico
            send_slack_alert(alert)
            send_email_alert(alert)
    
    # Enviar resumen si hay muchas alertas
    total_alerts = len(alerts)
    if total_alerts >= CRITICAL_THRESHOLD:
        summary = f"Se detectaron {{total_alerts}} alertas en las últimas 24 horas. "
        summary += "Por favor, revise el panel de Wazuh para más detalles."
        
        if SLACK_WEBHOOK:
            payload = {{
                "text": f"📊 Virtualmin Enterprise Security Summary",
                "attachments": [
                    {{
                        "color": "warning",
                        "title": "Resumen de Alertas",
                        "text": summary,
                        "fields": [
                            {{
                                "title": "Total de Alertas",
                                "value": total_alerts,
                                "short": True
                            }},
                            {{
                                "title": "Alertas Críticas",
                                "value": alert_counts.get(12, 0),
                                "short": True
                            }},
                            {{
                                "title": "Alertas Altas",
                                "value": alert_counts.get(10, 0),
                                "short": True
                            }},
                            {{
                                "title": "Alertas Medias",
                                "value": alert_counts.get(8, 0),
                                "short": True
                            }}
                        ],
                        "footer": "Virtualmin Enterprise SIEM",
                        "ts": int(datetime.now().timestamp())
                    }}
                ]
            }}
            
            try:
                response = requests.post(SLACK_WEBHOOK, json=payload)
                response.raise_for_status()
                logger.info("Resumen de alertas enviado a Slack")
            except Exception as e:
                logger.error(f"Error al enviar resumen a Slack: {{e}}")

if __name__ == "__main__":
    analyze_alerts()
""")
            
            # Hacer ejecutable el script
            os.chmod(alert_script, 0o755)
            
            # Crear tarea cron para ejecutar el script cada hora
            cron_job = f"0 * * * * {alert_script} >> /var/log/virtualmin-enterprise/wazuh_alerts.log 2>&1"
            
            # Añadir tarea cron
            subprocess.run(["crontab", "-l"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            subprocess.run(["(crontab -l 2>/dev/null; echo '{cron_job}') | crontab -"], shell=True, check=True)
            
            logger.info("Sistema de alertas configurado")
            return True
        except Exception as e:
            logger.error(f"Error al configurar alertas: {e}")
            return False
    
    def deploy_siem(self, hostname=None):
        """Desplegar el sistema SIEM completo"""
        logger.info("Iniciando despliegue del sistema SIEM")
        
        # Obtener hostname si no se proporciona
        if not hostname:
            hostname = subprocess.run(["hostname"], stdout=subprocess.PIPE, text=True).stdout.strip()
        
        # Crear reglas y decoders
        if not self.create_wazuh_rules():
            logger.error("Error al crear reglas de Wazuh")
            return False
        
        if not self.create_wazuh_decoders():
            logger.error("Error al crear decoders de Wazuh")
            return False
        
        # Registrar agente
        if not self.register_wazuh_agent(hostname):
            logger.error("Error al registrar agente de Wazuh")
            return False
        
        # Instalar agente
        if not self.install_wazuh_agent(hostname):
            logger.error("Error al instalar agente de Wazuh")
            return False
        
        # Configurar reenvío de logs
        if not self.configure_log_forwarding():
            logger.error("Error al configurar reenvío de logs")
            return False
        
        # Configurar alertas
        if not self.setup_alerts():
            logger.error("Error al configurar alertas")
            return False
        
        logger.info("Despliegue del sistema SIEM completado exitosamente")
        return True

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Integración de Wazuh SIEM con Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/config/wazuh_config.json')
    parser.add_argument('--hostname', help='Hostname del agente')
    parser.add_argument('--deploy', action='store_true', help='Desplegar sistema SIEM completo')
    
    args = parser.parse_args()
    
    # Inicializar integración
    wazuh_integration = WazuhIntegration(args.config)
    
    if args.deploy:
        # Desplegar sistema SIEM
        success = wazuh_integration.deploy_siem(args.hostname)
        sys.exit(0 if success else 1)
    else:
        logger.error("Debe especificar una acción. Use --deploy para desplegar el sistema SIEM.")
        sys.exit(1)

if __name__ == "__main__":
    main()