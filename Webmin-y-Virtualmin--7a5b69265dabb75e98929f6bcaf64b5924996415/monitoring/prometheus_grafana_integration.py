#!/usr/bin/env python3

# Sistema de Integración de Prometheus y Grafana para Métricas y Alertas Centralizadas
# para Virtualmin Enterprise

import json
import os
import sys
import time
import subprocess
import logging
import sqlite3
import requests
import yaml
import shutil
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import signal
import psutil

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/prometheus_grafana_integration.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class PrometheusGrafanaIntegration:
    def __init__(self, config_file=None):
        """Inicializar el sistema de integración de Prometheus y Grafana"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/monitoring/metrics.db')
        self.prometheus_dir = self.config.get('prometheus', {}).get('path', '/opt/prometheus')
        self.grafana_dir = self.config.get('grafana', {}).get('path', '/opt/grafana')
        self.alertmanager_dir = self.config.get('alertmanager', {}).get('path', '/opt/alertmanager')
        self.node_exporter_dir = self.config.get('node_exporter', {}).get('path', '/opt/node_exporter')
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
        
        # Estado de los servicios
        self.service_status = {}
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/monitoring/metrics.db"
            },
            "prometheus": {
                "path": "/opt/prometheus",
                "version": "2.45.0",
                "download_url": "https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz",
                "port": 9090,
                "retention": "15d",
                "scrape_interval": "15s"
            },
            "grafana": {
                "path": "/opt/grafana",
                "version": "10.0.0",
                "download_url": "https://dl.grafana.com/oss/release/grafana-10.0.0.linux-amd64.tar.gz",
                "port": 3000,
                "admin_user": "admin",
                "admin_password": "admin123"
            },
            "alertmanager": {
                "path": "/opt/alertmanager",
                "version": "0.26.0",
                "download_url": "https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz",
                "port": 9093
            },
            "node_exporter": {
                "path": "/opt/node_exporter",
                "version": "1.6.1",
                "download_url": "https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz",
                "port": 9100
            },
            "targets": {
                "web_server": {
                    "host": "localhost",
                    "port": 80,
                    "metrics_path": "/metrics",
                    "scrape_interval": "15s"
                },
                "database": {
                    "host": "localhost",
                    "port": 3306,
                    "metrics_path": "/metrics",
                    "scrape_interval": "30s"
                },
                "virtualmin": {
                    "host": "localhost",
                    "port": 10000,
                    "metrics_path": "/metrics",
                    "scrape_interval": "15s"
                },
                "node": {
                    "host": "localhost",
                    "port": 9100,
                    "metrics_path": "/metrics",
                    "scrape_interval": "15s"
                }
            },
            "alerting": {
                "enabled": True,
                "rules_file": "/opt/prometheus/alert_rules.yml",
                "notification_channels": ["email", "slack"],
                "smtp_server": "",
                "smtp_port": 587,
                "smtp_username": "",
                "smtp_password": "",
                "slack_webhook": ""
            },
            "dashboards": {
                "path": "/opt/grafana/dashboards",
                "provisioning": "/opt/grafana/provisioning",
                "datasource_name": "Prometheus",
                "datasource_url": "http://localhost:9090"
            }
        }
        
        if config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    user_config = json.load(f)
                
                # Fusionar configuración por defecto con configuración de usuario
                for section in default_config:
                    if section in user_config:
                        if isinstance(default_config[section], dict):
                            default_config[section].update(user_config[section])
                        else:
                            default_config[section] = user_config[section]
                
                return default_config
            except (json.JSONDecodeError, IOError) as e:
                logger.error(f"Error al cargar configuración: {e}")
                return default_config
        else:
            return default_config
    
    def create_directories(self):
        """Crear directorios necesarios"""
        directories = [
            '/opt/virtualmin-enterprise/monitoring',
            os.path.dirname(self.db_path),
            self.prometheus_dir,
            self.grafana_dir,
            self.alertmanager_dir,
            self.node_exporter_dir,
            self.config['dashboards']['path'],
            self.config['dashboards']['provisioning'],
            f"{self.config['dashboards']['provisioning']}/datasources",
            f"{self.config['dashboards']['provisioning']}/dashboards",
            '/var/log/virtualmin-enterprise'
        ]
        
        for directory in directories:
            try:
                os.makedirs(directory, exist_ok=True)
                logger.info(f"Directorio creado: {directory}")
            except OSError as e:
                logger.error(f"Error al crear directorio {directory}: {e}")
    
    def init_database(self):
        """Inicializar base de datos SQLite"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            # Crear tabla de métricas
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    metric_name TEXT NOT NULL,
                    metric_value REAL,
                    labels TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de alertas
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS alerts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    alert_name TEXT NOT NULL,
                    alert_state TEXT,
                    alert_value REAL,
                    threshold_value REAL,
                    message TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de dashboards
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS dashboards (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    dashboard_name TEXT UNIQUE NOT NULL,
                    dashboard_uid TEXT,
                    dashboard_json TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            conn.commit()
            conn.close()
            
            logger.info("Base de datos inicializada")
            return True
        except Exception as e:
            logger.error(f"Error al inicializar base de datos: {e}")
            return False
    
    def get_db_connection(self):
        """Obtener conexión a la base de datos"""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn
    
    def install_prometheus(self):
        """Instalar Prometheus"""
        try:
            # Verificar si Prometheus ya está instalado
            if os.path.exists(os.path.join(self.prometheus_dir, 'prometheus')):
                logger.info("Prometheus ya está instalado")
                return True
            
            # Descargar Prometheus
            download_url = self.config['prometheus']['download_url']
            tar_file = os.path.join('/tmp', os.path.basename(download_url))
            
            logger.info(f"Descargando Prometheus desde {download_url}")
            subprocess.run(['wget', '-O', tar_file, download_url], check=True)
            
            # Extraer Prometheus
            logger.info("Extrayendo Prometheus")
            extract_dir = os.path.join('/tmp', f"prometheus-{self.config['prometheus']['version']}.linux-amd64")
            subprocess.run(['tar', '-xzf', tar_file, '-C', '/tmp'], check=True)
            
            # Mover a directorio de instalación
            subprocess.run(['mv', extract_dir, self.prometheus_dir], check=True)
            
            # Establecer permisos de ejecución
            prometheus_bin = os.path.join(self.prometheus_dir, 'prometheus')
            subprocess.run(['chmod', '+x', prometheus_bin], check=True)
            
            # Crear directorio de datos
            data_dir = os.path.join(self.prometheus_dir, 'data')
            os.makedirs(data_dir, exist_ok=True)
            
            # Crear archivo de configuración
            self.create_prometheus_config()
            
            # Limpiar
            os.remove(tar_file)
            
            logger.info("Prometheus instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar Prometheus: {e}")
            return False
    
    def create_prometheus_config(self):
        """Crear archivo de configuración de Prometheus"""
        try:
            config_file = os.path.join(self.prometheus_dir, 'prometheus.yml')
            
            # Construir configuración
            prometheus_config = {
                'global': {
                    'scrape_interval': self.config['prometheus']['scrape_interval'],
                    'evaluation_interval': '15s'
                },
                'rule_files': [
                    self.config['alerting']['rules_file']
                ],
                'alerting': {
                    'alertmanagers': [
                        {
                            'static_configs': [
                                {
                                    'targets': [
                                        f"localhost:{self.config['alertmanager']['port']}"
                                    ]
                                }
                            ]
                        }
                    ]
                },
                'scrape_configs': []
            }
            
            # Añadir configuración de scrape para cada objetivo
            for target_name, target_config in self.config['targets'].items():
                scrape_config = {
                    'job_name': target_name,
                    'static_configs': [
                        {
                            'targets': [
                                f"{target_config['host']}:{target_config['port']}"
                            ]
                        }
                    ],
                    'metrics_path': target_config['metrics_path'],
                    'scrape_interval': target_config['scrape_interval']
                }
                
                prometheus_config['scrape_configs'].append(scrape_config)
            
            # Escribir archivo de configuración
            with open(config_file, 'w') as f:
                yaml.dump(prometheus_config, f)
            
            logger.info(f"Archivo de configuración de Prometheus creado: {config_file}")
            return True
        except Exception as e:
            logger.error(f"Error al crear archivo de configuración de Prometheus: {e}")
            return False
    
    def install_grafana(self):
        """Instalar Grafana"""
        try:
            # Verificar si Grafana ya está instalado
            if os.path.exists(os.path.join(self.grafana_dir, 'bin', 'grafana-server')):
                logger.info("Grafana ya está instalado")
                return True
            
            # Descargar Grafana
            download_url = self.config['grafana']['download_url']
            tar_file = os.path.join('/tmp', os.path.basename(download_url))
            
            logger.info(f"Descargando Grafana desde {download_url}")
            subprocess.run(['wget', '-O', tar_file, download_url], check=True)
            
            # Extraer Grafana
            logger.info("Extrayendo Grafana")
            extract_dir = os.path.join('/tmp', f"grafana-{self.config['grafana']['version']}")
            subprocess.run(['tar', '-xzf', tar_file, '-C', '/tmp'], check=True)
            
            # Mover a directorio de instalación
            subprocess.run(['mv', extract_dir, self.grafana_dir], check=True)
            
            # Crear directorios necesarios
            grafana_data_dir = os.path.join(self.grafana_dir, 'data')
            grafana_logs_dir = os.path.join(self.grafana_dir, 'logs')
            grafana_plugins_dir = os.path.join(self.grafana_dir, 'plugins')
            grafana_provisioning_dir = os.path.join(self.grafana_dir, 'conf', 'provisioning')
            
            for directory in [grafana_data_dir, grafana_logs_dir, grafana_plugins_dir, grafana_provisioning_dir]:
                os.makedirs(directory, exist_ok=True)
            
            # Establecer permisos
            grafana_bin = os.path.join(self.grafana_dir, 'bin', 'grafana-server')
            subprocess.run(['chmod', '+x', grafana_bin], check=True)
            
            # Crear archivo de configuración
            self.create_grafana_config()
            
            # Crear configuración de aprovisionamiento
            self.create_grafana_provisioning()
            
            # Limpiar
            os.remove(tar_file)
            
            logger.info("Grafana instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar Grafana: {e}")
            return False
    
    def create_grafana_config(self):
        """Crear archivo de configuración de Grafana"""
        try:
            config_file = os.path.join(self.grafana_dir, 'conf', 'defaults.ini')
            
            # Leer archivo de configuración por defecto
            default_config_file = os.path.join(self.grafana_dir, 'conf', 'sample.ini')
            
            if os.path.exists(default_config_file):
                with open(default_config_file, 'r') as f:
                    config_content = f.read()
                
                # Modificar configuración
                config_content = config_content.replace(';http_port = 3000', f'http_port = {self.config["grafana"]["port"]}')
                config_content = config_content.replace(';admin_user = admin', f'admin_user = {self.config["grafana"]["admin_user"]}')
                config_content = config_content.replace(';admin_password = admin', f'admin_password = {self.config["grafana"]["admin_password"]}')
                config_content = config_content.replace(';data = data', f'data = {os.path.join(self.grafana_dir, "data")}')
                config_content = config_content.replace(';logs = data/log', f'logs = {os.path.join(self.grafana_dir, "logs")}')
                config_content = config_content.replace(';plugins = data/plugins', f'plugins = {os.path.join(self.grafana_dir, "plugins")}')
                config_content = config_content.replace(';provisioning = conf/provisioning', f'provisioning = {os.path.join(self.grafana_dir, "conf", "provisioning")}')
                
                # Escribir archivo de configuración
                with open(config_file, 'w') as f:
                    f.write(config_content)
                
                logger.info(f"Archivo de configuración de Grafana creado: {config_file}")
                return True
            else:
                logger.error(f"Archivo de configuración por defecto de Grafana no encontrado: {default_config_file}")
                return False
        except Exception as e:
            logger.error(f"Error al crear archivo de configuración de Grafana: {e}")
            return False
    
    def create_grafana_provisioning(self):
        """Crear configuración de aprovisionamiento de Grafana"""
        try:
            # Crear configuración de datasources
            datasources_dir = os.path.join(self.config['dashboards']['provisioning'], 'datasources')
            os.makedirs(datasources_dir, exist_ok=True)
            
            datasource_config = {
                'apiVersion': 1,
                'datasources': [
                    {
                        'name': self.config['dashboards']['datasource_name'],
                        'type': 'prometheus',
                        'access': 'proxy',
                        'url': self.config['dashboards']['datasource_url'],
                        'isDefault': True,
                        'jsonData': {
                            'timeInterval': self.config['prometheus']['scrape_interval']
                        }
                    }
                ]
            }
            
            datasource_file = os.path.join(datasources_dir, 'prometheus.yml')
            with open(datasource_file, 'w') as f:
                yaml.dump(datasource_config, f)
            
            # Crear configuración de dashboards
            dashboards_dir = os.path.join(self.config['dashboards']['provisioning'], 'dashboards')
            os.makedirs(dashboards_dir, exist_ok=True)
            
            dashboard_config = {
                'apiVersion': 1,
                'providers': [
                    {
                        'name': 'default',
                        'orgId': 1,
                        'folder': '',
                        'type': 'file',
                        'disableDeletion': False,
                        'updateIntervalSeconds': 10,
                        'options': {
                            'path': self.config['dashboards']['path']
                        }
                    }
                ]
            }
            
            dashboard_file = os.path.join(dashboards_dir, 'dashboards.yml')
            with open(dashboard_file, 'w') as f:
                yaml.dump(dashboard_config, f)
            
            logger.info("Configuración de aprovisionamiento de Grafana creada")
            return True
        except Exception as e:
            logger.error(f"Error al crear configuración de aprovisionamiento de Grafana: {e}")
            return False
    
    def install_alertmanager(self):
        """Instalar Alertmanager"""
        try:
            # Verificar si Alertmanager ya está instalado
            if os.path.exists(os.path.join(self.alertmanager_dir, 'alertmanager')):
                logger.info("Alertmanager ya está instalado")
                return True
            
            # Descargar Alertmanager
            download_url = self.config['alertmanager']['download_url']
            tar_file = os.path.join('/tmp', os.path.basename(download_url))
            
            logger.info(f"Descargando Alertmanager desde {download_url}")
            subprocess.run(['wget', '-O', tar_file, download_url], check=True)
            
            # Extraer Alertmanager
            logger.info("Extrayendo Alertmanager")
            extract_dir = os.path.join('/tmp', f"alertmanager-{self.config['alertmanager']['version']}.linux-amd64")
            subprocess.run(['tar', '-xzf', tar_file, '-C', '/tmp'], check=True)
            
            # Mover a directorio de instalación
            subprocess.run(['mv', extract_dir, self.alertmanager_dir], check=True)
            
            # Establecer permisos de ejecución
            alertmanager_bin = os.path.join(self.alertmanager_dir, 'alertmanager')
            subprocess.run(['chmod', '+x', alertmanager_bin], check=True)
            
            # Crear directorio de datos
            data_dir = os.path.join(self.alertmanager_dir, 'data')
            os.makedirs(data_dir, exist_ok=True)
            
            # Crear archivo de configuración
            self.create_alertmanager_config()
            
            # Limpiar
            os.remove(tar_file)
            
            logger.info("Alertmanager instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar Alertmanager: {e}")
            return False
    
    def create_alertmanager_config(self):
        """Crear archivo de configuración de Alertmanager"""
        try:
            config_file = os.path.join(self.alertmanager_dir, 'alertmanager.yml')
            
            # Construir configuración
            alertmanager_config = {
                'global': {
                    'smtp_smarthost': f"{self.config['alerting']['smtp_server']}:{self.config['alerting']['smtp_port']}",
                    'smtp_from': 'alerts@virtualmin-enterprise.com',
                    'smtp_auth_username': self.config['alerting']['smtp_username'],
                    'smtp_auth_password': self.config['alerting']['smtp_password']
                },
                'route': {
                    'group_by': ['alertname'],
                    'group_wait': '10s',
                    'group_interval': '10s',
                    'repeat_interval': '1h',
                    'receiver': 'web.hook'
                },
                'receivers': [
                    {
                        'name': 'web.hook',
                        'email_configs': [
                            {
                                'to': 'admin@virtualmin-enterprise.com',
                                'subject': '[Virtualmin Enterprise] Alert: {{ .GroupLabels.alertname }}',
                                'body': |
                                    {{ range .Alerts }}
                                    Alert: {{ .Annotations.summary }}
                                    Description: {{ .Annotations.description }}
                                    {{ end }}
                            }
                        ]
                    }
                ]
            }
            
            # Añadir configuración de Slack si está habilitado
            if self.config['alerting']['slack_webhook']:
                alertmanager_config['receivers'][0]['slack_configs'] = [
                    {
                        'api_url': self.config['alerting']['slack_webhook'],
                        'channel': '#alerts',
                        'title': '[Virtualmin Enterprise] Alert: {{ .GroupLabels.alertname }}',
                        'text': |
                            {{ range .Alerts }}
                            Alert: {{ .Annotations.summary }}
                            Description: {{ .Annotations.description }}
                            {{ end }}
                    }
                ]
            
            # Escribir archivo de configuración
            with open(config_file, 'w') as f:
                yaml.dump(alertmanager_config, f)
            
            logger.info(f"Archivo de configuración de Alertmanager creado: {config_file}")
            return True
        except Exception as e:
            logger.error(f"Error al crear archivo de configuración de Alertmanager: {e}")
            return False
    
    def install_node_exporter(self):
        """Instalar Node Exporter"""
        try:
            # Verificar si Node Exporter ya está instalado
            if os.path.exists(os.path.join(self.node_exporter_dir, 'node_exporter')):
                logger.info("Node Exporter ya está instalado")
                return True
            
            # Descargar Node Exporter
            download_url = self.config['node_exporter']['download_url']
            tar_file = os.path.join('/tmp', os.path.basename(download_url))
            
            logger.info(f"Descargando Node Exporter desde {download_url}")
            subprocess.run(['wget', '-O', tar_file, download_url], check=True)
            
            # Extraer Node Exporter
            logger.info("Extrayendo Node Exporter")
            extract_dir = os.path.join('/tmp', f"node_exporter-{self.config['node_exporter']['version']}.linux-amd64")
            subprocess.run(['tar', '-xzf', tar_file, '-C', '/tmp'], check=True)
            
            # Mover a directorio de instalación
            subprocess.run(['mv', extract_dir, self.node_exporter_dir], check=True)
            
            # Establecer permisos de ejecución
            node_exporter_bin = os.path.join(self.node_exporter_dir, 'node_exporter')
            subprocess.run(['chmod', '+x', node_exporter_bin], check=True)
            
            # Crear servicio systemd
            self.create_node_exporter_service()
            
            # Limpiar
            os.remove(tar_file)
            
            logger.info("Node Exporter instalado exitosamente")
            return True
        except Exception as e:
            logger.error(f"Error al instalar Node Exporter: {e}")
            return False
    
    def create_node_exporter_service(self):
        """Crear servicio systemd para Node Exporter"""
        try:
            service_file = '/etc/systemd/system/node_exporter.service'
            
            service_content = f"""[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
ExecStart={os.path.join(self.node_exporter_dir, 'node_exporter')}

[Install]
WantedBy=multi-user.target
"""
            
            # Crear usuario node_exporter si no existe
            subprocess.run(['useradd', '--no-create-home', '--shell', '/bin/false', 'node_exporter'], check=False)
            
            # Escribir archivo de servicio
            with open(service_file, 'w') as f:
                f.write(service_content)
            
            # Recargar systemd y habilitar servicio
            subprocess.run(['systemctl', 'daemon-reload'], check=True)
            subprocess.run(['systemctl', 'enable', 'node_exporter'], check=True)
            
            logger.info(f"Servicio systemd de Node Exporter creado: {service_file}")
            return True
        except Exception as e:
            logger.error(f"Error al crear servicio systemd de Node Exporter: {e}")
            return False
    
    def create_prometheus_alert_rules(self):
        """Crear reglas de alerta de Prometheus"""
        try:
            rules_file = self.config['alerting']['rules_file']
            
            # Construir reglas de alerta
            alert_rules = {
                'groups': [
                    {
                        'name': 'virtualmin-enterprise',
                        'rules': [
                            {
                                'alert': 'InstanceDown',
                                'expr': 'up == 0',
                                'for': '1m',
                                'labels': {
                                    'severity': 'critical'
                                },
                                'annotations': {
                                    'summary': 'Instance {{ $labels.instance }} is down',
                                    'description': 'Instance {{ $labels.instance }} has been down for more than 1 minute.'
                                }
                            },
                            {
                                'alert': 'HighCPUUsage',
                                'expr': '100 - (avg by(instance) (irate(node_cpu_seconds_total{{mode="idle"}}[5m])) * 100) > 80',
                                'for': '5m',
                                'labels': {
                                    'severity': 'warning'
                                },
                                'annotations': {
                                    'summary': 'High CPU usage on {{ $labels.instance }}',
                                    'description': 'CPU usage is above 80% on {{ $labels.instance }} for more than 5 minutes.'
                                }
                            },
                            {
                                'alert': 'HighMemoryUsage',
                                'expr': '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80',
                                'for': '5m',
                                'labels': {
                                    'severity': 'warning'
                                },
                                'annotations': {
                                    'summary': 'High memory usage on {{ $labels.instance }}',
                                    'description': 'Memory usage is above 80% on {{ $labels.instance }} for more than 5 minutes.'
                                }
                            },
                            {
                                'alert': 'LowDiskSpace',
                                'expr': '(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 20',
                                'for': '5m',
                                'labels': {
                                    'severity': 'warning'
                                },
                                'annotations': {
                                    'summary': 'Low disk space on {{ $labels.instance }}',
                                    'description': 'Disk space is below 20% on {{ $labels.instance }} for more than 5 minutes.'
                                }
                            },
                            {
                                'alert': 'WebServerDown',
                                'expr': 'up{job="web_server"} == 0',
                                'for': '1m',
                                'labels': {
                                    'severity': 'critical'
                                },
                                'annotations': {
                                    'summary': 'Web server is down',
                                    'description': 'Web server {{ $labels.instance }} has been down for more than 1 minute.'
                                }
                            },
                            {
                                'alert': 'DatabaseDown',
                                'expr': 'up{job="database"} == 0',
                                'for': '1m',
                                'labels': {
                                    'severity': 'critical'
                                },
                                'annotations': {
                                    'summary': 'Database is down',
                                    'description': 'Database {{ $labels.instance }} has been down for more than 1 minute.'
                                }
                            },
                            {
                                'alert': 'VirtualMinDown',
                                'expr': 'up{job="virtualmin"} == 0',
                                'for': '1m',
                                'labels': {
                                    'severity': 'critical'
                                },
                                'annotations': {
                                    'summary': 'VirtualMin is down',
                                    'description': 'VirtualMin {{ $labels.instance }} has been down for more than 1 minute.'
                                }
                            }
                        ]
                    }
                ]
            }
            
            # Escribir archivo de reglas
            with open(rules_file, 'w') as f:
                yaml.dump(alert_rules, f)
            
            logger.info(f"Reglas de alerta de Prometheus creadas: {rules_file}")
            return True
        except Exception as e:
            logger.error(f"Error al crear reglas de alerta de Prometheus: {e}")
            return False
    
    def create_grafana_dashboards(self):
        """Crear dashboards de Grafana"""
        try:
            dashboards = [
                {
                    'name': 'Virtualmin Enterprise Overview',
                    'uid': 'virtualmin-overview',
                    'dashboard': {
                        'id': None,
                        'title': 'Virtualmin Enterprise Overview',
                        'tags': ['virtualmin', 'overview'],
                        'timezone': 'browser',
                        'panels': [
                            {
                                'id': 1,
                                'title': 'System Status',
                                'type': 'stat',
                                'targets': [
                                    {
                                        'expr': 'up',
                                        'refId': 'A'
                                    }
                                ],
                                'gridPos': {
                                    'h': 8,
                                    'w': 12,
                                    'x': 0,
                                    'y': 0
                                }
                            },
                            {
                                'id': 2,
                                'title': 'CPU Usage',
                                'type': 'graph',
                                'targets': [
                                    {
                                        'expr': '100 - (avg by(instance) (irate(node_cpu_seconds_total{{mode="idle"}}[5m])) * 100)',
                                        'refId': 'A'
                                    }
                                ],
                                'gridPos': {
                                    'h': 8,
                                    'w': 12,
                                    'x': 12,
                                    'y': 0
                                }
                            },
                            {
                                'id': 3,
                                'title': 'Memory Usage',
                                'type': 'graph',
                                'targets': [
                                    {
                                        'expr': '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100',
                                        'refId': 'A'
                                    }
                                ],
                                'gridPos': {
                                    'h': 8,
                                    'w': 12,
                                    'x': 0,
                                    'y': 8
                                }
                            },
                            {
                                'id': 4,
                                'title': 'Disk Usage',
                                'type': 'graph',
                                'targets': [
                                    {
                                        'expr': '(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100',
                                        'refId': 'A'
                                    }
                                ],
                                'gridPos': {
                                    'h': 8,
                                    'w': 12,
                                    'x': 12,
                                    'y': 8
                                }
                            }
                        ],
                        'time': {
                            'from': 'now-1h',
                            'to': 'now'
                        },
                        'refresh': '30s'
                    }
                },
                {
                    'name': 'Web Server Metrics',
                    'uid': 'web-server-metrics',
                    'dashboard': {
                        'id': None,
                        'title': 'Web Server Metrics',
                        'tags': ['web', 'server'],
                        'timezone': 'browser',
                        'panels': [
                            {
                                'id': 1,
                                'title': 'Request Rate',
                                'type': 'graph',
                                'targets': [
                                    {
                                        'expr': 'rate(http_requests_total[5m])',
                                        'refId': 'A'
                                    }
                                ],
                                'gridPos': {
                                    'h': 8,
                                    'w': 12,
                                    'x': 0,
                                    'y': 0
                                }
                            },
                            {
                                'id': 2,
                                'title': 'Response Time',
                                'type': 'graph',
                                'targets': [
                                    {
                                        'expr': 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))',
                                        'refId': 'A'
                                    }
                                ],
                                'gridPos': {
                                    'h': 8,
                                    'w': 12,
                                    'x': 12,
                                    'y': 0
                                }
                            }
                        ],
                        'time': {
                            'from': 'now-1h',
                            'to': 'now'
                        },
                        'refresh': '30s'
                    }
                }
            ]
            
            # Guardar dashboards
            for dashboard in dashboards:
                dashboard_file = os.path.join(self.config['dashboards']['path'], f"{dashboard['uid']}.json")
                
                with open(dashboard_file, 'w') as f:
                    json.dump(dashboard['dashboard'], f, indent=2)
                
                # Guardar en base de datos
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                cursor.execute('''
                    INSERT OR REPLACE INTO dashboards (dashboard_name, dashboard_uid, dashboard_json)
                    VALUES (?, ?, ?)
                ''', (
                    dashboard['name'],
                    dashboard['uid'],
                    json.dumps(dashboard['dashboard'])
                ))
                
                conn.commit()
                conn.close()
            
            logger.info("Dashboards de Grafana creados")
            return True
        except Exception as e:
            logger.error(f"Error al crear dashboards de Grafana: {e}")
            return False
    
    def start_prometheus(self):
        """Iniciar Prometheus"""
        try:
            # Verificar si Prometheus ya está en ejecución
            if self.is_service_running('prometheus'):
                logger.info("Prometheus ya está en ejecución")
                return True
            
            # Iniciar Prometheus
            prometheus_bin = os.path.join(self.prometheus_dir, 'prometheus')
            config_file = os.path.join(self.prometheus_dir, 'prometheus.yml')
            data_dir = os.path.join(self.prometheus_dir, 'data')
            
            cmd = [
                prometheus_bin,
                '--config.file', config_file,
                '--storage.tsdb.path', data_dir,
                '--web.console.libraries', os.path.join(self.prometheus_dir, 'console_libraries'),
                '--web.console.templates', os.path.join(self.prometheus_dir, 'consoles'),
                '--storage.tsdb.retention.time', self.config['prometheus']['retention'],
                '--web.enable-lifecycle'
            ]
            
            logger.info("Iniciando Prometheus")
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Esperar a que Prometheus se inicie
            time.sleep(5)
            
            # Verificar si Prometheus se inició correctamente
            if process.poll() is None:
                self.service_status['prometheus'] = {
                    'process': process,
                    'pid': process.pid,
                    'port': self.config['prometheus']['port'],
                    'status': 'running'
                }
                
                logger.info(f"Prometheus iniciado exitosamente en el puerto {self.config['prometheus']['port']}")
                return True
            else:
                stdout, stderr = process.communicate()
                logger.error(f"Error al iniciar Prometheus: {stderr}")
                return False
        except Exception as e:
            logger.error(f"Error al iniciar Prometheus: {e}")
            return False
    
    def start_grafana(self):
        """Iniciar Grafana"""
        try:
            # Verificar si Grafana ya está en ejecución
            if self.is_service_running('grafana'):
                logger.info("Grafana ya está en ejecución")
                return True
            
            # Iniciar Grafana
            grafana_bin = os.path.join(self.grafana_dir, 'bin', 'grafana-server')
            config_file = os.path.join(self.grafana_dir, 'conf', 'defaults.ini')
            
            cmd = [
                grafana_bin,
                '--config', config_file,
                '--homepath', self.grafana_dir
            ]
            
            logger.info("Iniciando Grafana")
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Esperar a que Grafana se inicie
            time.sleep(10)
            
            # Verificar si Grafana se inició correctamente
            if process.poll() is None:
                self.service_status['grafana'] = {
                    'process': process,
                    'pid': process.pid,
                    'port': self.config['grafana']['port'],
                    'status': 'running'
                }
                
                logger.info(f"Grafana iniciado exitosamente en el puerto {self.config['grafana']['port']}")
                return True
            else:
                stdout, stderr = process.communicate()
                logger.error(f"Error al iniciar Grafana: {stderr}")
                return False
        except Exception as e:
            logger.error(f"Error al iniciar Grafana: {e}")
            return False
    
    def start_alertmanager(self):
        """Iniciar Alertmanager"""
        try:
            # Verificar si Alertmanager ya está en ejecución
            if self.is_service_running('alertmanager'):
                logger.info("Alertmanager ya está en ejecución")
                return True
            
            # Iniciar Alertmanager
            alertmanager_bin = os.path.join(self.alertmanager_dir, 'alertmanager')
            config_file = os.path.join(self.alertmanager_dir, 'alertmanager.yml')
            data_dir = os.path.join(self.alertmanager_dir, 'data')
            
            cmd = [
                alertmanager_bin,
                '--config.file', config_file,
                '--storage.path', data_dir
            ]
            
            logger.info("Iniciando Alertmanager")
            process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            
            # Esperar a que Alertmanager se inicie
            time.sleep(5)
            
            # Verificar si Alertmanager se inició correctamente
            if process.poll() is None:
                self.service_status['alertmanager'] = {
                    'process': process,
                    'pid': process.pid,
                    'port': self.config['alertmanager']['port'],
                    'status': 'running'
                }
                
                logger.info(f"Alertmanager iniciado exitosamente en el puerto {self.config['alertmanager']['port']}")
                return True
            else:
                stdout, stderr = process.communicate()
                logger.error(f"Error al iniciar Alertmanager: {stderr}")
                return False
        except Exception as e:
            logger.error(f"Error al iniciar Alertmanager: {e}")
            return False
    
    def start_node_exporter(self):
        """Iniciar Node Exporter"""
        try:
            # Verificar si Node Exporter ya está en ejecución
            if self.is_service_running('node_exporter'):
                logger.info("Node Exporter ya está en ejecución")
                return True
            
            # Iniciar Node Exporter usando systemd
            subprocess.run(['systemctl', 'start', 'node_exporter'], check=True)
            
            # Esperar a que Node Exporter se inicie
            time.sleep(5)
            
            # Verificar si Node Exporter se inició correctamente
            result = subprocess.run(['systemctl', 'is-active', 'node_exporter'], capture_output=True, text=True)
            
            if result.returncode == 0:
                self.service_status['node_exporter'] = {
                    'port': self.config['node_exporter']['port'],
                    'status': 'running'
                }
                
                logger.info(f"Node Exporter iniciado exitosamente en el puerto {self.config['node_exporter']['port']}")
                return True
            else:
                logger.error(f"Error al iniciar Node Exporter: {result.stderr}")
                return False
        except Exception as e:
            logger.error(f"Error al iniciar Node Exporter: {e}")
            return False
    
    def is_service_running(self, service_name):
        """Verificar si un servicio está en ejecución"""
        try:
            if service_name == 'node_exporter':
                # Verificar usando systemd
                result = subprocess.run(['systemctl', 'is-active', service_name], capture_output=True, text=True)
                return result.returncode == 0
            elif service_name in self.service_status:
                # Verificar usando proceso
                process_info = self.service_status[service_name]
                if 'process' in process_info:
                    return process_info['process'].poll() is None
            
            return False
        except Exception as e:
            logger.error(f"Error al verificar estado del servicio {service_name}: {e}")
            return False
    
    def stop_service(self, service_name):
        """Detener un servicio"""
        try:
            if service_name == 'node_exporter':
                # Detener usando systemd
                subprocess.run(['systemctl', 'stop', service_name], check=True)
            elif service_name in self.service_status:
                # Detener usando proceso
                process_info = self.service_status[service_name]
                if 'process' in process_info:
                    process_info['process'].terminate()
                    process_info['process'].wait(timeout=10)
                
                del self.service_status[service_name]
            
            logger.info(f"Servicio {service_name} detenido")
            return True
        except Exception as e:
            logger.error(f"Error al detener servicio {service_name}: {e}")
            return False
    
    def install_all_components(self):
        """Instalar todos los componentes"""
        components_installed = []
        
        if self.install_prometheus():
            components_installed.append('prometheus')
        
        if self.install_grafana():
            components_installed.append('grafana')
        
        if self.install_alertmanager():
            components_installed.append('alertmanager')
        
        if self.install_node_exporter():
            components_installed.append('node_exporter')
        
        # Crear reglas de alerta
        self.create_prometheus_alert_rules()
        
        # Crear dashboards
        self.create_grafana_dashboards()
        
        return components_installed
    
    def start_all_services(self):
        """Iniciar todos los servicios"""
        services_started = []
        
        if self.start_node_exporter():
            services_started.append('node_exporter')
        
        if self.start_prometheus():
            services_started.append('prometheus')
        
        if self.start_alertmanager():
            services_started.append('alertmanager')
        
        if self.start_grafana():
            services_started.append('grafana')
        
        return services_started
    
    def stop_all_services(self):
        """Detener todos los servicios"""
        services_stopped = []
        
        services_to_stop = ['grafana', 'alertmanager', 'prometheus', 'node_exporter']
        
        for service in services_to_stop:
            if self.stop_service(service):
                services_stopped.append(service)
        
        return services_stopped
    
    def get_service_status(self):
        """Obtener estado de todos los servicios"""
        status = {}
        
        for service_name, service_info in self.service_status.items():
            if 'pid' in service_info:
                try:
                    # Verificar si el proceso todavía existe
                    process = psutil.Process(service_info['pid'])
                    if process.is_running():
                        status[service_name] = {
                            'status': 'running',
                            'pid': service_info['pid'],
                            'port': service_info.get('port', 0)
                        }
                    else:
                        status[service_name] = {
                            'status': 'stopped',
                            'pid': service_info['pid'],
                            'port': service_info.get('port', 0)
                        }
                except psutil.NoSuchProcess:
                    status[service_name] = {
                        'status': 'stopped',
                        'pid': service_info['pid'],
                        'port': service_info.get('port', 0)
                    }
            else:
                if service_name == 'node_exporter':
                    # Verificar usando systemd
                    result = subprocess.run(['systemctl', 'is-active', service_name], capture_output=True, text=True)
                    status[service_name] = {
                        'status': result.stdout.strip(),
                        'port': self.config[service_name]['port']
                    }
        
        return status
    
    def check_metrics_availability(self):
        """Verificar disponibilidad de métricas"""
        try:
            # Verificar métricas de Prometheus
            prometheus_url = f"http://localhost:{self.config['prometheus']['port']}/api/v1/query"
            
            # Consultar métricas de ejemplo
            response = requests.get(f"{prometheus_url}?query=up", timeout=5)
            
            if response.status_code == 200:
                data = response.json()
                if data['status'] == 'success':
                    metrics_count = len(data['data']['result'])
                    return {
                        'available': True,
                        'metrics_count': metrics_count,
                        'message': f"Métricas disponibles: {metrics_count}"
                    }
            
            return {
                'available': False,
                'metrics_count': 0,
                'message': "No se pudieron obtener métricas de Prometheus"
            }
        except Exception as e:
            logger.error(f"Error al verificar disponibilidad de métricas: {e}")
            return {
                'available': False,
                'metrics_count': 0,
                'message': f"Error: {str(e)}"
            }
    
    def generate_integration_report(self):
        """Generar reporte de integración"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.config['dashboards']['path'], f"integration_report_{timestamp}.html")
            
            # Obtener estado de los servicios
            service_status = self.get_service_status()
            
            # Verificar disponibilidad de métricas
            metrics_status = self.check_metrics_availability()
            
            # Contenido HTML
            html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Integración de Prometheus y Grafana - Virtualmin Enterprise</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }}
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        }}
        .header {{
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 1px solid #ddd;
        }}
        .summary {{
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
        }}
        .summary-item {{
            text-align: center;
            padding: 15px;
            border-radius: 8px;
            min-width: 120px;
        }}
        .summary-item.running {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .summary-item.stopped {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .summary-item.total {{
            background-color: #e3f2fd;
            color: #1565c0;
        }}
        .summary-number {{
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .summary-label {{
            font-size: 14px;
        }}
        .service-section {{
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ddd;
        }}
        .service-title {{
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }}
        .service-status {{
            margin-bottom: 15px;
            padding: 8px 12px;
            border-radius: 4px;
            font-weight: bold;
            text-align: center;
        }}
        .service-status.running {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .service-status.stopped {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .service-details {{
            margin-top: 15px;
        }}
        .metrics-section {{
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ddd;
        }}
        .metrics-title {{
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }}
        .metrics-status {{
            margin-bottom: 15px;
            padding: 8px 12px;
            border-radius: 4px;
            font-weight: bold;
            text-align: center;
        }}
        .metrics-status.available {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .metrics-status.unavailable {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .footer {{
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            color: #666;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Reporte de Integración de Prometheus y Grafana</h1>
            <p>Virtualmin Enterprise - Sistema de Métricas y Alertas Centralizadas</p>
        </div>
        
        <div class="summary">
            <div class="summary-item total">
                <div class="summary-number">{len(service_status)}</div>
                <div class="summary-label">Total</div>
            </div>
            <div class="summary-item running">
                <div class="summary-number">{sum(1 for s in service_status.values() if s['status'] == 'running')}</div>
                <div class="summary-label">En Ejecución</div>
            </div>
            <div class="summary-item stopped">
                <div class="summary-number">{sum(1 for s in service_status.values() if s['status'] == 'stopped')}</div>
                <div class="summary-label">Detenidos</div>
            </div>
        </div>
        
        <div class="service-section">
            <div class="service-title">Estado de los Servicios</div>
"""
            
            # Añadir estado de los servicios
            for service_name, service_info in service_status.items():
                status_class = service_info['status']
                status_text = "En Ejecución" if service_info['status'] == 'running' else "Detenido"
                
                html_content += f"""
            <div class="service-status {status_class}">
                {service_name.title()}: {status_text}
            </div>
            <div class="service-details">
                <p><strong>PID:</strong> {service_info.get('pid', 'N/A')}</p>
                <p><strong>Puerto:</strong> {service_info.get('port', 'N/A')}</p>
            </div>
"""
            
            html_content += """
        </div>
        
        <div class="metrics-section">
            <div class="metrics-title">Disponibilidad de Métricas</div>
"""
            
            # Añadir estado de las métricas
            metrics_status_class = 'available' if metrics_status['available'] else 'unavailable'
            metrics_status_text = "Disponibles" if metrics_status['available'] else "No Disponibles"
            
            html_content += f"""
            <div class="metrics-status {metrics_status_class}">
                {metrics_status_text}: {metrics_status['message']}
            </div>
            <div class="service-details">
                <p><strong>Cantidad de Métricas:</strong> {metrics_status['metrics_count']}</p>
            </div>
"""
            
            html_content += """
        </div>
        
        <div class="service-section">
            <div class="service-title">Enlaces de Acceso</div>
            <div class="service-details">
                <p><strong>Prometheus:</strong> <a href="http://localhost:{0}">http://localhost:{0}</a></p>
                <p><strong>Grafana:</strong> <a href="http://localhost:{1}">http://localhost:{1}</a></p>
                <p><strong>Alertmanager:</strong> <a href="http://localhost:{2}">http://localhost:{2}</a></p>
                <p><strong>Node Exporter:</strong> <a href="http://localhost:{3}">http://localhost:{3}</a></p>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>Reporte generado por Virtualmin Enterprise - Sistema de Métricas y Alertas Centralizadas</p>
        <p>Fecha de generación: """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """</p>
    </div>
</body>
</html>
""".format(
                self.config['prometheus']['port'],
                self.config['grafana']['port'],
                self.config['alertmanager']['port'],
                self.config['node_exporter']['port']
            )
            
            # Escribir archivo HTML
            with open(report_file, 'w') as f:
                f.write(html_content)
            
            logger.info(f"Reporte de integración generado: {report_file}")
            return report_file
        except Exception as e:
            logger.error(f"Error al generar reporte de integración: {e}")
            return None

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de Integración de Prometheus y Grafana para Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/monitoring/prometheus_grafana_config.json')
    parser.add_argument('--install', action='store_true', help='Instalar todos los componentes')
    parser.add_argument('--start', action='store_true', help='Iniciar todos los servicios')
    parser.add_argument('--stop', action='store_true', help='Detener todos los servicios')
    parser.add_argument('--status', action='store_true', help='Mostrar estado de los servicios')
    parser.add_argument('--metrics', action='store_true', help='Verificar disponibilidad de métricas')
    parser.add_argument('--report', action='store_true', help='Generar reporte de integración')
    parser.add_argument('--service', help='Iniciar/detener un servicio específico')
    parser.add_argument('--action', choices=['start', 'stop'], help='Acción a realizar en el servicio')
    
    args = parser.parse_args()
    
    # Inicializar sistema
    monitoring_system = PrometheusGrafanaIntegration(args.config)
    
    if args.install:
        # Instalar componentes
        components = monitoring_system.install_all_components()
        print(f"Componentes instalados: {', '.join(components)}")
    elif args.start:
        # Iniciar servicios
        services = monitoring_system.start_all_services()
        print(f"Servicios iniciados: {', '.join(services)}")
    elif args.stop:
        # Detener servicios
        services = monitoring_system.stop_all_services()
        print(f"Servicios detenidos: {', '.join(services)}")
    elif args.service and args.action:
        # Realizar acción en un servicio específico
        if args.action == 'start':
            if args.service == 'prometheus':
                success = monitoring_system.start_prometheus()
            elif args.service == 'grafana':
                success = monitoring_system.start_grafana()
            elif args.service == 'alertmanager':
                success = monitoring_system.start_alertmanager()
            elif args.service == 'node_exporter':
                success = monitoring_system.start_node_exporter()
            else:
                success = False
                print(f"Servicio no soportado: {args.service}")
                sys.exit(1)
        elif args.action == 'stop':
            if args.service == 'node_exporter':
                success = monitoring_system.stop_service('node_exporter')
            else:
                success = monitoring_system.stop_service(args.service)
        else:
            success = False
        
        if success:
            print(f"Servicio {args.service} {args.action}ed")
        else:
            print(f"Error al {args.action} servicio {args.service}")
            sys.exit(1)
    elif args.status:
        # Mostrar estado de los servicios
        status = monitoring_system.get_service_status()
        
        print("Estado de los servicios:")
        for service_name, service_info in status.items():
            print(f"  - {service_name}: {service_info['status']} (PID: {service_info.get('pid', 'N/A')}, Puerto: {service_info.get('port', 'N/A')})")
    elif args.metrics:
        # Verificar disponibilidad de métricas
        metrics_status = monitoring_system.check_metrics_availability()
        
        if metrics_status['available']:
            print(f"Métricas disponibles: {metrics_status['metrics_count']}")
        else:
            print(f"Métricas no disponibles: {metrics_status['message']}")
            sys.exit(1)
    elif args.report:
        # Generar reporte
        report_file = monitoring_system.generate_integration_report()
        
        if report_file:
            print(f"Reporte de integración generado: {report_file}")
        else:
            print("Error al generar reporte de integración")
            sys.exit(1)
    else:
        # Instalar y iniciar todo por defecto
        components = monitoring_system.install_all_components()
        print(f"Componentes instalados: {', '.join(components)}")
        
        services = monitoring_system.start_all_services()
        print(f"Servicios iniciados: {', '.join(services)}")
        
        report_file = monitoring_system.generate_integration_report()
        if report_file:
            print(f"Reporte de integración generado: {report_file}")

if __name__ == "__main__":
    main()