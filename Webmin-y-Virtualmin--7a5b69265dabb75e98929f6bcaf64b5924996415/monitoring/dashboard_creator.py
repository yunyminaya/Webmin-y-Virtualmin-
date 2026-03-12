#!/usr/bin/env python3

# Sistema de Creación de Dashboards Personalizados para Seguridad, Rendimiento y Disponibilidad
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
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/dashboard_creator.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class DashboardCreator:
    def __init__(self, config_file=None):
        """Inicializar el sistema de creación de dashboards"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/monitoring/dashboards.db')
        self.dashboards_dir = self.config.get('dashboards', {}).get('path', '/opt/grafana/dashboards')
        self.templates_dir = self.config.get('dashboards', {}).get('templates', '/opt/virtualmin-enterprise/monitoring/dashboard_templates')
        self.grafana_api_url = f"http://localhost:{self.config.get('grafana', {}).get('port', 3000)}/api"
        self.grafana_credentials = (
            self.config.get('grafana', {}).get('admin_user', 'admin'),
            self.config.get('grafana', {}).get('admin_password', 'admin')
        )
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
        
        # Cargar plantillas de dashboards
        self.load_dashboard_templates()
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/monitoring/dashboards.db"
            },
            "dashboards": {
                "path": "/opt/grafana/dashboards",
                "templates": "/opt/virtualmin-enterprise/monitoring/dashboard_templates",
                "auto_import": True,
                "update_interval": 3600
            },
            "grafana": {
                "port": 3000,
                "admin_user": "admin",
                "admin_password": "admin"
            },
            "prometheus": {
                "port": 9090,
                "url": "http://localhost:9090"
            },
            "categories": {
                "security": {
                    "name": "Seguridad",
                    "icon": "shield",
                    "color": "#E74C3C"
                },
                "performance": {
                    "name": "Rendimiento",
                    "icon": "tachometer",
                    "color": "#3498DB"
                },
                "availability": {
                    "name": "Disponibilidad",
                    "icon": "check-circle",
                    "color": "#2ECC71"
                },
                "infrastructure": {
                    "name": "Infraestructura",
                    "icon": "server",
                    "color": "#9B59B6"
                },
                "applications": {
                    "name": "Aplicaciones",
                    "icon": "code",
                    "color": "#F39C12"
                },
                "network": {
                    "name": "Red",
                    "icon": "globe",
                    "color": "#1ABC9C"
                }
            },
            "widgets": {
                "stat": {
                    "type": "stat",
                    "default_height": 8,
                    "default_width": 6
                },
                "graph": {
                    "type": "graph",
                    "default_height": 8,
                    "default_width": 12
                },
                "table": {
                    "type": "table",
                    "default_height": 8,
                    "default_width": 12
                },
                "heatmap": {
                    "type": "heatmap",
                    "default_height": 8,
                    "default_width": 12
                },
                "gauge": {
                    "type": "gauge",
                    "default_height": 8,
                    "default_width": 8
                },
                "piechart": {
                    "type": "piechart",
                    "default_height": 8,
                    "default_width": 8
                }
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
            self.dashboards_dir,
            self.templates_dir,
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
            
            # Crear tabla de dashboards
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS dashboards (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    dashboard_uid TEXT UNIQUE NOT NULL,
                    dashboard_name TEXT NOT NULL,
                    dashboard_title TEXT NOT NULL,
                    category TEXT,
                    tags TEXT,
                    dashboard_json TEXT,
                    grafana_id INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de widgets
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS widgets (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    widget_id TEXT UNIQUE NOT NULL,
                    widget_name TEXT NOT NULL,
                    widget_type TEXT NOT NULL,
                    widget_config TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de plantillas de dashboards
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS dashboard_templates (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    template_name TEXT UNIQUE NOT NULL,
                    template_title TEXT NOT NULL,
                    category TEXT,
                    description TEXT,
                    template_json TEXT,
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
    
    def load_dashboard_templates(self):
        """Cargar plantillas de dashboards desde archivos"""
        try:
            self.templates = {}
            
            # Cargar plantillas predefinidas
            self.templates['security_overview'] = self.create_security_dashboard_template()
            self.templates['performance_overview'] = self.create_performance_dashboard_template()
            self.templates['availability_overview'] = self.create_availability_dashboard_template()
            self.templates['infrastructure_overview'] = self.create_infrastructure_dashboard_template()
            self.templates['application_overview'] = self.create_application_dashboard_template()
            self.templates['network_overview'] = self.create_network_dashboard_template()
            
            # Guardar plantillas en la base de datos si no existen
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            for template_name, template_data in self.templates.items():
                cursor.execute('''
                    SELECT COUNT(*) FROM dashboard_templates WHERE template_name = ?
                ''', (template_name,))
                
                if cursor.fetchone()[0] == 0:
                    cursor.execute('''
                        INSERT INTO dashboard_templates (template_name, template_title, category, description, template_json)
                        VALUES (?, ?, ?, ?, ?)
                    ''', (
                        template_name,
                        template_data['title'],
                        template_data['category'],
                        template_data['description'],
                        json.dumps(template_data['dashboard'])
                    ))
            
            conn.commit()
            conn.close()
            
            logger.info("Plantillas de dashboards cargadas")
            return True
        except Exception as e:
            logger.error(f"Error al cargar plantillas de dashboards: {e}")
            return False
    
    def create_security_dashboard_template(self):
        """Crear plantilla de dashboard de seguridad"""
        return {
            'title': 'Panel de Seguridad',
            'category': 'security',
            'description': 'Dashboard para monitorear la seguridad del sistema',
            'dashboard': {
                'id': None,
                'title': 'Panel de Seguridad',
                'tags': ['security', 'virtualmin'],
                'timezone': 'browser',
                'panels': [
                    {
                        'id': None,
                        'title': 'Estado de Seguridad',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'sum(up{job=~"virtualmin|webmin|firewall"}) - sum(up{job=~"virtualmin|webmin|firewall"} == 0)',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 0
                        },
                        'options': {
                            'colorMode': 'value',
                            'graphMode': 'area',
                            'justifyMode': 'auto',
                            'orientation': 'auto',
                            'reduceOptions': {
                                'values': False,
                                'calcs': [
                                    'lastNotNull'
                                ],
                                'fields': ''
                            },
                            'textMode': 'auto'
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Crítico'
                                            },
                                            '1': {
                                                'color': 'yellow',
                                                'index': 1,
                                                'text': 'Advertencia'
                                            },
                                            '2': {
                                                'color': 'green',
                                                'index': 2,
                                                'text': 'Seguro'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ],
                                'thresholds': {
                                    'steps': [
                                        {
                                            'color': 'green',
                                            'value': None
                                        },
                                        {
                                            'color': 'red',
                                            'value': 80
                                        }
                                    ]
                                },
                                'unit': 'short'
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Intentos de Inicio de Sesión Fallidos',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(login_failed_total[5m])',
                                'refId': 'A',
                                'legendFormat': 'Intentos fallidos'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 0
                        },
                        'yAxes': [
                            {
                                'label': 'Intentos por minuto',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Alertas de Seguridad',
                        'type': 'table',
                        'targets': [
                            {
                                'expr': 'ALERTS{alertname=~".*Security.*"}',
                                'refId': 'A',
                                'format': 'table',
                                'instant': True
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 24,
                            'x': 0,
                            'y': 8
                        },
                        'transformations': [
                            {
                                'id': 'filterFieldsByName',
                                'options': {
                                    'include': {
                                        'names': [
                                            'alertname',
                                            'severity',
                                            'instance',
                                            'summary'
                                        ]
                                    }
                                }
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Estado del Firewall',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'up{job="firewall"}',
                                'refId': 'A',
                                'legendFormat': 'Firewall'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 0,
                            'y': 16
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Caído'
                                            },
                                            '1': {
                                                'color': 'green',
                                                'index': 1,
                                                'text': 'Activo'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ]
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Vulnerabilidades Detectadas',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'sum(vulnerabilities_detected)',
                                'refId': 'A',
                                'legendFormat': 'Vulnerabilidades'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 6,
                            'y': 16
                        },
                        'fieldConfig': {
                            'defaults': {
                                'thresholds': {
                                    'steps': [
                                        {
                                            'color': 'green',
                                            'value': None
                                        },
                                        {
                                            'color': 'yellow',
                                            'value': 1
                                        },
                                        {
                                            'color': 'red',
                                            'value': 5
                                        }
                                    ]
                                }
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Escaneos de Seguridad',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'increase(security_scan_completed_total[1h])',
                                'refId': 'A',
                                'legendFormat': 'Escaneos completados'
                            },
                            {
                                'expr': 'increase(security_scan_failed_total[1h])',
                                'refId': 'B',
                                'legendFormat': 'Escaneos fallidos'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'label': 'Escaneos por hora',
                                'show': True
                            }
                        ]
                    }
                ],
                'time': {
                    'from': 'now-1h',
                    'to': 'now'
                },
                'refresh': '30s'
            }
        }
    
    def create_performance_dashboard_template(self):
        """Crear plantilla de dashboard de rendimiento"""
        return {
            'title': 'Panel de Rendimiento',
            'category': 'performance',
            'description': 'Dashboard para monitorear el rendimiento del sistema',
            'dashboard': {
                'id': None,
                'title': 'Panel de Rendimiento',
                'tags': ['performance', 'virtualmin'],
                'timezone': 'browser',
                'panels': [
                    {
                        'id': None,
                        'title': 'Uso de CPU',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': '100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 0
                        },
                        'yAxes': [
                            {
                                'max': 100,
                                'min': 0,
                                'label': 'Porcentaje (%)',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Uso de Memoria',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 0
                        },
                        'yAxes': [
                            {
                                'max': 100,
                                'min': 0,
                                'label': 'Porcentaje (%)',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Uso de Disco',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': '(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100',
                                'refId': 'A',
                                'legendFormat': '{{instance}} - {{mountpoint}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'max': 100,
                                'min': 0,
                                'label': 'Porcentaje (%)',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Tráfico de Red',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(node_network_receive_bytes_total[5m])',
                                'refId': 'A',
                                'legendFormat': 'Entrada - {{instance}}'
                            },
                            {
                                'expr': 'rate(node_network_transmit_bytes_total[5m])',
                                'refId': 'B',
                                'legendFormat': 'Salida - {{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'label': 'Bytes por segundo',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Tiempo de Respuesta del Servidor Web',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))',
                                'refId': 'A',
                                'legendFormat': 'Percentil 95'
                            },
                            {
                                'expr': 'histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))',
                                'refId': 'B',
                                'legendFormat': 'Percentil 50'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'label': 'Segundos',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Tasa de Solicitudes del Servidor Web',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(http_requests_total[5m])',
                                'refId': 'A',
                                'legendFormat': '{{method}} - {{status}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'label': 'Solicitudes por segundo',
                                'show': True
                            }
                        ]
                    }
                ],
                'time': {
                    'from': 'now-1h',
                    'to': 'now'
                },
                'refresh': '30s'
            }
        }
    
    def create_availability_dashboard_template(self):
        """Crear plantilla de dashboard de disponibilidad"""
        return {
            'title': 'Panel de Disponibilidad',
            'category': 'availability',
            'description': 'Dashboard para monitorear la disponibilidad de servicios',
            'dashboard': {
                'id': None,
                'title': 'Panel de Disponibilidad',
                'tags': ['availability', 'virtualmin'],
                'timezone': 'browser',
                'panels': [
                    {
                        'id': None,
                        'title': 'Estado de Servicios',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'up{job="web_server"}',
                                'refId': 'A',
                                'legendFormat': 'Servidor Web'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 0,
                            'y': 0
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Caído'
                                            },
                                            '1': {
                                                'color': 'green',
                                                'index': 1,
                                                'text': 'Activo'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ]
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Estado de Base de Datos',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'up{job="database"}',
                                'refId': 'A',
                                'legendFormat': 'Base de Datos'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 6,
                            'y': 0
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Caída'
                                            },
                                            '1': {
                                                'color': 'green',
                                                'index': 1,
                                                'text': 'Activa'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ]
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Estado de Virtualmin',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'up{job="virtualmin"}',
                                'refId': 'A',
                                'legendFormat': 'Virtualmin'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 12,
                            'y': 0
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Caído'
                                            },
                                            '1': {
                                                'color': 'green',
                                                'index': 1,
                                                'text': 'Activo'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ]
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Tiempo de Actividad',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'time() - node_boot_time_seconds',
                                'refId': 'A',
                                'legendFormat': 'Tiempo de actividad'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 18,
                            'y': 0
                        },
                        'fieldConfig': {
                            'defaults': {
                                'unit': 'd',
                                'thresholds': {
                                    'steps': [
                                        {
                                            'color': 'green',
                                            'value': None
                                        },
                                        {
                                            'color': 'red',
                                            'value': 1
                                        }
                                    ]
                                }
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Historial de Disponibilidad',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'up{job="web_server"}',
                                'refId': 'A',
                                'legendFormat': 'Servidor Web'
                            },
                            {
                                'expr': 'up{job="database"}',
                                'refId': 'B',
                                'legendFormat': 'Base de Datos'
                            },
                            {
                                'expr': 'up{job="virtualmin"}',
                                'refId': 'C',
                                'legendFormat': 'Virtualmin'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 24,
                            'x': 0,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'max': 1.1,
                                'min': -0.1,
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Tiempo de Respuesta',
                        'type': 'heatmap',
                        'targets': [
                            {
                                'expr': 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))',
                                'refId': 'A',
                                'legendFormat': 'Percentil 95'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'label': 'Segundos',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Tasa de Errores',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100',
                                'refId': 'A',
                                'legendFormat': 'Tasa de errores 5xx'
                            },
                            {
                                'expr': 'rate(http_requests_total{status=~"4.."}[5m]) / rate(http_requests_total[5m]) * 100',
                                'refId': 'B',
                                'legendFormat': 'Tasa de errores 4xx'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'max': 100,
                                'min': 0,
                                'label': 'Porcentaje (%)',
                                'show': True
                            }
                        ]
                    }
                ],
                'time': {
                    'from': 'now-24h',
                    'to': 'now'
                },
                'refresh': '30s'
            }
        }
    
    def create_infrastructure_dashboard_template(self):
        """Crear plantilla de dashboard de infraestructura"""
        return {
            'title': 'Panel de Infraestructura',
            'category': 'infrastructure',
            'description': 'Dashboard para monitorear la infraestructura del sistema',
            'dashboard': {
                'id': None,
                'title': 'Panel de Infraestructura',
                'tags': ['infrastructure', 'virtualmin'],
                'timezone': 'browser',
                'panels': [
                    {
                        'id': None,
                        'title': 'Estado de los Servidores',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'up',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 0
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Caído'
                                            },
                                            '1': {
                                                'color': 'green',
                                                'index': 1,
                                                'text': 'Activo'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ]
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Número de Servidores',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'count(up)',
                                'refId': 'A',
                                'legendFormat': 'Total'
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
                        'id': None,
                        'title': 'Uso de CPU por Servidor',
                        'type': 'heatmap',
                        'targets': [
                            {
                                'expr': '100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 24,
                            'x': 0,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'max': 100,
                                'min': 0,
                                'label': 'Porcentaje (%)',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Uso de Memoria por Servidor',
                        'type': 'heatmap',
                        'targets': [
                            {
                                'expr': '(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 24,
                            'x': 0,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'max': 100,
                                'min': 0,
                                'label': 'Porcentaje (%)',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Uso de Disco por Servidor',
                        'type': 'table',
                        'targets': [
                            {
                                'expr': '(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100',
                                'refId': 'A',
                                'format': 'table',
                                'instant': True
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 24,
                            'x': 0,
                            'y': 24
                        },
                        'transformations': [
                            {
                                'id': 'filterFieldsByName',
                                'options': {
                                    'include': {
                                        'names': [
                                            'instance',
                                            'mountpoint',
                                            'Value'
                                        ]
                                    }
                                }
                            },
                            {
                                'id': 'organize',
                                'options': {
                                    'excludeByName': {
                                        'Time': true
                                    },
                                    'indexByName': {
                                        'instance': 0,
                                        'mountpoint': 1,
                                        'Value': 2
                                    },
                                    'renameByName': {
                                        'Value': 'Uso (%)'
                                    }
                                }
                            }
                        ]
                    }
                ],
                'time': {
                    'from': 'now-1h',
                    'to': 'now'
                },
                'refresh': '30s'
            }
        }
    
    def create_application_dashboard_template(self):
        """Crear plantilla de dashboard de aplicaciones"""
        return {
            'title': 'Panel de Aplicaciones',
            'category': 'applications',
            'description': 'Dashboard para monitorear las aplicaciones del sistema',
            'dashboard': {
                'id': None,
                'title': 'Panel de Aplicaciones',
                'tags': ['applications', 'virtualmin'],
                'timezone': 'browser',
                'panels': [
                    {
                        'id': None,
                        'title': 'Estado de Aplicaciones',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'up{job=~"apache|nginx|php|python"}',
                                'refId': 'A',
                                'legendFormat': '{{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 0
                        },
                        'fieldConfig': {
                            'defaults': {
                                'mappings': [
                                    {
                                        'options': {
                                            '0': {
                                                'color': 'red',
                                                'index': 0,
                                                'text': 'Caída'
                                            },
                                            '1': {
                                                'color': 'green',
                                                'index': 1,
                                                'text': 'Activa'
                                            }
                                        },
                                        'type': 'value'
                                    }
                                ]
                            }
                        }
                    },
                    {
                        'id': None,
                        'title': 'Procesos de Aplicaciones',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'count(process_running{name=~"apache|nginx|php-fpm|python"})',
                                'refId': 'A',
                                'legendFormat': 'Procesos'
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
                        'id': None,
                        'title': 'Uso de CPU por Aplicación',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'sum by (name) (rate(process_cpu_seconds_total[5m]))',
                                'refId': 'A',
                                'legendFormat': '{{name}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'label': 'Uso de CPU',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Uso de Memoria por Aplicación',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'sum by (name) (process_resident_memory_bytes)',
                                'refId': 'A',
                                'legendFormat': '{{name}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'label': 'Memoria Residente',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Conexiones por Aplicación',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'sum by (name) (process_num_connections)',
                                'refId': 'A',
                                'legendFormat': '{{name}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 24,
                            'x': 0,
                            'y': 16
                        },
                        'yAxes': [
                            {
                                'label': 'Número de Conexiones',
                                'show': True
                            }
                        ]
                    }
                ],
                'time': {
                    'from': 'now-1h',
                    'to': 'now'
                },
                'refresh': '30s'
            }
        }
    
    def create_network_dashboard_template(self):
        """Crear plantilla de dashboard de red"""
        return {
            'title': 'Panel de Red',
            'category': 'network',
            'description': 'Dashboard para monitorear la red del sistema',
            'dashboard': {
                'id': None,
                'title': 'Panel de Red',
                'tags': ['network', 'virtualmin'],
                'timezone': 'browser',
                'panels': [
                    {
                        'id': None,
                        'title': 'Tráfico de Red Entrante',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(node_network_receive_bytes_total[5m])',
                                'refId': 'A',
                                'legendFormat': '{{device}} - {{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 0
                        },
                        'yAxes': [
                            {
                                'label': 'Bytes por segundo',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Tráfico de Red Saliente',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(node_network_transmit_bytes_total[5m])',
                                'refId': 'A',
                                'legendFormat': '{{device}} - {{instance}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 0
                        },
                        'yAxes': [
                            {
                                'label': 'Bytes por segundo',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Paquetes Descartados',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(node_network_receive_drop_total[5m])',
                                'refId': 'A',
                                'legendFormat': 'Entrada - {{device}}'
                            },
                            {
                                'expr': 'rate(node_network_transmit_drop_total[5m])',
                                'refId': 'B',
                                'legendFormat': 'Salida - {{device}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 0,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'label': 'Paquetes por segundo',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Errores de Red',
                        'type': 'graph',
                        'targets': [
                            {
                                'expr': 'rate(node_network_receive_errs_total[5m])',
                                'refId': 'A',
                                'legendFormat': 'Entrada - {{device}}'
                            },
                            {
                                'expr': 'rate(node_network_transmit_errs_total[5m])',
                                'refId': 'B',
                                'legendFormat': 'Salida - {{device}}'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 8
                        },
                        'yAxes': [
                            {
                                'label': 'Paquetes por segundo',
                                'show': True
                            }
                        ]
                    },
                    {
                        'id': None,
                        'title': 'Conexiones de Red',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'node_netstat_Tcp_CurrEstab',
                                'refId': 'A',
                                'legendFormat': 'Conexiones TCP'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 0,
                            'y': 16
                        }
                    },
                    {
                        'id': None,
                        'title': 'Conexiones en Escucha',
                        'type': 'stat',
                        'targets': [
                            {
                                'expr': 'node_netstat_Tcp_Listen',
                                'refId': 'A',
                                'legendFormat': 'Conexiones en Escucha'
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 6,
                            'x': 6,
                            'y': 16
                        }
                    },
                    {
                        'id': None,
                        'title': 'Estado de Interfaces de Red',
                        'type': 'table',
                        'targets': [
                            {
                                'expr': 'node_network_up',
                                'refId': 'A',
                                'format': 'table',
                                'instant': True
                            }
                        ],
                        'gridPos': {
                            'h': 8,
                            'w': 12,
                            'x': 12,
                            'y': 16
                        },
                        'transformations': [
                            {
                                'id': 'filterFieldsByName',
                                'options': {
                                    'include': {
                                        'names': [
                                            'device',
                                            'Value'
                                        ]
                                    }
                                }
                            },
                            {
                                'id': 'organize',
                                'options': {
                                    'excludeByName': {
                                        'Time': true
                                    },
                                    'indexByName': {
                                        'device': 0,
                                        'Value': 1
                                    },
                                    'renameByName': {
                                        'Value': 'Estado'
                                    }
                                }
                            }
                        ]
                    }
                ],
                'time': {
                    'from': 'now-1h',
                    'to': 'now'
                },
                'refresh': '30s'
            }
        }
    
    def create_dashboard_from_template(self, template_name, dashboard_name=None, customizations=None):
        """Crear un dashboard a partir de una plantilla"""
        try:
            # Verificar si la plantilla existe
            if template_name not in self.templates:
                logger.error(f"Plantilla no encontrada: {template_name}")
                return {'success': False, 'error': f'Plantilla no encontrada: {template_name}'}
            
            # Obtener plantilla
            template = self.templates[template_name]
            
            # Crear copia del dashboard de la plantilla
            dashboard = template['dashboard'].copy()
            
            # Personalizar dashboard
            if dashboard_name:
                dashboard['title'] = dashboard_name
            else:
                dashboard['title'] = f"{template['title']} - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            
            # Generar UID único
            dashboard['uid'] = str(uuid.uuid4())
            
            # Aplicar personalizaciones
            if customizations:
                dashboard = self.apply_dashboard_customizations(dashboard, customizations)
            
            # Guardar dashboard en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO dashboards (dashboard_uid, dashboard_name, dashboard_title, category, tags, dashboard_json, grafana_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                dashboard['uid'],
                dashboard['title'],
                dashboard['title'],
                template['category'],
                json.dumps(template['tags']),
                json.dumps(dashboard),
                None  # grafana_id se actualizará después de importar a Grafana
            ))
            
            conn.commit()
            conn.close()
            
            # Guardar dashboard en archivo
            dashboard_file = os.path.join(self.dashboards_dir, f"{dashboard['uid']}.json")
            
            with open(dashboard_file, 'w') as f:
                json.dump(dashboard, f, indent=2)
            
            logger.info(f"Dashboard creado: {dashboard['title']} ({dashboard['uid']})")
            
            # Importar a Grafana si está configurado para importación automática
            grafana_id = None
            if self.config['dashboards']['auto_import']:
                grafana_id = self.import_dashboard_to_grafana(dashboard_file)
                
                if grafana_id:
                    # Actualizar ID de Grafana en la base de datos
                    conn = self.get_db_connection()
                    cursor = conn.cursor()
                    
                    cursor.execute('''
                        UPDATE dashboards SET grafana_id = ? WHERE dashboard_uid = ?
                    ''', (grafana_id, dashboard['uid']))
                    
                    conn.commit()
                    conn.close()
            
            return {
                'success': True,
                'dashboard_uid': dashboard['uid'],
                'dashboard_name': dashboard['title'],
                'dashboard_file': dashboard_file,
                'grafana_id': grafana_id
            }
        except Exception as e:
            logger.error(f"Error al crear dashboard desde plantilla: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def apply_dashboard_customizations(self, dashboard, customizations):
        """Aplicar personalizaciones a un dashboard"""
        try:
            # Personalizar título si se especifica
            if 'title' in customizations:
                dashboard['title'] = customizations['title']
            
            # Personalizar tiempo si se especifica
            if 'time' in customizations:
                if 'from' in customizations['time']:
                    dashboard['time']['from'] = customizations['time']['from']
                
                if 'to' in customizations['time']:
                    dashboard['time']['to'] = customizations['time']['to']
            
            # Personalizar intervalo de actualización si se especifica
            if 'refresh' in customizations:
                dashboard['refresh'] = customizations['refresh']
            
            # Personalizar paneles si se especifica
            if 'panels' in customizations:
                for panel_customization in customizations['panels']:
                    panel_id = panel_customization.get('id')
                    
                    if panel_id is not None:
                        # Buscar panel por ID
                        for i, panel in enumerate(dashboard['panels']):
                            if panel['id'] == panel_id:
                                # Aplicar personalizaciones al panel
                                if 'title' in panel_customization:
                                    dashboard['panels'][i]['title'] = panel_customization['title']
                                
                                if 'targets' in panel_customization:
                                    dashboard['panels'][i]['targets'] = panel_customization['targets']
                                
                                if 'gridPos' in panel_customization:
                                    dashboard['panels'][i]['gridPos'] = panel_customization['gridPos']
                                
                                break
            
            # Añadir nuevos paneles si se especifica
            if 'add_panels' in customizations:
                for panel in customizations['add_panels']:
                    # Generar ID único para el nuevo panel
                    existing_ids = [p['id'] for p in dashboard['panels'] if p['id'] is not None]
                    new_id = max(existing_ids) + 1 if existing_ids else 1
                    
                    # Asignar ID si no tiene
                    if 'id' not in panel:
                        panel['id'] = new_id
                    
                    dashboard['panels'].append(panel)
            
            return dashboard
        except Exception as e:
            logger.error(f"Error al aplicar personalizaciones al dashboard: {e}")
            return dashboard
    
    def import_dashboard_to_grafana(self, dashboard_file):
        """Importar dashboard a Grafana"""
        try:
            # Leer archivo del dashboard
            with open(dashboard_file, 'r') as f:
                dashboard = json.load(f)
            
            # Construir URL de importación
            import_url = f"{self.grafana_api_url}/dashboards/db"
            
            # Preparar payload
            payload = {
                'dashboard': dashboard,
                'overwrite': True
            }
            
            # Realizar solicitud POST
            response = requests.post(
                import_url,
                json=payload,
                auth=self.grafana_credentials,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                response_data = response.json()
                grafana_id = response_data.get('id')
                grafana_uid = response_data.get('uid')
                
                logger.info(f"Dashboard importado a Grafana: ID {grafana_id}, UID {grafana_uid}")
                return grafana_id
            else:
                logger.error(f"Error al importar dashboard a Grafana: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            logger.error(f"Error al importar dashboard a Grafana: {e}")
            return None
    
    def create_custom_dashboard(self, dashboard_config):
        """Crear un dashboard personalizado"""
        try:
            # Generar UID único
            dashboard_uid = str(uuid.uuid4())
            
            # Crear estructura básica del dashboard
            dashboard = {
                'id': None,
                'uid': dashboard_uid,
                'title': dashboard_config.get('title', 'Dashboard Personalizado'),
                'tags': dashboard_config.get('tags', []),
                'timezone': 'browser',
                'panels': dashboard_config.get('panels', []),
                'time': {
                    'from': dashboard_config.get('time_from', 'now-1h'),
                    'to': dashboard_config.get('time_to', 'now')
                },
                'refresh': dashboard_config.get('refresh', '30s')
            }
            
            # Validar paneles
            valid_panels = []
            
            for panel in dashboard['panels']:
                if self.validate_panel(panel):
                    valid_panels.append(panel)
                else:
                    logger.warning(f"Panel inválido omitido: {panel.get('title', 'Sin título')}")
            
            dashboard['panels'] = valid_panels
            
            # Guardar dashboard en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO dashboards (dashboard_uid, dashboard_name, dashboard_title, category, tags, dashboard_json, grafana_id)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                dashboard['uid'],
                dashboard['title'],
                dashboard['title'],
                dashboard_config.get('category', 'custom'),
                json.dumps(dashboard['tags']),
                json.dumps(dashboard),
                None  # grafana_id se actualizará después de importar a Grafana
            ))
            
            conn.commit()
            conn.close()
            
            # Guardar dashboard en archivo
            dashboard_file = os.path.join(self.dashboards_dir, f"{dashboard['uid']}.json")
            
            with open(dashboard_file, 'w') as f:
                json.dump(dashboard, f, indent=2)
            
            logger.info(f"Dashboard personalizado creado: {dashboard['title']} ({dashboard['uid']})")
            
            # Importar a Grafana si está configurado para importación automática
            grafana_id = None
            if self.config['dashboards']['auto_import']:
                grafana_id = self.import_dashboard_to_grafana(dashboard_file)
                
                if grafana_id:
                    # Actualizar ID de Grafana en la base de datos
                    conn = self.get_db_connection()
                    cursor = conn.cursor()
                    
                    cursor.execute('''
                        UPDATE dashboards SET grafana_id = ? WHERE dashboard_uid = ?
                    ''', (grafana_id, dashboard['uid']))
                    
                    conn.commit()
                    conn.close()
            
            return {
                'success': True,
                'dashboard_uid': dashboard['uid'],
                'dashboard_name': dashboard['title'],
                'dashboard_file': dashboard_file,
                'grafana_id': grafana_id
            }
        except Exception as e:
            logger.error(f"Error al crear dashboard personalizado: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def validate_panel(self, panel):
        """Validar un panel de dashboard"""
        try:
            # Verificar campos requeridos
            if 'title' not in panel:
                logger.warning("Panel sin título")
                return False
            
            if 'type' not in panel:
                logger.warning(f"Panel '{panel['title']}' sin tipo")
                return False
            
            if 'targets' not in panel or not panel['targets']:
                logger.warning(f"Panel '{panel['title']}' sin targets")
                return False
            
            if 'gridPos' not in panel:
                logger.warning(f"Panel '{panel['title']}' sin gridPos")
                return False
            
            # Verificar gridPos
            gridPos = panel['gridPos']
            required_gridPos_fields = ['h', 'w', 'x', 'y']
            
            for field in required_gridPos_fields:
                if field not in gridPos:
                    logger.warning(f"Panel '{panel['title']}' con gridPos incompleto: falta {field}")
                    return False
            
            return True
        except Exception as e:
            logger.error(f"Error al validar panel: {e}")
            return False
    
    def get_dashboard_list(self, category=None):
        """Obtener lista de dashboards"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            if category:
                cursor.execute('''
                    SELECT dashboard_uid, dashboard_name, dashboard_title, category, tags, grafana_id, created_at, updated_at
                    FROM dashboards
                    WHERE category = ?
                    ORDER BY dashboard_title
                ''', (category,))
            else:
                cursor.execute('''
                    SELECT dashboard_uid, dashboard_name, dashboard_title, category, tags, grafana_id, created_at, updated_at
                    FROM dashboards
                    ORDER BY dashboard_title
                ''')
            
            dashboards = []
            
            for row in cursor.fetchall():
                dashboard = {
                    'uid': row['dashboard_uid'],
                    'name': row['dashboard_name'],
                    'title': row['dashboard_title'],
                    'category': row['category'],
                    'tags': json.loads(row['tags']) if row['tags'] else [],
                    'grafana_id': row['grafana_id'],
                    'created_at': row['created_at'],
                    'updated_at': row['updated_at']
                }
                
                dashboards.append(dashboard)
            
            conn.close()
            
            return dashboards
        except Exception as e:
            logger.error(f"Error al obtener lista de dashboards: {e}")
            return []
    
    def get_dashboard(self, dashboard_uid):
        """Obtener un dashboard específico"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT dashboard_uid, dashboard_name, dashboard_title, category, tags, dashboard_json, grafana_id, created_at, updated_at
                FROM dashboards
                WHERE dashboard_uid = ?
            ''', (dashboard_uid,))
            
            row = cursor.fetchone()
            conn.close()
            
            if not row:
                return None
            
            return {
                'uid': row['dashboard_uid'],
                'name': row['dashboard_name'],
                'title': row['dashboard_title'],
                'category': row['category'],
                'tags': json.loads(row['tags']) if row['tags'] else [],
                'dashboard': json.loads(row['dashboard_json']),
                'grafana_id': row['grafana_id'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at']
            }
        except Exception as e:
            logger.error(f"Error al obtener dashboard: {e}")
            return None
    
    def update_dashboard(self, dashboard_uid, dashboard_config):
        """Actualizar un dashboard existente"""
        try:
            # Obtener dashboard actual
            current_dashboard = self.get_dashboard(dashboard_uid)
            
            if not current_dashboard:
                return {'success': False, 'error': 'Dashboard no encontrado'}
            
            # Actualizar dashboard
            dashboard = current_dashboard['dashboard']
            
            # Aplicar actualizaciones
            if 'title' in dashboard_config:
                dashboard['title'] = dashboard_config['title']
            
            if 'tags' in dashboard_config:
                dashboard['tags'] = dashboard_config['tags']
            
            if 'panels' in dashboard_config:
                # Validar nuevos paneles
                valid_panels = []
                
                for panel in dashboard_config['panels']:
                    if self.validate_panel(panel):
                        valid_panels.append(panel)
                    else:
                        logger.warning(f"Panel inválido omitido: {panel.get('title', 'Sin título')}")
                
                dashboard['panels'] = valid_panels
            
            if 'time' in dashboard_config:
                if 'from' in dashboard_config['time']:
                    dashboard['time']['from'] = dashboard_config['time']['from']
                
                if 'to' in dashboard_config['time']:
                    dashboard['time']['to'] = dashboard_config['time']['to']
            
            if 'refresh' in dashboard_config:
                dashboard['refresh'] = dashboard_config['refresh']
            
            # Actualizar en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                UPDATE dashboards
                SET dashboard_name = ?, dashboard_title = ?, tags = ?, dashboard_json = ?, updated_at = ?
                WHERE dashboard_uid = ?
            ''', (
                dashboard['title'],
                dashboard['title'],
                json.dumps(dashboard['tags']),
                json.dumps(dashboard),
                datetime.now(),
                dashboard_uid
            ))
            
            conn.commit()
            conn.close()
            
            # Guardar dashboard en archivo
            dashboard_file = os.path.join(self.dashboards_dir, f"{dashboard_uid}.json")
            
            with open(dashboard_file, 'w') as f:
                json.dump(dashboard, f, indent=2)
            
            # Importar a Grafana si está configurado para importación automática
            if self.config['dashboards']['auto_import']:
                self.import_dashboard_to_grafana(dashboard_file)
            
            logger.info(f"Dashboard actualizado: {dashboard['title']} ({dashboard_uid})")
            
            return {
                'success': True,
                'dashboard_uid': dashboard_uid,
                'dashboard_name': dashboard['title'],
                'dashboard_file': dashboard_file
            }
        except Exception as e:
            logger.error(f"Error al actualizar dashboard: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def delete_dashboard(self, dashboard_uid):
        """Eliminar un dashboard"""
        try:
            # Obtener dashboard
            dashboard = self.get_dashboard(dashboard_uid)
            
            if not dashboard:
                return {'success': False, 'error': 'Dashboard no encontrado'}
            
            # Eliminar de Grafana si tiene ID
            if dashboard['grafana_id']:
                try:
                    delete_url = f"{self.grafana_api_url}/dashboards/uid/{dashboard_uid}"
                    
                    response = requests.delete(
                        delete_url,
                        auth=self.grafana_credentials
                    )
                    
                    if response.status_code == 200:
                        logger.info(f"Dashboard eliminado de Grafana: {dashboard_uid}")
                    else:
                        logger.error(f"Error al eliminar dashboard de Grafana: {response.status_code} - {response.text}")
                except Exception as e:
                    logger.error(f"Error al eliminar dashboard de Grafana: {e}")
            
            # Eliminar de la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                DELETE FROM dashboards
                WHERE dashboard_uid = ?
            ''', (dashboard_uid,))
            
            conn.commit()
            conn.close()
            
            # Eliminar archivo
            dashboard_file = os.path.join(self.dashboards_dir, f"{dashboard_uid}.json")
            
            if os.path.exists(dashboard_file):
                os.remove(dashboard_file)
            
            logger.info(f"Dashboard eliminado: {dashboard['title']} ({dashboard_uid})")
            
            return {'success': True, 'message': 'Dashboard eliminado'}
        except Exception as e:
            logger.error(f"Error al eliminar dashboard: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def create_dashboard_suite(self, suite_name, categories=None):
        """Crear una suite de dashboards"""
        try:
            if not categories:
                categories = list(self.config['categories'].keys())
            
            suite_dashboards = []
            
            for category in categories:
                template_name = f"{category}_overview"
                dashboard_name = f"{suite_name} - {self.config['categories'][category]['name']}"
                
                result = self.create_dashboard_from_template(template_name, dashboard_name)
                
                if result['success']:
                    suite_dashboards.append(result)
                else:
                    logger.error(f"Error al crear dashboard para categoría {category}: {result.get('error')}")
            
            return {
                'success': True,
                'suite_name': suite_name,
                'dashboards': suite_dashboards,
                'count': len(suite_dashboards)
            }
        except Exception as e:
            logger.error(f"Error al crear suite de dashboards: {e}")
            return {
                'success': False,
                'error': str(e)
            }

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de Creación de Dashboards Personalizados para Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/monitoring/dashboard_config.json')
    parser.add_argument('--create-template', help='Crear dashboard desde plantilla')
    parser.add_argument('--template-name', help='Nombre de la plantilla')
    parser.add_argument('--dashboard-name', help='Nombre del dashboard')
    parser.add_argument('--list', help='Listar dashboards')
    parser.add_argument('--list-categories', action='store_true', help='Listar categorías disponibles')
    parser.add_argument('--get', help='Obtener dashboard específico')
    parser.add_argument('--delete', help='Eliminar dashboard específico')
    parser.add_argument('--create-suite', help='Crear suite de dashboards')
    parser.add_argument('--categories', help='Categorías para la suite (separadas por comas)')
    parser.add_argument('--custom', help='Archivo JSON con configuración de dashboard personalizado')
    
    args = parser.parse_args()
    
    # Inicializar sistema
    dashboard_creator = DashboardCreator(args.config)
    
    if args.create_template and args.template_name:
        # Crear dashboard desde plantilla
        result = dashboard_creator.create_dashboard_from_template(
            args.template_name,
            args.dashboard_name
        )
        
        if result['success']:
            print(f"Dashboard creado: {result['dashboard_name']} ({result['dashboard_uid']})")
            print(f"Archivo: {result['dashboard_file']}")
            if result['grafana_id']:
                print(f"ID de Grafana: {result['grafana_id']}")
        else:
            print(f"Error al crear dashboard: {result.get('error')}")
            sys.exit(1)
    elif args.custom:
        # Crear dashboard personalizado
        try:
            with open(args.custom, 'r') as f:
                dashboard_config = json.load(f)
            
            result = dashboard_creator.create_custom_dashboard(dashboard_config)
            
            if result['success']:
                print(f"Dashboard personalizado creado: {result['dashboard_name']} ({result['dashboard_uid']})")
                print(f"Archivo: {result['dashboard_file']}")
                if result['grafana_id']:
                    print(f"ID de Grafana: {result['grafana_id']}")
            else:
                print(f"Error al crear dashboard personalizado: {result.get('error')}")
                sys.exit(1)
        except Exception as e:
            print(f"Error al leer archivo de configuración: {e}")
            sys.exit(1)
    elif args.list:
        # Listar dashboards
        category = None  # Podría ser un parámetro en el futuro
        
        dashboards = dashboard_creator.get_dashboard_list(category)
        
        if dashboards:
            print("Dashboards disponibles:")
            for dashboard in dashboards:
                grafana_info = f" (Grafana ID: {dashboard['grafana_id']})" if dashboard['grafana_id'] else ""
                print(f"  - {dashboard['title']} ({dashboard['uid']}) - {dashboard['category']}{grafana_info}")
        else:
            print("No hay dashboards disponibles")
    elif args.list_categories:
        # Listar categorías
        print("Categorías disponibles:")
        for category, config in dashboard_creator.config['categories'].items():
            print(f"  - {category}: {config['name']} ({config['color']})")
    elif args.get:
        # Obtener dashboard específico
        dashboard = dashboard_creator.get_dashboard(args.get)
        
        if dashboard:
            print(f"Dashboard: {dashboard['title']} ({dashboard['uid']})")
            print(f"Categoría: {dashboard['category']}")
            print(f"Tags: {', '.join(dashboard['tags'])}")
            print(f"Paneles: {len(dashboard['dashboard']['panels'])}")
            print(f"Archivo: {os.path.join(dashboard_creator.dashboards_dir, f'{dashboard[\"uid\"]}.json')}")
            if dashboard['grafana_id']:
                print(f"ID de Grafana: {dashboard['grafana_id']}")
        else:
            print(f"Dashboard no encontrado: {args.get}")
            sys.exit(1)
    elif args.delete:
        # Eliminar dashboard
        result = dashboard_creator.delete_dashboard(args.delete)
        
        if result['success']:
            print(f"Dashboard eliminado: {args.delete}")
        else:
            print(f"Error al eliminar dashboard: {result.get('error')}")
            sys.exit(1)
    elif args.create_suite:
        # Crear suite de dashboards
        categories = None
        
        if args.categories:
            categories = [cat.strip() for cat in args.categories.split(',')]
        
        result = dashboard_creator.create_dashboard_suite(args.create_suite, categories)
        
        if result['success']:
            print(f"Suite de dashboards creada: {result['suite_name']}")
            print(f"Dashboards creados: {result['count']}")
            
            for dashboard in result['dashboards']:
                print(f"  - {dashboard['dashboard_name']} ({dashboard['dashboard_uid']})")
        else:
            print(f"Error al crear suite de dashboards: {result.get('error')}")
            sys.exit(1)
    else:
        # Crear suite de dashboards por defecto
        result = dashboard_creator.create_dashboard_suite("Virtualmin Enterprise")
        
        if result['success']:
            print(f"Suite de dashboards creada: {result['suite_name']}")
            print(f"Dashboards creados: {result['count']}")
            
            for dashboard in result['dashboards']:
                print(f"  - {dashboard['dashboard_name']} ({dashboard['dashboard_uid']})")
        else:
            print(f"Error al crear suite de dashboards: {result.get('error')}")
            sys.exit(1)

if __name__ == "__main__":
    main()