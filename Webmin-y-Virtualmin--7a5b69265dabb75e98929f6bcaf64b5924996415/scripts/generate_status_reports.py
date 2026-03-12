#!/usr/bin/env python3
"""
Script para generar reportes de estado automáticos de Virtualmin Enterprise
Integra métricas de sistema, seguridad, rendimiento y disponibilidad
"""

import os
import sys
import json
import yaml
import datetime
import time
import subprocess
import logging
import argparse
import requests
import sqlite3
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from jinja2 import Template, Environment, FileSystemLoader
from pathlib import Path

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin/status_reports.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Configuración
SCRIPT_DIR = Path(__file__).parent.absolute()
PROJECT_ROOT = SCRIPT_DIR.parent
CONFIG_DIR = PROJECT_ROOT / "configs"
REPORTS_DIR = PROJECT_ROOT / "reports"
STATUS_DB = PROJECT_ROOT / "data" / "status_metrics.db"
CONFIG_FILE = CONFIG_DIR / "status_reports_config.yml"

# Asegurar que los directorios existan
os.makedirs(REPORTS_DIR, exist_ok=True)
os.makedirs(STATUS_DB.parent, exist_ok=True)

class StatusReportGenerator:
    """Clase principal para generar reportes de estado"""
    
    def __init__(self, config_file=None):
        """Inicializar el generador de reportes"""
        self.config_file = config_file or CONFIG_FILE
        self.config = self.load_config()
        self.db_connection = None
        self.setup_database()
        
    def load_config(self):
        """Cargar configuración desde archivo YAML"""
        if not os.path.exists(self.config_file):
            logger.warning(f"Archivo de configuración no encontrado: {self.config_file}")
            return self.create_default_config()
        
        try:
            with open(self.config_file, 'r') as f:
                config = yaml.safe_load(f)
            logger.info(f"Configuración cargada desde: {self.config_file}")
            return config
        except Exception as e:
            logger.error(f"Error al cargar configuración: {str(e)}")
            return self.create_default_config()
    
    def create_default_config(self):
        """Crear configuración por defecto"""
        default_config = {
            "general": {
                "project_name": "Virtualmin Enterprise",
                "environment": "production",
                "reports_dir": str(REPORTS_DIR),
                "retention_days": 30
            },
            "metrics": {
                "system": {
                    "enabled": True,
                    "interval": 300,  # segundos
                    "sources": ["/proc", "/sys"]
                },
                "security": {
                    "enabled": True,
                    "interval": 600,
                    "sources": ["firewall", "ids", "ssl", "auth"]
                },
                "performance": {
                    "enabled": True,
                    "interval": 300,
                    "sources": ["cpu", "memory", "disk", "network"]
                },
                "services": {
                    "enabled": True,
                    "interval": 60,
                    "services": ["virtualmin", "webmin", "apache", "nginx", "mysql"]
                }
            },
            "alerts": {
                "enabled": True,
                "thresholds": {
                    "cpu_usage": 80,
                    "memory_usage": 85,
                    "disk_usage": 90,
                    "response_time": 2000,
                    "error_rate": 5
                }
            },
            "reporting": {
                "formats": ["html", "json", "pdf"],
                "schedule": "daily",
                "email": {
                    "enabled": False,
                    "recipients": ["admin@example.com"],
                    "smtp_server": "localhost",
                    "smtp_port": 587,
                    "smtp_user": "",
                    "smtp_password": ""
                }
            }
        }
        
        # Guardar configuración por defecto
        try:
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w') as f:
                yaml.dump(default_config, f, default_flow_style=False)
            logger.info(f"Configuración por defecto creada en: {self.config_file}")
        except Exception as e:
            logger.error(f"Error al crear configuración por defecto: {str(e)}")
        
        return default_config
    
    def setup_database(self):
        """Configurar base de datos SQLite para métricas"""
        try:
            self.db_connection = sqlite3.connect(STATUS_DB)
            cursor = self.db_connection.cursor()
            
            # Crear tablas si no existen
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS system_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    metric_name TEXT,
                    metric_value REAL,
                    unit TEXT
                )
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS security_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    metric_name TEXT,
                    metric_value TEXT,
                    severity TEXT
                )
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS performance_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    metric_name TEXT,
                    metric_value REAL,
                    unit TEXT
                )
            ''')
            
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS service_status (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                    service_name TEXT,
                    status TEXT,
                    response_time REAL,
                    uptime TEXT
                )
            ''')
            
            self.db_connection.commit()
            logger.info("Base de datos configurada correctamente")
        except Exception as e:
            logger.error(f"Error al configurar base de datos: {str(e)}")
            raise
    
    def collect_system_metrics(self):
        """Recopilar métricas del sistema"""
        if not self.config["metrics"]["system"]["enabled"]:
            return {}
        
        logger.info("Recopilando métricas del sistema")
        metrics = {}
        
        try:
            # CPU Usage
            cpu_usage = self.get_cpu_usage()
            metrics["cpu_usage"] = cpu_usage
            
            # Memory Usage
            memory_usage = self.get_memory_usage()
            metrics.update(memory_usage)
            
            # Disk Usage
            disk_usage = self.get_disk_usage()
            metrics.update(disk_usage)
            
            # Network Stats
            network_stats = self.get_network_stats()
            metrics.update(network_stats)
            
            # System Uptime
            uptime = self.get_system_uptime()
            metrics["uptime"] = uptime
            
            # Guardar métricas en la base de datos
            self.save_system_metrics(metrics)
            
            return metrics
        except Exception as e:
            logger.error(f"Error al recopilar métricas del sistema: {str(e)}")
            return {}
    
    def get_cpu_usage(self):
        """Obtener uso de CPU"""
        try:
            # Usar comando top para obtener uso de CPU
            result = subprocess.run(
                ["top", "-bn", "1", "-p", "1"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            for line in result.stdout.split('\n'):
                if '%Cpu(s):' in line:
                    # Extraer porcentaje de uso de CPU
                    parts = line.split(',')
                    for part in parts:
                        if 'id,' in part:
                            idle = float(part.strip().split()[0].replace(',', ''))
                            cpu_usage = 100.0 - idle
                            return cpu_usage
            
            # Alternativa usando /proc/stat
            with open('/proc/stat', 'r') as f:
                lines = f.readlines()
                for line in lines:
                    if line.startswith('cpu '):
                        parts = line.split()
                        user = int(parts[1])
                        nice = int(parts[2])
                        system = int(parts[3])
                        idle = int(parts[4])
                        iowait = int(parts[5])
                        irq = int(parts[6])
                        softirq = int(parts[7])
                        total = user + nice + system + idle + iowait + irq + softirq
                        cpu_usage = ((total - idle) / total) * 100
                        return cpu_usage
            
            return 0.0
        except Exception as e:
            logger.error(f"Error al obtener uso de CPU: {str(e)}")
            return 0.0
    
    def get_memory_usage(self):
        """Obtener uso de memoria"""
        try:
            with open('/proc/meminfo', 'r') as f:
                lines = f.readlines()
                
            mem_info = {}
            for line in lines:
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip()
                    if 'kB' in value:
                        value = int(value.split()[0])
                        mem_info[key] = value
            
            total_memory = mem_info.get('MemTotal', 0)
            free_memory = mem_info.get('MemFree', 0)
            available_memory = mem_info.get('MemAvailable', free_memory)
            buffers = mem_info.get('Buffers', 0)
            cached = mem_info.get('Cached', 0)
            
            used_memory = total_memory - available_memory
            memory_usage_percent = (used_memory / total_memory) * 100 if total_memory > 0 else 0
            
            return {
                "memory_total_kb": total_memory,
                "memory_used_kb": used_memory,
                "memory_available_kb": available_memory,
                "memory_usage_percent": memory_usage_percent,
                "memory_buffers_kb": buffers,
                "memory_cached_kb": cached
            }
        except Exception as e:
            logger.error(f"Error al obtener uso de memoria: {str(e)}")
            return {}
    
    def get_disk_usage(self):
        """Obtener uso de disco"""
        try:
            result = subprocess.run(
                ["df", "-h"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            disk_info = {}
            lines = result.stdout.strip().split('\n')[1:]  # Omitir encabezado
            
            for line in lines:
                parts = line.split()
                if len(parts) >= 6:
                    filesystem = parts[0]
                    size = parts[1]
                    used = parts[2]
                    available = parts[3]
                    usage_percent = parts[4].replace('%', '')
                    mount_point = parts[5]
                    
                    # Convertir uso porcentaje a número
                    try:
                        usage_num = float(usage_percent)
                    except ValueError:
                        usage_num = 0
                    
                    disk_info[f"disk_{mount_point.replace('/', '_')}_usage_percent"] = usage_num
                    disk_info[f"disk_{mount_point.replace('/', '_')}_size"] = size
                    disk_info[f"disk_{mount_point.replace('/', '_')}_used"] = used
                    disk_info[f"disk_{mount_point.replace('/', '_')}_available"] = available
            
            return disk_info
        except Exception as e:
            logger.error(f"Error al obtener uso de disco: {str(e)}")
            return {}
    
    def get_network_stats(self):
        """Obtener estadísticas de red"""
        try:
            with open('/proc/net/dev', 'r') as f:
                lines = f.readlines()
            
            network_info = {}
            # Omitir encabezados
            for line in lines[2:]:
                if ':' in line:
                    parts = line.split(':')
                    interface = parts[0].strip()
                    stats = parts[1].strip().split()
                    
                    if len(stats) >= 16:
                        rx_bytes = int(stats[0])
                        tx_bytes = int(stats[8])
                        
                        network_info[f"network_{interface}_rx_bytes"] = rx_bytes
                        network_info[f"network_{interface}_tx_bytes"] = tx_bytes
            
            return network_info
        except Exception as e:
            logger.error(f"Error al obtener estadísticas de red: {str(e)}")
            return {}
    
    def get_system_uptime(self):
        """Obtener tiempo de actividad del sistema"""
        try:
            with open('/proc/uptime', 'r') as f:
                uptime_seconds = float(f.read().split()[0])
                
            # Convertir a días, horas, minutos
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            
            return {
                "uptime_seconds": uptime_seconds,
                "uptime_days": days,
                "uptime_hours": hours,
                "uptime_minutes": minutes,
                "uptime_formatted": f"{days}d {hours}h {minutes}m"
            }
        except Exception as e:
            logger.error(f"Error al obtener tiempo de actividad: {str(e)}")
            return {}
    
    def collect_security_metrics(self):
        """Recopilar métricas de seguridad"""
        if not self.config["metrics"]["security"]["enabled"]:
            return {}
        
        logger.info("Recopilando métricas de seguridad")
        metrics = {}
        
        try:
            # Firewall Status
            firewall_status = self.get_firewall_status()
            metrics.update(firewall_status)
            
            # SSL Certificates Status
            ssl_status = self.get_ssl_certificates_status()
            metrics.update(ssl_status)
            
            # Authentication Attempts
            auth_attempts = self.get_authentication_attempts()
            metrics.update(auth_attempts)
            
            # Failed Login Attempts
            failed_logins = self.get_failed_login_attempts()
            metrics.update(failed_logins)
            
            # Guardar métricas en la base de datos
            self.save_security_metrics(metrics)
            
            return metrics
        except Exception as e:
            logger.error(f"Error al recopilar métricas de seguridad: {str(e)}")
            return {}
    
    def get_firewall_status(self):
        """Obtener estado del firewall"""
        try:
            # Verificar si ufw está instalado y activo
            result = subprocess.run(
                ["ufw", "status"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                is_active = "Status: active" in result.stdout
                return {
                    "firewall_active": is_active,
                    "firewall_type": "ufw",
                    "firewall_status": "active" if is_active else "inactive"
                }
            
            # Verificar si iptables está activo
            result = subprocess.run(
                ["iptables", "-L", "-n"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Contar reglas
                rules_count = len([line for line in result.stdout.split('\n') if line.startswith('ACCEPT') or line.startswith('DROP') or line.startswith('REJECT')])
                return {
                    "firewall_active": rules_count > 0,
                    "firewall_type": "iptables",
                    "firewall_rules_count": rules_count,
                    "firewall_status": "active" if rules_count > 0 else "inactive"
                }
            
            return {
                "firewall_active": False,
                "firewall_type": "unknown",
                "firewall_status": "inactive"
            }
        except Exception as e:
            logger.error(f"Error al obtener estado del firewall: {str(e)}")
            return {
                "firewall_active": False,
                "firewall_type": "unknown",
                "firewall_status": "error"
            }
    
    def get_ssl_certificates_status(self):
        """Obtener estado de certificados SSL"""
        try:
            # Buscar certificados SSL en directorios comunes
            ssl_dirs = [
                "/etc/ssl/certs",
                "/etc/apache2/ssl",
                "/etc/nginx/ssl",
                "/etc/postfix/ssl",
                "/home/*/sslcerts"
            ]
            
            cert_info = {}
            total_certs = 0
            valid_certs = 0
            expired_certs = 0
            expiring_soon_certs = 0
            
            for ssl_dir in ssl_dirs:
                # Expandir comodines en la ruta
                if '*' in ssl_dir:
                    expanded_dirs = subprocess.run(
                        ["bash", "-c", "echo " + ssl_dir],
                        capture_output=True,
                        text=True,
                        timeout=5
                    )
                    ssl_dirs_list = expanded_dirs.stdout.strip().split()
                else:
                    ssl_dirs_list = [ssl_dir]
                
                for dir_path in ssl_dirs_list:
                    if not os.path.isdir(dir_path):
                        continue
                    
                    for cert_file in os.listdir(dir_path):
                        if cert_file.endswith('.crt') or cert_file.endswith('.pem'):
                            cert_path = os.path.join(dir_path, cert_file)
                            
                            # Verificar fecha de expiración
                            result = subprocess.run(
                                ["openssl", "x509", "-in", cert_path, "-noout", "-dates"],
                                capture_output=True,
                                text=True,
                                timeout=10
                            )
                            
                            if result.returncode == 0:
                                for line in result.stdout.split('\n'):
                                    if line.startswith('notAfter='):
                                        date_str = line.split('=')[1]
                                        expiry_date = datetime.datetime.strptime(date_str, '%b %d %H:%M:%S %Y %Z')
                                        
                                        now = datetime.datetime.now()
                                        days_until_expiry = (expiry_date - now).days
                                        
                                        total_certs += 1
                                        
                                        if days_until_expiry < 0:
                                            expired_certs += 1
                                            status = "expired"
                                        elif days_until_expiry < 30:
                                            expiring_soon_certs += 1
                                            status = "expiring_soon"
                                        else:
                                            valid_certs += 1
                                            status = "valid"
                                        
                                        cert_info[f"ssl_cert_{cert_file}_status"] = status
                                        cert_info[f"ssl_cert_{cert_file}_days_until_expiry"] = days_until_expiry
            
            cert_info["ssl_total_certs"] = total_certs
            cert_info["ssl_valid_certs"] = valid_certs
            cert_info["ssl_expired_certs"] = expired_certs
            cert_info["ssl_expiring_soon_certs"] = expiring_soon_certs
            
            return cert_info
        except Exception as e:
            logger.error(f"Error al obtener estado de certificados SSL: {str(e)}")
            return {}
    
    def get_authentication_attempts(self):
        """Obtener intentos de autenticación"""
        try:
            # Buscar en logs de autenticación
            auth_logs = [
                "/var/log/auth.log",
                "/var/log/secure",
                "/var/log/virtualmin/auth.log"
            ]
            
            total_attempts = 0
            successful_attempts = 0
            
            now = datetime.datetime.now()
            one_day_ago = now - datetime.timedelta(days=1)
            
            for log_file in auth_logs:
                if not os.path.exists(log_file):
                    continue
                
                # Usar grep para buscar intentos de autenticación en las últimas 24 horas
                result = subprocess.run(
                    ["grep", "-E", "(Accepted|Failed|authentication)", log_file],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            total_attempts += 1
                            if "Accepted" in line:
                                successful_attempts += 1
            
            return {
                "auth_total_attempts_24h": total_attempts,
                "auth_successful_attempts_24h": successful_attempts,
                "auth_failed_attempts_24h": total_attempts - successful_attempts
            }
        except Exception as e:
            logger.error(f"Error al obtener intentos de autenticación: {str(e)}")
            return {}
    
    def get_failed_login_attempts(self):
        """Obtener intentos de inicio de sesión fallidos"""
        try:
            # Buscar en logs de Virtualmin
            virtualmin_logs = [
                "/var/log/virtualmin/miniserv.log",
                "/var/webmin/miniserv.log"
            ]
            
            failed_attempts = 0
            blocked_ips = set()
            
            now = datetime.datetime.now()
            one_day_ago = now - datetime.timedelta(days=1)
            
            for log_file in virtualmin_logs:
                if not os.path.exists(log_file):
                    continue
                
                # Usar grep para buscar intentos fallidos en las últimas 24 horas
                result = subprocess.run(
                    ["grep", "-E", "(Failed|Invalid)", log_file],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if result.returncode == 0:
                    for line in result.stdout.split('\n'):
                        if line.strip():
                            failed_attempts += 1
                            
                            # Extraer IP si está disponible
                            parts = line.split()
                            for part in parts:
                                if self.is_valid_ip(part):
                                    blocked_ips.add(part)
            
            return {
                "failed_login_attempts_24h": failed_attempts,
                "blocked_ips_count_24h": len(blocked_ips)
            }
        except Exception as e:
            logger.error(f"Error al obtener intentos de inicio de sesión fallidos: {str(e)}")
            return {}
    
    def is_valid_ip(self, ip):
        """Verificar si una cadena es una dirección IP válida"""
        try:
            parts = ip.split('.')
            if len(parts) != 4:
                return False
            
            for part in parts:
                if not part.isdigit() or int(part) < 0 or int(part) > 255:
                    return False
            
            return True
        except:
            return False
    
    def collect_performance_metrics(self):
        """Recopilar métricas de rendimiento"""
        if not self.config["metrics"]["performance"]["enabled"]:
            return {}
        
        logger.info("Recopilando métricas de rendimiento")
        metrics = {}
        
        try:
            # Response Time for Virtualmin
            response_time = self.get_virtualmin_response_time()
            metrics["virtualmin_response_time"] = response_time
            
            # Database Performance
            db_performance = self.get_database_performance()
            metrics.update(db_performance)
            
            # Web Server Performance
            web_performance = self.get_web_server_performance()
            metrics.update(web_performance)
            
            # Guardar métricas en la base de datos
            self.save_performance_metrics(metrics)
            
            return metrics
        except Exception as e:
            logger.error(f"Error al recopilar métricas de rendimiento: {str(e)}")
            return {}
    
    def get_virtualmin_response_time(self):
        """Obtener tiempo de respuesta de Virtualmin"""
        try:
            # Realizar una solicitud HTTP a Virtualmin
            start_time = time.time()
            
            response = requests.get(
                "https://localhost:10000/",
                verify=False,  # Ignorar verificación SSL para pruebas locales
                timeout=10
            )
            
            end_time = time.time()
            response_time = (end_time - start_time) * 1000  # Convertir a milisegundos
            
            return response_time
        except Exception as e:
            logger.error(f"Error al obtener tiempo de respuesta de Virtualmin: {str(e)}")
            return -1  # Indicar error
    
    def get_database_performance(self):
        """Obtener métricas de rendimiento de la base de datos"""
        try:
            # Verificar si MySQL/MariaDB está en ejecución
            result = subprocess.run(
                ["systemctl", "is-active", "mysql"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.stdout.strip() == "active":
                # Obtener estado de MySQL
                mysql_status = subprocess.run(
                    ["mysql", "-e", "SHOW STATUS LIKE 'Connections';"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if mysql_status.returncode == 0:
                    for line in mysql_status.stdout.split('\n'):
                        if 'Connections' in line:
                            parts = line.split('\t')
                            if len(parts) >= 2:
                                connections = parts[1]
                                return {
                                    "mysql_active": True,
                                    "mysql_connections": int(connections)
                                }
                
                return {"mysql_active": True}
            else:
                return {"mysql_active": False}
        except Exception as e:
            logger.error(f"Error al obtener métricas de base de datos: {str(e)}")
            return {"mysql_active": False, "mysql_error": str(e)}
    
    def get_web_server_performance(self):
        """Obtener métricas de rendimiento del servidor web"""
        try:
            # Verificar si Apache está en ejecución
            apache_result = subprocess.run(
                ["systemctl", "is-active", "apache2"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            # Verificar si Nginx está en ejecución
            nginx_result = subprocess.run(
                ["systemctl", "is-active", "nginx"],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            web_metrics = {}
            
            if apache_result.stdout.strip() == "active":
                # Obtener estado de Apache
                apache_status = subprocess.run(
                    ["apache2ctl", "status"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if apache_status.returncode == 0:
                    for line in apache_status.stdout.split('\n'):
                        if "requests currently being processed" in line:
                            parts = line.split()
                            if len(parts) >= 1:
                                requests = parts[0]
                                web_metrics["apache_active_requests"] = int(requests)
                
                web_metrics["apache_active"] = True
            else:
                web_metrics["apache_active"] = False
            
            if nginx_result.stdout.strip() == "active":
                # Obtener estado de Nginx
                nginx_status = subprocess.run(
                    ["nginx", "-s", "status"],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                web_metrics["nginx_active"] = True
            else:
                web_metrics["nginx_active"] = False
            
            return web_metrics
        except Exception as e:
            logger.error(f"Error al obtener métricas del servidor web: {str(e)}")
            return {}
    
    def collect_service_status(self):
        """Recopilar estado de servicios"""
        if not self.config["metrics"]["services"]["enabled"]:
            return {}
        
        logger.info("Recopilando estado de servicios")
        service_status = {}
        
        try:
            services = self.config["metrics"]["services"]["services"]
            
            for service in services:
                status = self.get_service_status(service)
                service_status[service] = status
                
                # Guardar estado en la base de datos
                self.save_service_status(service, status)
            
            return service_status
        except Exception as e:
            logger.error(f"Error al recopilar estado de servicios: {str(e)}")
            return {}
    
    def get_service_status(self, service_name):
        """Obtener estado de un servicio específico"""
        try:
            # Verificar si el servicio está activo
            result = subprocess.run(
                ["systemctl", "is-active", service_name],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            status = result.stdout.strip()
            
            # Obtener información adicional si el servicio está activo
            if status == "active":
                # Obtener tiempo de actividad
                uptime_result = subprocess.run(
                    ["systemctl", "show", service_name, "--property=ActiveEnterTimestamp"],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                uptime = "Unknown"
                if uptime_result.returncode == 0:
                    for line in uptime_result.stdout.split('\n'):
                        if 'ActiveEnterTimestamp=' in line:
                            timestamp_str = line.split('=')[1]
                            try:
                                timestamp = datetime.datetime.fromisoformat(timestamp_str)
                                now = datetime.datetime.now()
                                uptime_seconds = (now - timestamp).total_seconds()
                                uptime_days = int(uptime_seconds // 86400)
                                uptime_hours = int((uptime_seconds % 86400) // 3600)
                                uptime_minutes = int((uptime_seconds % 3600) // 60)
                                uptime = f"{uptime_days}d {uptime_hours}h {uptime_minutes}m"
                            except:
                                pass
                
                # Medir tiempo de respuesta para servicios web
                response_time = -1
                if service_name in ["virtualmin", "webmin"]:
                    response_time = self.get_virtualmin_response_time()
                
                return {
                    "status": status,
                    "uptime": uptime,
                    "response_time": response_time
                }
            else:
                return {
                    "status": status,
                    "uptime": "Inactive",
                    "response_time": -1
                }
        except Exception as e:
            logger.error(f"Error al obtener estado del servicio {service_name}: {str(e)}")
            return {
                "status": "error",
                "uptime": "Unknown",
                "response_time": -1,
                "error": str(e)
            }
    
    def save_system_metrics(self, metrics):
        """Guardar métricas del sistema en la base de datos"""
        if not self.db_connection:
            return
        
        try:
            cursor = self.db_connection.cursor()
            
            for metric_name, metric_value in metrics.items():
                if isinstance(metric_value, (int, float)):
                    unit = ""
                    if "usage" in metric_name and "percent" in metric_name:
                        unit = "%"
                    elif "bytes" in metric_name:
                        unit = "bytes"
                    elif "seconds" in metric_name:
                        unit = "seconds"
                    elif metric_name in ["uptime_days", "uptime_hours", "uptime_minutes"]:
                        unit = "count"
                    
                    cursor.execute(
                        "INSERT INTO system_metrics (metric_name, metric_value, unit) VALUES (?, ?, ?)",
                        (metric_name, metric_value, unit)
                    )
            
            self.db_connection.commit()
        except Exception as e:
            logger.error(f"Error al guardar métricas del sistema: {str(e)}")
    
    def save_security_metrics(self, metrics):
        """Guardar métricas de seguridad en la base de datos"""
        if not self.db_connection:
            return
        
        try:
            cursor = self.db_connection.cursor()
            
            for metric_name, metric_value in metrics.items():
                severity = "info"
                
                if "firewall" in metric_name and not metric_value:
                    severity = "critical"
                elif "ssl_expired" in metric_name and metric_value > 0:
                    severity = "critical"
                elif "ssl_expiring_soon" in metric_name and metric_value > 0:
                    severity = "warning"
                elif "failed" in metric_name and metric_value > 10:
                    severity = "warning"
                
                cursor.execute(
                    "INSERT INTO security_metrics (metric_name, metric_value, severity) VALUES (?, ?, ?)",
                    (metric_name, str(metric_value), severity)
                )
            
            self.db_connection.commit()
        except Exception as e:
            logger.error(f"Error al guardar métricas de seguridad: {str(e)}")
    
    def save_performance_metrics(self, metrics):
        """Guardar métricas de rendimiento en la base de datos"""
        if not self.db_connection:
            return
        
        try:
            cursor = self.db_connection.cursor()
            
            for metric_name, metric_value in metrics.items():
                if isinstance(metric_value, (int, float)):
                    unit = ""
                    if "response_time" in metric_name:
                        unit = "ms"
                    elif "connections" in metric_name:
                        unit = "count"
                    elif "requests" in metric_name:
                        unit = "count"
                    
                    cursor.execute(
                        "INSERT INTO performance_metrics (metric_name, metric_value, unit) VALUES (?, ?, ?)",
                        (metric_name, metric_value, unit)
                    )
            
            self.db_connection.commit()
        except Exception as e:
            logger.error(f"Error al guardar métricas de rendimiento: {str(e)}")
    
    def save_service_status(self, service_name, status):
        """Guardar estado de servicio en la base de datos"""
        if not self.db_connection:
            return
        
        try:
            cursor = self.db_connection.cursor()
            
            cursor.execute(
                "INSERT INTO service_status (service_name, status, response_time, uptime) VALUES (?, ?, ?, ?)",
                (service_name, status.get("status", ""), status.get("response_time", -1), status.get("uptime", ""))
            )
            
            self.db_connection.commit()
        except Exception as e:
            logger.error(f"Error al guardar estado del servicio {service_name}: {str(e)}")
    
    def check_alerts(self, metrics):
        """Verificar si alguna métrica supera los umbrales configurados"""
        if not self.config["alerts"]["enabled"]:
            return []
        
        logger.info("Verificando alertas")
        alerts = []
        thresholds = self.config["alerts"]["thresholds"]
        
        # Verificar uso de CPU
        if "cpu_usage" in metrics and metrics["cpu_usage"] > thresholds["cpu_usage"]:
            alerts.append({
                "type": "cpu_usage",
                "severity": "warning",
                "message": f"Uso de CPU elevado: {metrics['cpu_usage']}%",
                "threshold": thresholds["cpu_usage"],
                "current_value": metrics["cpu_usage"]
            })
        
        # Verificar uso de memoria
        if "memory_usage_percent" in metrics and metrics["memory_usage_percent"] > thresholds["memory_usage"]:
            alerts.append({
                "type": "memory_usage",
                "severity": "warning",
                "message": f"Uso de memoria elevado: {metrics['memory_usage_percent']}%",
                "threshold": thresholds["memory_usage"],
                "current_value": metrics["memory_usage_percent"]
            })
        
        # Verificar uso de disco
        for key, value in metrics.items():
            if "disk_usage_percent" in key and value > thresholds["disk_usage"]:
                alerts.append({
                    "type": "disk_usage",
                    "severity": "critical",
                    "message": f"Uso de disco elevado en {key.replace('disk_', '').replace('_usage_percent', '')}: {value}%",
                    "threshold": thresholds["disk_usage"],
                    "current_value": value
                })
        
        # Verificar tiempo de respuesta
        if "virtualmin_response_time" in metrics and metrics["virtualmin_response_time"] > thresholds["response_time"]:
            alerts.append({
                "type": "response_time",
                "severity": "warning",
                "message": f"Tiempo de respuesta elevado: {metrics['virtualmin_response_time']}ms",
                "threshold": thresholds["response_time"],
                "current_value": metrics["virtualmin_response_time"]
            })
        
        # Verificar certificados SSL expirados
        if "ssl_expired_certs" in metrics and metrics["ssl_expired_certs"] > 0:
            alerts.append({
                "type": "ssl_expired",
                "severity": "critical",
                "message": f"Hay {metrics['ssl_expired_certs']} certificados SSL expirados",
                "threshold": 0,
                "current_value": metrics["ssl_expired_certs"]
            })
        
        # Verificar certificados SSL por expirar
        if "ssl_expiring_soon_certs" in metrics and metrics["ssl_expiring_soon_certs"] > 0:
            alerts.append({
                "type": "ssl_expiring_soon",
                "severity": "warning",
                "message": f"Hay {metrics['ssl_expiring_soon_certs']} certificados SSL por expirar",
                "threshold": 0,
                "current_value": metrics["ssl_expiring_soon_certs"]
            })
        
        # Verificar intentos de inicio de sesión fallidos
        if "failed_login_attempts_24h" in metrics and metrics["failed_login_attempts_24h"] > 20:
            alerts.append({
                "type": "failed_logins",
                "severity": "warning",
                "message": f"Hay {metrics['failed_login_attempts_24h']} intentos de inicio de sesión fallidos en las últimas 24 horas",
                "threshold": 20,
                "current_value": metrics["failed_login_attempts_24h"]
            })
        
        return alerts
    
    def generate_report(self, format_type="html"):
        """Generar reporte de estado"""
        logger.info(f"Generando reporte en formato {format_type}")
        
        # Recopilar todas las métricas
        system_metrics = self.collect_system_metrics()
        security_metrics = self.collect_security_metrics()
        performance_metrics = self.collect_performance_metrics()
        service_status = self.collect_service_status()
        
        # Combinar todas las métricas
        all_metrics = {}
        all_metrics.update(system_metrics)
        all_metrics.update(security_metrics)
        all_metrics.update(performance_metrics)
        
        # Verificar alertas
        alerts = self.check_alerts(all_metrics)
        
        # Crear datos para el reporte
        report_data = {
            "timestamp": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "project_name": self.config["general"]["project_name"],
            "environment": self.config["general"]["environment"],
            "system_metrics": system_metrics,
            "security_metrics": security_metrics,
            "performance_metrics": performance_metrics,
            "service_status": service_status,
            "alerts": alerts,
            "charts": {}
        }
        
        # Generar gráficos
        if format_type == "html":
            report_data["charts"] = self.generate_charts(all_metrics)
        
        # Generar reporte según el formato
        if format_type == "html":
            return self.generate_html_report(report_data)
        elif format_type == "json":
            return self.generate_json_report(report_data)
        elif format_type == "pdf":
            return self.generate_pdf_report(report_data)
        else:
            raise ValueError(f"Formato de reporte no soportado: {format_type}")
    
    def generate_charts(self, metrics):
        """Generar gráficos para el reporte"""
        charts = {}
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        
        try:
            # Gráfico de uso de CPU y memoria
            cpu_memory_data = self.get_metrics_history("cpu_usage, memory_usage_percent", hours=24)
            if cpu_memory_data:
                plt.figure(figsize=(10, 6))
                
                df = pd.DataFrame(cpu_memory_data)
                df['timestamp'] = pd.to_datetime(df['timestamp'])
                
                plt.plot(df['timestamp'], df['metric_value'], label='CPU Usage (%)')
                
                memory_data = self.get_metrics_history("memory_usage_percent", hours=24)
                if memory_data:
                    df_memory = pd.DataFrame(memory_data)
                    df_memory['timestamp'] = pd.to_datetime(df_memory['timestamp'])
                    plt.plot(df_memory['timestamp'], df_memory['metric_value'], label='Memory Usage (%)')
                
                plt.title('CPU and Memory Usage (Last 24 Hours)')
                plt.xlabel('Time')
                plt.ylabel('Usage (%)')
                plt.legend()
                plt.grid(True)
                plt.tight_layout()
                
                chart_path = REPORTS_DIR / f"cpu_memory_usage_{timestamp}.png"
                plt.savefig(chart_path)
                plt.close()
                
                charts["cpu_memory_usage"] = str(chart_path)
            
            # Gráfico de uso de disco
            disk_data = {}
            for key, value in metrics.items():
                if "disk_" in key and "_usage_percent" in key:
                    disk_name = key.replace("disk_", "").replace("_usage_percent", "")
                    disk_data[disk_name] = value
            
            if disk_data:
                plt.figure(figsize=(10, 6))
                
                disks = list(disk_data.keys())
                usage = list(disk_data.values())
                
                plt.bar(disks, usage)
                plt.title('Disk Usage by Mount Point')
                plt.xlabel('Mount Point')
                plt.ylabel('Usage (%)')
                plt.grid(True, axis='y')
                plt.tight_layout()
                
                chart_path = REPORTS_DIR / f"disk_usage_{timestamp}.png"
                plt.savefig(chart_path)
                plt.close()
                
                charts["disk_usage"] = str(chart_path)
            
            # Gráfico de tiempo de respuesta
            response_time_data = self.get_metrics_history("virtualmin_response_time", hours=24)
            if response_time_data:
                plt.figure(figsize=(10, 6))
                
                df = pd.DataFrame(response_time_data)
                df['timestamp'] = pd.to_datetime(df['timestamp'])
                
                plt.plot(df['timestamp'], df['metric_value'])
                plt.title('Virtualmin Response Time (Last 24 Hours)')
                plt.xlabel('Time')
                plt.ylabel('Response Time (ms)')
                plt.grid(True)
                plt.tight_layout()
                
                chart_path = REPORTS_DIR / f"response_time_{timestamp}.png"
                plt.savefig(chart_path)
                plt.close()
                
                charts["response_time"] = str(chart_path)
            
            return charts
        except Exception as e:
            logger.error(f"Error al generar gráficos: {str(e)}")
            return {}
    
    def get_metrics_history(self, metric_names, hours=24):
        """Obtener historial de métricas de la base de datos"""
        try:
            if not self.db_connection:
                return []
            
            cursor = self.db_connection.cursor()
            
            # Determinar qué tabla consultar según las métricas
            table = "system_metrics"
            if "response_time" in metric_names:
                table = "performance_metrics"
            
            # Construir consulta
            metric_list = metric_names.split(', ')
            placeholders = ', '.join(['?'] * len(metric_list))
            
            query = f"""
                SELECT timestamp, metric_name, metric_value
                FROM {table}
                WHERE metric_name IN ({placeholders})
                AND timestamp >= datetime('now', '-{hours} hours')
                ORDER BY timestamp
            """
            
            cursor.execute(query, metric_list)
            rows = cursor.fetchall()
            
            # Formatear resultados
            data = []
            for row in rows:
                data.append({
                    "timestamp": row[0],
                    "metric_name": row[1],
                    "metric_value": row[2]
                })
            
            return data
        except Exception as e:
            logger.error(f"Error al obtener historial de métricas: {str(e)}")
            return []
    
    def generate_html_report(self, report_data):
        """Generar reporte en formato HTML"""
        try:
            # Crear entorno Jinja2
            env = Environment(loader=FileSystemLoader(str(SCRIPT_DIR / "templates")))
            
            # Buscar plantilla HTML
            template_path = SCRIPT_DIR / "templates" / "status_report.html"
            
            if not template_path.exists():
                # Crear plantilla por defecto si no existe
                template_path = self.create_default_html_template()
            
            # Cargar plantilla
            template = env.get_template("status_report.html")
            
            # Renderizar plantilla con datos
            html_content = template.render(report_data)
            
            # Guardar reporte
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            report_path = REPORTS_DIR / f"status_report_{timestamp}.html"
            
            with open(report_path, 'w') as f:
                f.write(html_content)
            
            logger.info(f"Reporte HTML generado: {report_path}")
            return str(report_path)
        except Exception as e:
            logger.error(f"Error al generar reporte HTML: {str(e)}")
            raise
    
    def create_default_html_template(self):
        """Crear plantilla HTML por defecto"""
        templates_dir = SCRIPT_DIR / "templates"
        os.makedirs(templates_dir, exist_ok=True)
        
        template_content = '''<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Estado - {{ project_name }}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .section {
            margin-bottom: 30px;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .section h2 {
            color: #2c3e50;
            border-bottom: 1px solid #ddd;
            padding-bottom: 10px;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding: 10px;
            border-bottom: 1px solid #eee;
        }
        .metric-name {
            font-weight: bold;
        }
        .metric-value {
            text-align: right;
        }
        .alert {
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 5px;
        }
        .alert-warning {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            color: #856404;
        }
        .alert-critical {
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
        }
        .status-active {
            color: #27ae60;
        }
        .status-inactive {
            color: #e74c3c;
        }
        .status-unknown {
            color: #f39c12;
        }
        .chart {
            margin: 20px 0;
            text-align: center;
        }
        .chart img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }
        table, th, td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
        .footer {
            margin-top: 30px;
            padding: 20px;
            text-align: center;
            border-top: 1px solid #ddd;
            color: #777;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Reporte de Estado</h1>
        <p>{{ project_name }} - {{ environment }}</p>
        <p>Fecha: {{ timestamp }}</p>
    </div>

    <div class="section">
        <h2>Resumen</h2>
        <div class="metric">
            <span class="metric-name">Estado General</span>
            <span class="metric-value">
                {% if alerts|length == 0 %}
                    <span style="color: #27ae60;">Normal</span>
                {% elif alerts|selectattr('severity', 'equalto', 'critical')|list|length > 0 %}
                    <span style="color: #e74c3c;">Crítico</span>
                {% else %}
                    <span style="color: #f39c12;">Advertencia</span>
                {% endif %}
            </span>
        </div>
        <div class="metric">
            <span class="metric-name">Alertas Activas</span>
            <span class="metric-value">{{ alerts|length }}</span>
        </div>
    </div>

    {% if alerts %}
    <div class="section">
        <h2>Alertas</h2>
        {% for alert in alerts %}
        <div class="alert alert-{{ alert.severity }}">
            <strong>{{ alert.type|title }}:</strong> {{ alert.message }}
        </div>
        {% endfor %}
    </div>
    {% endif %}

    <div class="section">
        <h2>Métricas del Sistema</h2>
        <div class="metric">
            <span class="metric-name">Uso de CPU</span>
            <span class="metric-value">{{ system_metrics.cpu_usage|round(2) }}%</span>
        </div>
        <div class="metric">
            <span class="metric-name">Uso de Memoria</span>
            <span class="metric-value">{{ system_metrics.memory_usage_percent|round(2) }}%</span>
        </div>
        <div class="metric">
            <span class="metric-name">Tiempo de Actividad</span>
            <span class="metric-value">{{ system_metrics.uptime_formatted }}</span>
        </div>
    </div>

    <div class="section">
        <h2>Métricas de Seguridad</h2>
        <div class="metric">
            <span class="metric-name">Estado del Firewall</span>
            <span class="metric-value">{{ security_metrics.firewall_status|title }}</span>
        </div>
        <div class="metric">
            <span class="metric-name">Certificados SSL Válidos</span>
            <span class="metric-value">{{ security_metrics.ssl_valid_certs }}/{{ security_metrics.ssl_total_certs }}</span>
        </div>
        <div class="metric">
            <span class="metric-name">Intentos de Inicio de Sesión Fallidos (24h)</span>
            <span class="metric-value">{{ security_metrics.failed_login_attempts_24h }}</span>
        </div>
    </div>

    <div class="section">
        <h2>Métricas de Rendimiento</h2>
        <div class="metric">
            <span class="metric-name">Tiempo de Respuesta de Virtualmin</span>
            <span class="metric-value">{{ performance_metrics.virtualmin_response_time|round(2) }}ms</span>
        </div>
        {% if performance_metrics.mysql_active %}
        <div class="metric">
            <span class="metric-name">Conexiones de Base de Datos</span>
            <span class="metric-value">{{ performance_metrics.mysql_connections }}</span>
        </div>
        {% endif %}
    </div>

    <div class="section">
        <h2>Estado de Servicios</h2>
        <table>
            <tr>
                <th>Servicio</th>
                <th>Estado</th>
                <th>Tiempo de Actividad</th>
                <th>Tiempo de Respuesta</th>
            </tr>
            {% for service, status in service_status.items() %}
            <tr>
                <td>{{ service|title }}</td>
                <td class="status-{{ status.status }}">{{ status.status|title }}</td>
                <td>{{ status.uptime }}</td>
                <td>
                    {% if status.response_time >= 0 %}
                        {{ status.response_time|round(2) }}ms
                    {% else %}
                        N/A
                    {% endif %}
                </td>
            </tr>
            {% endfor %}
        </table>
    </div>

    {% if charts %}
    <div class="section">
        <h2>Gráficos</h2>
        {% for chart_name, chart_path in charts.items() %}
        <div class="chart">
            <h3>{{ chart_name|title }}</h3>
            <img src="{{ chart_path }}" alt="{{ chart_name }}">
        </div>
        {% endfor %}
    </div>
    {% endif %}

    <div class="footer">
        <p>Reporte generado automáticamente por Virtualmin Enterprise Status Reporter</p>
    </div>
</body>
</html>'''
        
        template_path = templates_dir / "status_report.html"
        with open(template_path, 'w') as f:
            f.write(template_content)
        
        logger.info(f"Plantilla HTML por defecto creada: {template_path}")
        return templates_dir
    
    def generate_json_report(self, report_data):
        """Generar reporte en formato JSON"""
        try:
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            report_path = REPORTS_DIR / f"status_report_{timestamp}.json"
            
            with open(report_path, 'w') as f:
                json.dump(report_data, f, indent=2, default=str)
            
            logger.info(f"Reporte JSON generado: {report_path}")
            return str(report_path)
        except Exception as e:
            logger.error(f"Error al generar reporte JSON: {str(e)}")
            raise
    
    def generate_pdf_report(self, report_data):
        """Generar reporte en formato PDF"""
        try:
            # Primero generar reporte HTML
            html_report_path = self.generate_html_report(report_data)
            
            # Convertir HTML a PDF usando wkhtmltopdf
            timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            pdf_report_path = REPORTS_DIR / f"status_report_{timestamp}.pdf"
            
            try:
                subprocess.run(
                    ["wkhtmltopdf", str(html_report_path), str(pdf_report_path)],
                    capture_output=True,
                    timeout=30
                )
                
                logger.info(f"Reporte PDF generado: {pdf_report_path}")
                return str(pdf_report_path)
            except subprocess.CalledProcessError as e:
                logger.error(f"Error al convertir HTML a PDF: {str(e)}")
                logger.error("Asegúrese de que wkhtmltopdf esté instalado")
                raise
        except Exception as e:
            logger.error(f"Error al generar reporte PDF: {str(e)}")
            raise
    
    def send_email_report(self, report_path):
        """Enviar reporte por correo electrónico"""
        if not self.config["reporting"]["email"]["enabled"]:
            logger.info("Envío de correo electrónico no está habilitado")
            return
        
        try:
            import smtplib
            from email.mime.multipart import MIMEMultipart
            from email.mime.text import MIMEText
            from email.mime.base import MIMEBase
            from email import encoders
            
            # Configuración SMTP
            smtp_server = self.config["reporting"]["email"]["smtp_server"]
            smtp_port = self.config["reporting"]["email"]["smtp_port"]
            smtp_user = self.config["reporting"]["email"]["smtp_user"]
            smtp_password = self.config["reporting"]["email"]["smtp_password"]
            recipients = self.config["reporting"]["email"]["recipients"]
            
            # Crear mensaje
            msg = MIMEMultipart()
            msg['From'] = smtp_user
            msg['To'] = ', '.join(recipients)
            msg['Subject'] = f"Reporte de Estado - {self.config['general']['project_name']} - {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            
            # Cuerpo del mensaje
            body = f"""
            Se ha generado un nuevo reporte de estado para {self.config['general']['project_name']}.
            
            El reporte se adjunta a este correo electrónico.
            
            Fecha de generación: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
            Entorno: {self.config['general']['environment']}
            """
            
            msg.attach(MIMEText(body, 'plain'))
            
            # Adjuntar reporte
            with open(report_path, 'rb') as attachment:
                part = MIMEBase('application', 'octet-stream')
                part.set_payload(attachment.read())
                encoders.encode_base64(part)
                part.add_header(
                    'Content-Disposition',
                    f'attachment; filename= {os.path.basename(report_path)}'
                )
                msg.attach(part)
            
            # Enviar correo
            server = smtplib.SMTP(smtp_server, smtp_port)
            if smtp_user and smtp_password:
                server.starttls()
                server.login(smtp_user, smtp_password)
            
            server.send_message(msg)
            server.quit()
            
            logger.info(f"Reporte enviado por correo electrónico a: {', '.join(recipients)}")
        except Exception as e:
            logger.error(f"Error al enviar reporte por correo electrónico: {str(e)}")
    
    def cleanup_old_reports(self):
        """Limpiar reportes antiguos"""
        try:
            retention_days = self.config["general"]["retention_days"]
            cutoff_date = datetime.datetime.now() - datetime.timedelta(days=retention_days)
            
            for report_file in REPORTS_DIR.glob("*"):
                if report_file.is_file():
                    file_date = datetime.datetime.fromtimestamp(report_file.stat().st_mtime)
                    if file_date < cutoff_date:
                        report_file.unlink()
                        logger.info(f"Reporte antiguo eliminado: {report_file}")
            
            # Limpiar métricas antiguas de la base de datos
            if self.db_connection:
                cursor = self.db_connection.cursor()
                
                # Eliminar métricas antiguas
                cursor.execute("DELETE FROM system_metrics WHERE timestamp < datetime(?, '-{} days')".format(retention_days), (cutoff_date,))
                cursor.execute("DELETE FROM security_metrics WHERE timestamp < datetime(?, '-{} days')".format(retention_days), (cutoff_date,))
                cursor.execute("DELETE FROM performance_metrics WHERE timestamp < datetime(?, '-{} days')".format(retention_days), (cutoff_date,))
                cursor.execute("DELETE FROM service_status WHERE timestamp < datetime(?, '-{} days')".format(retention_days), (cutoff_date,))
                
                self.db_connection.commit()
                logger.info("Métricas antiguas eliminadas de la base de datos")
        except Exception as e:
            logger.error(f"Error al limpiar reportes antiguos: {str(e)}")
    
    def run(self, format_types=None, send_email=False):
        """Ejecutar el generador de reportes"""
        if format_types is None:
            format_types = self.config["reporting"]["formats"]
        
        logger.info(f"Iniciando generación de reportes en formatos: {', '.join(format_types)}")
        
        report_paths = []
        
        # Generar reportes en cada formato solicitado
        for format_type in format_types:
            try:
                report_path = self.generate_report(format_type)
                report_paths.append(report_path)
                
                # Enviar reporte por correo electrónico si está habilitado
                if send_email:
                    self.send_email_report(report_path)
            except Exception as e:
                logger.error(f"Error al generar reporte en formato {format_type}: {str(e)}")
        
        # Limpiar reportes antiguos
        self.cleanup_old_reports()
        
        logger.info(f"Generación de reportes completada. Reportes generados: {', '.join(report_paths)}")
        return report_paths


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(description='Generador de Reportes de Estado de Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default=str(CONFIG_FILE))
    parser.add_argument('--format', help='Formato del reporte (html, json, pdf)', choices=['html', 'json', 'pdf'], nargs='+')
    parser.add_argument('--email', help='Enviar reporte por correo electrónico', action='store_true')
    parser.add_argument('--cleanup-only', help='Solo limpiar reportes antiguos', action='store_true')
    
    args = parser.parse_args()
    
    # Crear generador de reportes
    generator = StatusReportGenerator(args.config)
    
    # Ejecutar solo limpieza si se solicita
    if args.cleanup_only:
        generator.cleanup_old_reports()
        return
    
    # Generar reportes
    generator.run(args.format, args.email)


if __name__ == "__main__":
    main()