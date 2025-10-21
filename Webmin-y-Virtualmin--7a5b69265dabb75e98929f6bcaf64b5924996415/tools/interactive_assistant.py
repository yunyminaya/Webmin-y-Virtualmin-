#!/usr/bin/env python3

# Sistema de Asistentes Interactivos y Scripts de Autodiagnóstico
# para Virtualmin Enterprise

import json
import os
import sys
import time
import subprocess
import logging
import sqlite3
import re
import textwrap
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import argparse
import signal

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/interactive_assistant.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class Color:
    """Códigos de color para la terminal"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

class InteractiveAssistant:
    def __init__(self, config_file=None):
        """Inicializar el asistente interactivo"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/assistant/assistant.db')
        self.commands_dir = self.config.get('commands', {}).get('path', '/opt/virtualmin-enterprise/assistant/commands')
        self.reports_dir = self.config.get('reports', {}).get('path', '/opt/virtualmin-enterprise/assistant/reports')
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
        
        # Cargar comandos disponibles
        self.load_commands()
        
        # Estado del asistente
        self.running = True
        self.current_context = {}
        self.history = []
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/assistant/assistant.db"
            },
            "commands": {
                "path": "/opt/virtualmin-enterprise/assistant/commands"
            },
            "reports": {
                "path": "/opt/virtualmin-enterprise/assistant/reports"
            },
            "system": {
                "virtualmin_path": "/usr/share/webmin",
                "config_path": "/etc/webmin",
                "log_path": "/var/webmin"
            },
            "services": [
                "webmin",
                "virtualmin",
                "apache2",
                "nginx",
                "mysql",
                "postgresql",
                "postfix",
                "dovecot"
            ],
            "security": {
                "check_vulnerabilities": True,
                "check_permissions": True,
                "check_ssl": True
            },
            "monitoring": {
                "check_services": True,
                "check_resources": True,
                "check_logs": True
            },
            "backup": {
                "check_backups": True,
                "verify_backups": True
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
            '/opt/virtualmin-enterprise/assistant',
            os.path.dirname(self.db_path),
            self.commands_dir,
            self.reports_dir,
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
            
            # Crear tabla de diagnósticos
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS diagnostics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    diagnostic_id TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL,
                    category TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    duration INTEGER,
                    results TEXT,
                    recommendations TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de comandos
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS commands (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    command_id TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL,
                    description TEXT,
                    category TEXT NOT NULL,
                    command TEXT NOT NULL,
                    parameters TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de problemas comunes
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS common_issues (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    issue_id TEXT UNIQUE NOT NULL,
                    title TEXT NOT NULL,
                    description TEXT,
                    symptoms TEXT,
                    causes TEXT,
                    solutions TEXT,
                    category TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de historial
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    command TEXT NOT NULL,
                    response TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    
    def load_commands(self):
        """Cargar comandos disponibles"""
        try:
            self.commands = {}
            
            # Cargar comandos predefinidos
            self.load_predefined_commands()
            
            # Cargar comandos personalizados desde la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('SELECT * FROM commands')
            
            for row in cursor.fetchall():
                command_id = row['command_id']
                self.commands[command_id] = {
                    'name': row['name'],
                    'description': row['description'],
                    'category': row['category'],
                    'command': row['command'],
                    'parameters': json.loads(row['parameters']) if row['parameters'] else {}
                }
            
            conn.close()
            
            logger.info(f"Comandos cargados: {len(self.commands)}")
            return True
        except Exception as e:
            logger.error(f"Error al cargar comandos: {e}")
            return False
    
    def load_predefined_commands(self):
        """Cargar comandos predefinidos"""
        try:
            # Comandos de diagnóstico
            self.commands['diagnose_all'] = {
                'name': 'Diagnóstico Completo',
                'description': 'Realizar un diagnóstico completo del sistema',
                'category': 'diagnostic',
                'command': 'diagnose_all',
                'parameters': {}
            }
            
            self.commands['diagnose_services'] = {
                'name': 'Diagnóstico de Servicios',
                'description': 'Verificar el estado de todos los servicios',
                'category': 'diagnostic',
                'command': 'diagnose_services',
                'parameters': {}
            }
            
            self.commands['diagnose_security'] = {
                'name': 'Diagnóstico de Seguridad',
                'description': 'Realizar un análisis de seguridad del sistema',
                'category': 'diagnostic',
                'command': 'diagnose_security',
                'parameters': {}
            }
            
            self.commands['diagnose_performance'] = {
                'name': 'Diagnóstico de Rendimiento',
                'description': 'Analizar el rendimiento del sistema',
                'category': 'diagnostic',
                'command': 'diagnose_performance',
                'parameters': {}
            }
            
            self.commands['diagnose_network'] = {
                'name': 'Diagnóstico de Red',
                'description': 'Verificar la configuración y estado de la red',
                'category': 'diagnostic',
                'command': 'diagnose_network',
                'parameters': {}
            }
            
            # Comandos de reparación
            self.commands['fix_permissions'] = {
                'name': 'Reparar Permisos',
                'description': 'Reparar permisos de archivos y directorios',
                'category': 'repair',
                'command': 'fix_permissions',
                'parameters': {}
            }
            
            self.commands['fix_services'] = {
                'name': 'Reparar Servicios',
                'description': 'Intentar reparar servicios caídos',
                'category': 'repair',
                'command': 'fix_services',
                'parameters': {}
            }
            
            self.commands['fix_ssl'] = {
                'name': 'Reparar Certificados SSL',
                'description': 'Reparar problemas con certificados SSL',
                'category': 'repair',
                'command': 'fix_ssl',
                'parameters': {}
            }
            
            # Comandos de información
            self.commands['info_system'] = {
                'name': 'Información del Sistema',
                'description': 'Mostrar información detallada del sistema',
                'category': 'info',
                'command': 'info_system',
                'parameters': {}
            }
            
            self.commands['info_services'] = {
                'name': 'Información de Servicios',
                'description': 'Mostrar información detallada de los servicios',
                'category': 'info',
                'command': 'info_services',
                'parameters': {}
            }
            
            self.commands['info_logs'] = {
                'name': 'Información de Logs',
                'description': 'Mostrar información de los logs del sistema',
                'category': 'info',
                'command': 'info_logs',
                'parameters': {}
            }
            
            # Comandos de utilidad
            self.commands['help'] = {
                'name': 'Ayuda',
                'description': 'Mostrar ayuda sobre comandos disponibles',
                'category': 'utility',
                'command': 'help',
                'parameters': {}
            }
            
            self.commands['exit'] = {
                'name': 'Salir',
                'description': 'Salir del asistente interactivo',
                'category': 'utility',
                'command': 'exit',
                'parameters': {}
            }
            
            self.commands['clear'] = {
                'name': 'Limpiar Pantalla',
                'description': 'Limpiar la pantalla de la terminal',
                'category': 'utility',
                'command': 'clear',
                'parameters': {}
            }
            
            self.commands['history'] = {
                'name': 'Historial',
                'description': 'Mostrar el historial de comandos',
                'category': 'utility',
                'command': 'history',
                'parameters': {}
            }
            
            return True
        except Exception as e:
            logger.error(f"Error al cargar comandos predefinidos: {e}")
            return False
    
    def run_command(self, command_id, parameters=None):
        """Ejecutar un comando"""
        try:
            if command_id not in self.commands:
                return {
                    'success': False,
                    'message': f"Comando no encontrado: {command_id}"
                }
            
            command = self.commands[command_id]
            
            # Guardar en historial
            self.history.append({
                'command': command_id,
                'parameters': parameters,
                'timestamp': datetime.now()
            })
            
            # Ejecutar comando según tipo
            if command['category'] == 'diagnostic':
                result = self.run_diagnostic_command(command['command'], parameters)
            elif command['category'] == 'repair':
                result = self.run_repair_command(command['command'], parameters)
            elif command['category'] == 'info':
                result = self.run_info_command(command['command'], parameters)
            elif command['category'] == 'utility':
                result = self.run_utility_command(command['command'], parameters)
            else:
                result = {
                    'success': False,
                    'message': f"Categoría de comando no soportada: {command['category']}"
                }
            
            return result
        except Exception as e:
            logger.error(f"Error al ejecutar comando: {e}")
            return {
                'success': False,
                'message': f"Error al ejecutar comando: {str(e)}"
            }
    
    def run_diagnostic_command(self, command, parameters=None):
        """Ejecutar un comando de diagnóstico"""
        try:
            if command == 'diagnose_all':
                return self.diagnose_all()
            elif command == 'diagnose_services':
                return self.diagnose_services()
            elif command == 'diagnose_security':
                return self.diagnose_security()
            elif command == 'diagnose_performance':
                return self.diagnose_performance()
            elif command == 'diagnose_network':
                return self.diagnose_network()
            else:
                return {
                    'success': False,
                    'message': f"Comando de diagnóstico no soportado: {command}"
                }
        except Exception as e:
            logger.error(f"Error al ejecutar comando de diagnóstico: {e}")
            return {
                'success': False,
                'message': f"Error al ejecutar comando de diagnóstico: {str(e)}"
            }
    
    def diagnose_all(self):
        """Realizar un diagnóstico completo del sistema"""
        try:
            # Generar ID único para el diagnóstico
            diagnostic_id = f"diagnose_all_{int(time.time())}"
            
            # Registrar diagnóstico en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO diagnostics (diagnostic_id, name, category, start_time)
                VALUES (?, ?, ?, ?)
            ''', (
                diagnostic_id,
                'Diagnóstico Completo',
                'comprehensive',
                datetime.now()
            ))
            
            conn.commit()
            conn.close()
            
            # Mostrar mensaje de inicio
            print(f"{Color.CYAN}Iniciando diagnóstico completo del sistema...{Color.END}")
            print(f"{Color.CYAN}ID de diagnóstico: {diagnostic_id}{Color.END}")
            print()
            
            # Ejecutar diagnósticos individuales
            results = {}
            
            # Diagnóstico de servicios
            print(f"{Color.YELLOW}1. Diagnóstico de servicios{Color.END}")
            services_result = self.diagnose_services()
            results['services'] = services_result
            print()
            
            # Diagnóstico de seguridad
            print(f"{Color.YELLOW}2. Diagnóstico de seguridad{Color.END}")
            security_result = self.diagnose_security()
            results['security'] = security_result
            print()
            
            # Diagnóstico de rendimiento
            print(f"{Color.YELLOW}3. Diagnóstico de rendimiento{Color.END}")
            performance_result = self.diagnose_performance()
            results['performance'] = performance_result
            print()
            
            # Diagnóstico de red
            print(f"{Color.YELLOW}4. Diagnóstico de red{Color.END}")
            network_result = self.diagnose_network()
            results['network'] = network_result
            print()
            
            # Generar recomendaciones
            recommendations = self.generate_recommendations(results)
            
            # Actualizar diagnóstico en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                UPDATE diagnostics SET status = ?, end_time = ?, results = ?, recommendations = ?
                WHERE diagnostic_id = ?
            ''', (
                'completed',
                datetime.now(),
                json.dumps(results),
                json.dumps(recommendations),
                diagnostic_id
            ))
            
            conn.commit()
            conn.close()
            
            # Mostrar resumen
            print(f"{Color.GREEN}Diagnóstico completo finalizado{Color.END}")
            print(f"{Color.GREEN}ID de diagnóstico: {diagnostic_id}{Color.END}")
            
            # Mostrar recomendaciones
            if recommendations:
                print(f"{Color.MAGENTA}Recomendaciones:{Color.END}")
                for i, recommendation in enumerate(recommendations, 1):
                    print(f"{Color.MAGENTA}{i}. {recommendation['title']}{Color.END}")
                    print(f"{Color.MAGENTA}   {recommendation['description']}{Color.END}")
                    print()
            
            # Generar informe
            report_file = self.generate_diagnostic_report(diagnostic_id, results, recommendations)
            
            if report_file:
                print(f"{Color.CYAN}Informe generado: {report_file}{Color.END}")
            
            return {
                'success': True,
                'diagnostic_id': diagnostic_id,
                'results': results,
                'recommendations': recommendations,
                'report_file': report_file
            }
        except Exception as e:
            logger.error(f"Error en diagnóstico completo: {e}")
            return {
                'success': False,
                'message': f"Error en diagnóstico completo: {str(e)}"
            }
    
    def diagnose_services(self):
        """Verificar el estado de todos los servicios"""
        try:
            results = {
                'services': {},
                'summary': {
                    'total': len(self.config['services']),
                    'running': 0,
                    'stopped': 0,
                    'failed': 0
                }
            }
            
            for service in self.config['services']:
                try:
                    # Verificar estado del servicio
                    result = subprocess.run(
                        ['systemctl', 'is-active', service],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    status = result.stdout.strip()
                    
                    if status == 'active':
                        results['summary']['running'] += 1
                        status_icon = f"{Color.GREEN}✓{Color.END}"
                    else:
                        results['summary']['stopped'] += 1
                        status_icon = f"{Color.RED}✗{Color.END}"
                    
                    # Obtener información adicional
                    info_result = subprocess.run(
                        ['systemctl', 'show', service, '--property=Description,LoadState,ActiveState,SubState'],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    info_lines = info_result.stdout.strip().split('\n')
                    info = {}
                    
                    for line in info_lines:
                        if '=' in line:
                            key, value = line.split('=', 1)
                            info[key] = value
                    
                    results['services'][service] = {
                        'status': status,
                        'info': info,
                        'success': status == 'active'
                    }
                    
                    # Mostrar resultado
                    print(f"   {status_icon} {service}: {status}")
                    if 'Description' in info:
                        print(f"      {info['Description']}")
                    
                except subprocess.TimeoutExpired:
                    results['services'][service] = {
                        'status': 'timeout',
                        'info': {},
                        'success': False
                    }
                    results['summary']['failed'] += 1
                    
                    print(f"   {Color.RED}✗{Color.END} {service}: Timeout")
                except Exception as e:
                    results['services'][service] = {
                        'status': 'error',
                        'info': {},
                        'error': str(e),
                        'success': False
                    }
                    results['summary']['failed'] += 1
                    
                    print(f"   {Color.RED}✗{Color.END} {service}: Error - {str(e)}")
            
            # Mostrar resumen
            print(f"   Resumen: {results['summary']['running']} en ejecución, {results['summary']['stopped']} detenidos, {results['summary']['failed']} con errores")
            
            return {
                'success': True,
                'results': results
            }
        except Exception as e:
            logger.error(f"Error en diagnóstico de servicios: {e}")
            return {
                'success': False,
                'message': f"Error en diagnóstico de servicios: {str(e)}"
            }
    
    def diagnose_security(self):
        """Realizar un análisis de seguridad del sistema"""
        try:
            results = {
                'ssl': {},
                'permissions': {},
                'firewall': {},
                'vulnerabilities': {},
                'summary': {
                    'checks_performed': 0,
                    'issues_found': 0,
                    'warnings': 0
                }
            }
            
            # Verificar certificados SSL
            print(f"   Verificando certificados SSL...")
            ssl_result = self.check_ssl_certificates()
            results['ssl'] = ssl_result
            results['summary']['checks_performed'] += 1
            
            if ssl_result['issues']:
                results['summary']['issues_found'] += len(ssl_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(ssl_result['issues'])} problemas con certificados SSL{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas con certificados SSL{Color.END}")
            
            # Verificar permisos
            print(f"   Verificando permisos...")
            permissions_result = self.check_permissions()
            results['permissions'] = permissions_result
            results['summary']['checks_performed'] += 1
            
            if permissions_result['issues']:
                results['summary']['issues_found'] += len(permissions_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(permissions_result['issues'])} problemas de permisos{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de permisos{Color.END}")
            
            # Verificar firewall
            print(f"   Verificando firewall...")
            firewall_result = self.check_firewall()
            results['firewall'] = firewall_result
            results['summary']['checks_performed'] += 1
            
            if firewall_result['issues']:
                results['summary']['issues_found'] += len(firewall_result['issues'])
                print(f"   {Color.YELLOW}Se encontraron {len(firewall_result['issues'])} advertencias de firewall{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas con el firewall{Color.END}")
            
            # Verificar vulnerabilidades
            print(f"   Verificando vulnerabilidades...")
            vulnerabilities_result = self.check_vulnerabilities()
            results['vulnerabilities'] = vulnerabilities_result
            results['summary']['checks_performed'] += 1
            
            if vulnerabilities_result['issues']:
                results['summary']['issues_found'] += len(vulnerabilities_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(vulnerabilities_result['issues'])} vulnerabilidades{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron vulnerabilidades críticas{Color.END}")
            
            # Mostrar resumen
            print(f"   Resumen: {results['summary']['checks_performed']} verificaciones realizadas, {results['summary']['issues_found']} problemas encontrados")
            
            return {
                'success': True,
                'results': results
            }
        except Exception as e:
            logger.error(f"Error en diagnóstico de seguridad: {e}")
            return {
                'success': False,
                'message': f"Error en diagnóstico de seguridad: {str(e)}"
            }
    
    def check_ssl_certificates(self):
        """Verificar certificados SSL"""
        try:
            result = {
                'certificates': {},
                'issues': [],
                'summary': {
                    'total': 0,
                    'valid': 0,
                    'expired': 0,
                    'expiring_soon': 0
                }
            }
            
            # Buscar certificados SSL en ubicaciones comunes
            cert_paths = [
                '/etc/ssl/certs',
                '/etc/apache2/ssl',
                '/etc/nginx/ssl',
                '/etc/postfix/ssl',
                '/etc/dovecot/ssl'
            ]
            
            for cert_path in cert_paths:
                if os.path.exists(cert_path):
                    for cert_file in os.listdir(cert_path):
                        if cert_file.endswith('.crt') or cert_file.endswith('.pem'):
                            cert_full_path = os.path.join(cert_path, cert_file)
                            
                            try:
                                # Verificar certificado
                                cmd = [
                                    'openssl', 'x509',
                                    '-in', cert_full_path,
                                    '-noout',
                                    '-dates'
                                ]
                                
                                openssl_result = subprocess.run(
                                    cmd,
                                    capture_output=True,
                                    text=True,
                                    timeout=10
                                )
                                
                                if openssl_result.returncode == 0:
                                    # Extraer fechas
                                    not_before = ''
                                    not_after = ''
                                    
                                    for line in openssl_result.stdout.split('\n'):
                                        if line.startswith('notBefore='):
                                            not_before = line.split('=', 1)[1]
                                        elif line.startswith('notAfter='):
                                            not_after = line.split('=', 1)[1]
                                    
                                    # Convertir fechas a objetos datetime
                                    not_before_dt = datetime.strptime(not_before, '%b %d %H:%M:%S %Y %Z')
                                    not_after_dt = datetime.strptime(not_after, '%b %d %H:%M:%S %Y %Z')
                                    
                                    # Verificar si el certificado está expirado o expirará pronto
                                    now = datetime.now()
                                    days_until_expiry = (not_after_dt - now).days
                                    
                                    result['summary']['total'] += 1
                                    
                                    if days_until_expiry < 0:
                                        result['summary']['expired'] += 1
                                        result['issues'].append({
                                            'type': 'expired_certificate',
                                            'path': cert_full_path,
                                            'message': f"El certificado ha expirado hace {abs(days_until_expiry)} días"
                                        })
                                    elif days_until_expiry < 30:
                                        result['summary']['expiring_soon'] += 1
                                        result['issues'].append({
                                            'type': 'expiring_soon_certificate',
                                            'path': cert_full_path,
                                            'message': f"El certificado expirará en {days_until_expiry} días"
                                        })
                                    else:
                                        result['summary']['valid'] += 1
                                    
                                    result['certificates'][cert_full_path] = {
                                        'not_before': not_before,
                                        'not_after': not_after,
                                        'days_until_expiry': days_until_expiry,
                                        'valid': days_until_expiry > 0
                                    }
                            except Exception as e:
                                result['issues'].append({
                                    'type': 'certificate_error',
                                    'path': cert_full_path,
                                    'message': f"Error al verificar certificado: {str(e)}"
                                })
            return result
        except Exception as e:
            logger.error(f"Error al verificar certificados SSL: {e}")
            return {
                'certificates': {},
                'issues': [{
                    'type': 'ssl_check_error',
                    'message': f"Error al verificar certificados SSL: {str(e)}"
                }]
            }
    
    def check_permissions(self):
        """Verificar permisos de archivos y directorios críticos"""
        try:
            result = {
                'files': {},
                'issues': [],
                'summary': {
                    'total': 0,
                    'correct': 0,
                    'incorrect': 0
                }
            }
            
            # Lista de archivos y directorios críticos y sus permisos esperados
            critical_paths = [
                {'path': '/etc/passwd', 'expected_perms': '644'},
                {'path': '/etc/shadow', 'expected_perms': '600'},
                {'path': '/etc/group', 'expected_perms': '644'},
                {'path': '/etc/gshadow', 'expected_perms': '600'},
                {'path': '/etc/ssh/sshd_config', 'expected_perms': '600'},
                {'path': '/etc/ssh/ssh_host_rsa_key', 'expected_perms': '600'},
                {'path': '/etc/ssh/ssh_host_rsa_key.pub', 'expected_perms': '644'},
                {'path': '/var/www', 'expected_perms': '755'},
                {'path': '/var/log', 'expected_perms': '755'},
                {'path': '/etc/webmin', 'expected_perms': '755'}
            ]
            
            for item in critical_paths:
                path = item['path']
                expected_perms = item['expected_perms']
                
                if os.path.exists(path):
                    try:
                        # Obtener permisos actuales
                        stat_info = os.stat(path)
                        current_perms = oct(stat_info.st_mode)[-3:]
                        
                        result['summary']['total'] += 1
                        
                        if current_perms != expected_perms:
                            result['summary']['incorrect'] += 1
                            
                            result['issues'].append({
                                'type': 'incorrect_permissions',
                                'path': path,
                                'current_perms': current_perms,
                                'expected_perms': expected_perms,
                                'message': f"Permisos incorrectos: {current_perms} (esperado: {expected_perms})"
                            })
                            
                            result['files'][path] = {
                                'current_perms': current_perms,
                                'expected_perms': expected_perms,
                                'correct': False
                            }
                        else:
                            result['summary']['correct'] += 1
                            
                            result['files'][path] = {
                                'current_perms': current_perms,
                                'expected_perms': expected_perms,
                                'correct': True
                            }
                    except Exception as e:
                        result['issues'].append({
                            'type': 'permission_check_error',
                            'path': path,
                            'message': f"Error al verificar permisos: {str(e)}"
                        })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar permisos: {e}")
            return {
                'files': {},
                'issues': [{
                    'type': 'permissions_check_error',
                    'message': f"Error al verificar permisos: {str(e)}"
                }]
            }
    
    def check_firewall(self):
        """Verificar estado del firewall"""
        try:
            result = {
                'status': 'unknown',
                'rules': {},
                'issues': [],
                'summary': {
                    'total_rules': 0,
                    'active_rules': 0
                }
            }
            
            # Verificar si UFW está disponible
            try:
                ufw_status = subprocess.run(
                    ['ufw', 'status'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if ufw_status.returncode == 0:
                    # Analizar estado de UFW
                    status_lines = ufw_status.stdout.split('\n')
                    
                    for line in status_lines:
                        line = line.strip()
                        
                        if line == 'Status: active':
                            result['status'] = 'active'
                        elif line == 'Status: inactive':
                            result['status'] = 'inactive'
                            result['issues'].append({
                                'type': 'firewall_inactive',
                                'message': 'El firewall está inactivo'
                            })
                        elif line.startswith('[ ') and 'ALLOW' in line:
                            # Extraer regla permitida
                            rule_match = re.match(r'\[ (\d+)\] (.*)', line)
                            if rule_match:
                                rule_id = rule_match.group(1)
                                rule_description = rule_match.group(2)
                                
                                result['summary']['total_rules'] += 1
                                result['summary']['active_rules'] += 1
                                
                                result['rules'][rule_id] = {
                                    'action': 'ALLOW',
                                    'description': rule_description,
                                    'active': True
                                }
                        elif line.startswith('[ ') and 'DENY' in line:
                            # Extraer regla denegada
                            rule_match = re.match(r'\[ (\d+)\] (.*)', line)
                            if rule_match:
                                rule_id = rule_match.group(1)
                                rule_description = rule_match.group(2)
                                
                                result['summary']['total_rules'] += 1
                                result['summary']['active_rules'] += 1
                                
                                result['rules'][rule_id] = {
                                    'action': 'DENY',
                                    'description': rule_description,
                                    'active': True
                                }
            except subprocess.TimeoutExpired:
                result['issues'].append({
                    'type': 'firewall_check_timeout',
                    'message': 'Timeout al verificar estado del firewall'
                })
            except FileNotFoundError:
                # UFW no está disponible, intentar con iptables
                try:
                    iptables_result = subprocess.run(
                        ['iptables', '-L', '-n'],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    if iptables_result.returncode == 0:
                        result['status'] = 'iptables'
                        
                        # Contar reglas de iptables
                        rules_count = len([line for line in iptables_result.stdout.split('\n') if line.strip()])
                        
                        result['summary']['total_rules'] = rules_count
                        result['summary']['active_rules'] = rules_count
                except Exception as e:
                    result['issues'].append({
                        'type': 'firewall_check_error',
                        'message': f"Error al verificar iptables: {str(e)}"
                    })
            except Exception as e:
                result['issues'].append({
                    'type': 'firewall_check_error',
                    'message': f"Error al verificar firewall: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar firewall: {e}")
            return {
                'status': 'error',
                'issues': [{
                    'type': 'firewall_check_error',
                    'message': f"Error al verificar firewall: {str(e)}"
                }]
            }
    
    def check_vulnerabilities(self):
        """Verificar vulnerabilidades del sistema"""
        try:
            result = {
                'vulnerabilities': [],
                'summary': {
                    'total': 0,
                    'critical': 0,
                    'high': 0,
                    'medium': 0,
                    'low': 0
                }
            }
            
            # Verificar si hay actualizaciones de seguridad pendientes
            try:
                # Para sistemas basados en Debian/Ubuntu
                update_result = subprocess.run(
                    ['apt', 'list', '--upgradable'],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if update_result.returncode == 0:
                    # Analizar actualizaciones pendientes
                    for line in update_result.stdout.split('\n'):
                        if line.strip() and '/' in line:
                            parts = line.split()
                            
                            if len(parts) >= 3:
                                package_name = parts[0]
                                current_version = parts[1]
                                new_version = parts[2]
                                
                                # Verificar si es una actualización de seguridad
                                if '-security' in line or 'security' in package_name.lower():
                                    result['summary']['total'] += 1
                                    result['summary']['medium'] += 1
                                    
                                    result['vulnerabilities'].append({
                                        'type': 'security_update',
                                        'package': package_name,
                                        'current_version': current_version,
                                        'new_version': new_version,
                                        'severity': 'medium',
                                        'message': f"Actualización de seguridad disponible para {package_name}"
                                    })
            except subprocess.TimeoutExpired:
                result['vulnerabilities'].append({
                    'type': 'vulnerability_check_timeout',
                    'message': 'Timeout al verificar actualizaciones de seguridad'
                })
            except FileNotFoundError:
                # apt no está disponible, intentar con yum para sistemas basados en RedHat/CentOS
                try:
                    update_result = subprocess.run(
                        ['yum', 'check-update', 'security'],
                        capture_output=True,
                        text=True,
                        timeout=30
                    )
                    
                    if update_result.returncode == 0:
                        # Analizar actualizaciones de seguridad
                        for line in update_result.stdout.split('\n'):
                            if line.strip() and not line.startswith('Last metadata') and not line.startswith('Security'):
                                parts = line.split()
                                
                                if len(parts) >= 3:
                                    package_name = parts[0]
                                    current_version = parts[1]
                                    repo = parts[2] if len(parts) > 2 else ''
                                    
                                    if repo == 'security':
                                        result['summary']['total'] += 1
                                        result['summary']['medium'] += 1
                                        
                                        result['vulnerabilities'].append({
                                            'type': 'security_update',
                                            'package': package_name,
                                            'current_version': current_version,
                                            'new_version': repo,
                                            'severity': 'medium',
                                            'message': f"Actualización de seguridad disponible para {package_name}"
                                        })
                except Exception as e:
                    result['vulnerabilities'].append({
                        'type': 'vulnerability_check_error',
                        'message': f"Error al verificar actualizaciones de seguridad con yum: {str(e)}"
                    })
            except Exception as e:
                result['vulnerabilities'].append({
                    'type': 'vulnerability_check_error',
                    'message': f"Error al verificar actualizaciones de seguridad: {str(e)}"
                })
            
            # Verificar usuarios con UID 0 (root)
            try:
                passwd_result = subprocess.run(
                    ['grep', ':0:', '/etc/passwd'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if passwd_result.returncode == 0:
                    root_users = passwd_result.stdout.strip().split('\n')
                    
                    if len(root_users) > 1:
                        result['summary']['total'] += 1
                        result['summary']['high'] += 1
                        
                        result['vulnerabilities'].append({
                            'type': 'multiple_root_users',
                            'users': root_users,
                            'severity': 'high',
                            'message': f"Múltiples usuarios con UID 0: {', '.join(root_users)}"
                        })
            except Exception as e:
                result['vulnerabilities'].append({
                    'type': 'root_users_check_error',
                    'message': f"Error al verificar usuarios con UID 0: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar vulnerabilidades: {e}")
            return {
                'vulnerabilities': [{
                    'type': 'vulnerability_check_error',
                    'message': f"Error al verificar vulnerabilidades: {str(e)}"
                }]
            }
    
    def diagnose_performance(self):
        """Analizar el rendimiento del sistema"""
        try:
            results = {
                'cpu': {},
                'memory': {},
                'disk': {},
                'network': {},
                'summary': {
                    'checks_performed': 0,
                    'issues_found': 0,
                    'warnings': 0
                }
            }
            
            # Verificar uso de CPU
            print(f"   Verificando uso de CPU...")
            cpu_result = self.check_cpu_usage()
            results['cpu'] = cpu_result
            results['summary']['checks_performed'] += 1
            
            if cpu_result['issues']:
                results['summary']['issues_found'] += len(cpu_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(cpu_result['issues'])} problemas de CPU{Color.END}")
            elif cpu_result['warnings']:
                results['summary']['warnings'] += len(cpu_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(cpu_result['warnings'])} advertencias de CPU{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de CPU{Color.END}")
            
            # Verificar uso de memoria
            print(f"   Verificando uso de memoria...")
            memory_result = self.check_memory_usage()
            results['memory'] = memory_result
            results['summary']['checks_performed'] += 1
            
            if memory_result['issues']:
                results['summary']['issues_found'] += len(memory_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(memory_result['issues'])} problemas de memoria{Color.END}")
            elif memory_result['warnings']:
                results['summary']['warnings'] += len(memory_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(memory_result['warnings'])} advertencias de memoria{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de memoria{Color.END}")
            
            # Verificar uso de disco
            print(f"   Verificando uso de disco...")
            disk_result = self.check_disk_usage()
            results['disk'] = disk_result
            results['summary']['checks_performed'] += 1
            
            if disk_result['issues']:
                results['summary']['issues_found'] += len(disk_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(disk_result['issues'])} problemas de disco{Color.END}")
            elif disk_result['warnings']:
                results['summary']['warnings'] += len(disk_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(disk_result['warnings'])} advertencias de disco{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de disco{Color.END}")
            
            # Verificar uso de red
            print(f"   Verificando uso de red...")
            network_result = self.check_network_usage()
            results['network'] = network_result
            results['summary']['checks_performed'] += 1
            
            if network_result['issues']:
                results['summary']['issues_found'] += len(network_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(network_result['issues'])} problemas de red{Color.END}")
            elif network_result['warnings']:
                results['summary']['warnings'] += len(network_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(network_result['warnings'])} advertencias de red{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de red{Color.END}")
            
            # Mostrar resumen
            print(f"   Resumen: {results['summary']['checks_performed']} verificaciones realizadas, {results['summary']['issues_found']} problemas encontrados")
            
            return {
                'success': True,
                'results': results
            }
        except Exception as e:
            logger.error(f"Error en diagnóstico de rendimiento: {e}")
            return {
                'success': False,
                'message': f"Error en diagnóstico de rendimiento: {str(e)}"
            }
    
    def check_cpu_usage(self):
        """Verificar uso de CPU"""
        try:
            result = {
                'usage': 0,
                'load_average': {},
                'processes': {},
                'issues': [],
                'warnings': []
            }
            
            # Obtener uso de CPU
            try:
                cpu_result = subprocess.run(
                    ['top', '-bn1', '|', 'grep', 'Cpu(s)'],
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if cpu_result.returncode == 0:
                    # Analizar salida de top
                    cpu_line = cpu_result.stdout.strip()
                    
                    # Extraer porcentaje de uso de CPU
                    cpu_match = re.search(r'(\d+\.?\d*)\s*%us', cpu_line)
                    if cpu_match:
                        result['usage'] = float(cpu_match.group(1))
                        
                        # Verificar si el uso de CPU es alto
                        if result['usage'] > 90:
                            result['issues'].append({
                                'type': 'high_cpu_usage',
                                'value': result['usage'],
                                'message': f"Uso de CPU muy alto: {result['usage']:.2f}%"
                            })
                        elif result['usage'] > 70:
                            result['warnings'].append({
                                'type': 'moderate_cpu_usage',
                                'value': result['usage'],
                                'message': f"Uso de CPU moderadamente alto: {result['usage']:.2f}%"
                            })
            except Exception as e:
                result['issues'].append({
                    'type': 'cpu_usage_check_error',
                    'message': f"Error al verificar uso de CPU: {str(e)}"
                })
            
            # Obtener carga promedio
            try:
                load_result = subprocess.run(
                    ['cat', '/proc/loadavg'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if load_result.returncode == 0:
                    load_values = load_result.stdout.strip().split()[:3]
                    
                    result['load_average'] = {
                        '1min': float(load_values[0]),
                        '5min': float(load_values[1]),
                        '15min': float(load_values[2])
                    }
                    
                    # Obtener número de núcleos
                    cpu_cores = os.cpu_count()
                    
                    # Verificar si la carga es alta
                    if result['load_average']['1min'] > cpu_cores * 2:
                        result['issues'].append({
                            'type': 'high_load_average',
                            'value': result['load_average']['1min'],
                            'cpu_cores': cpu_cores,
                            'message': f"Carga promedio alta: {result['load_average']['1min']:.2f} (núcleos: {cpu_cores})"
                        })
                    elif result['load_average']['1min'] > cpu_cores:
                        result['warnings'].append({
                            'type': 'moderate_load_average',
                            'value': result['load_average']['1min'],
                            'cpu_cores': cpu_cores,
                            'message': f"Carga promedio moderadamente alta: {result['load_average']['1min']:.2f} (núcleos: {cpu_cores})"
                        })
            except Exception as e:
                result['issues'].append({
                    'type': 'load_average_check_error',
                    'message': f"Error al verificar carga promedio: {str(e)}"
                })
            
            # Obtener procesos que más consumen CPU
            try:
                ps_result = subprocess.run(
                    ['ps', '-eo', 'pid,pcpu,comm', '--sort=-pcpu', '|', 'head', '-10'],
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if ps_result.returncode == 0:
                    lines = ps_result.stdout.strip().split('\n')
                    
                    # Omitir la primera línea (encabezado)
                    for line in lines[1:]:
                        parts = line.split(None, 2)
                        
                        if len(parts) >= 3:
                            pid = parts[0]
                            cpu_percentage = parts[1]
                            command = parts[2]
                            
                            result['processes'][pid] = {
                                'cpu_percentage': float(cpu_percentage),
                                'command': command
                            }
            except Exception as e:
                result['issues'].append({
                    'type': 'processes_cpu_check_error',
                    'message': f"Error al verificar procesos que consumen CPU: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar uso de CPU: {e}")
            return {
                'issues': [{
                    'type': 'cpu_check_error',
                    'message': f"Error al verificar uso de CPU: {str(e)}"
                }]
            }
    
    def check_memory_usage(self):
        """Verificar uso de memoria"""
        try:
            result = {
                'total': 0,
                'used': 0,
                'free': 0,
                'available': 0,
                'usage_percentage': 0,
                'swap': {},
                'processes': {},
                'issues': [],
                'warnings': []
            }
            
            # Obtener información de memoria
            try:
                mem_result = subprocess.run(
                    ['cat', '/proc/meminfo'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if mem_result.returncode == 0:
                    mem_info = {}
                    
                    for line in mem_result.stdout.strip().split('\n'):
                        if ':' in line:
                            key, value = line.split(':', 1)
                            mem_info[key.strip()] = value.strip()
                    
                    # Extraer valores de memoria
                    if 'MemTotal' in mem_info:
                        result['total'] = int(mem_info['MemTotal'].split()[0])
                    
                    if 'MemAvailable' in mem_info:
                        result['available'] = int(mem_info['MemAvailable'].split()[0])
                    
                    if 'MemFree' in mem_info:
                        result['free'] = int(mem_info['MemFree'].split()[0])
                    
                    # Calcular memoria utilizada
                    result['used'] = result['total'] - result['available']
                    result['usage_percentage'] = (result['used'] / result['total']) * 100
                    
                    # Verificar si el uso de memoria es alto
                    if result['usage_percentage'] > 90:
                        result['issues'].append({
                            'type': 'high_memory_usage',
                            'value': result['usage_percentage'],
                            'message': f"Uso de memoria muy alto: {result['usage_percentage']:.2f}%"
                        })
                    elif result['usage_percentage'] > 80:
                        result['warnings'].append({
                            'type': 'moderate_memory_usage',
                            'value': result['usage_percentage'],
                            'message': f"Uso de memoria moderadamente alto: {result['usage_percentage']:.2f}%"
                        })
            except Exception as e:
                result['issues'].append({
                    'type': 'memory_usage_check_error',
                    'message': f"Error al verificar uso de memoria: {str(e)}"
                })
            
            # Obtener información de swap
            try:
                swap_result = subprocess.run(
                    ['cat', '/proc/meminfo'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if swap_result.returncode == 0:
                    swap_info = {}
                    
                    for line in swap_result.stdout.strip().split('\n'):
                        if ':' in line and 'Swap' in line:
                            key, value = line.split(':', 1)
                            swap_info[key.strip()] = value.strip()
                    
                    # Extraer valores de swap
                    if 'SwapTotal' in swap_info:
                        swap_total = int(swap_info['SwapTotal'].split()[0])
                        
                        if swap_total > 0:
                            if 'SwapFree' in swap_info:
                                swap_free = int(swap_info['SwapFree'].split()[0])
                                
                                result['swap'] = {
                                    'total': swap_total,
                                    'free': swap_free,
                                    'used': swap_total - swap_free,
                                    'usage_percentage': ((swap_total - swap_free) / swap_total) * 100
                                }
                                
                                # Verificar si el uso de swap es alto
                                if result['swap']['usage_percentage'] > 50:
                                    result['issues'].append({
                                        'type': 'high_swap_usage',
                                        'value': result['swap']['usage_percentage'],
                                        'message': f"Uso de swap alto: {result['swap']['usage_percentage']:.2f}%"
                                    })
            except Exception as e:
                result['issues'].append({
                    'type': 'swap_usage_check_error',
                    'message': f"Error al verificar uso de swap: {str(e)}"
                })
            
            # Obtener procesos que más consumen memoria
            try:
                ps_result = subprocess.run(
                    ['ps', '-eo', 'pid,pmem,comm', '--sort=-pmem', '|', 'head', '-10'],
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if ps_result.returncode == 0:
                    lines = ps_result.stdout.strip().split('\n')
                    
                    # Omitir la primera línea (encabezado)
                    for line in lines[1:]:
                        parts = line.split(None, 2)
                        
                        if len(parts) >= 3:
                            pid = parts[0]
                            mem_percentage = parts[1]
                            command = parts[2]
                            
                            result['processes'][pid] = {
                                'memory_percentage': float(mem_percentage),
                                'command': command
                            }
            except Exception as e:
                result['issues'].append({
                    'type': 'processes_memory_check_error',
                    'message': f"Error al verificar procesos que consumen memoria: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar uso de memoria: {e}")
            return {
                'issues': [{
                    'type': 'memory_check_error',
                    'message': f"Error al verificar uso de memoria: {str(e)}"
                }]
            }
    
    def check_disk_usage(self):
        """Verificar uso de disco"""
        try:
            result = {
                'filesystems': {},
                'issues': [],
                'warnings': []
            }
            
            # Obtener información de uso de disco
            try:
                df_result = subprocess.run(
                    ['df', '-h', '--type=ext4,ext3,xfs'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if df_result.returncode == 0:
                    lines = df_result.stdout.strip().split('\n')
                    
                    # Omitir la primera línea (encabezado)
                    for line in lines[1:]:
                        parts = line.split()
                        
                        if len(parts) >= 6:
                            filesystem = parts[0]
                            size = parts[1]
                            used = parts[2]
                            avail = parts[3]
                            use_percent = parts[4]
                            mountpoint = parts[5]
                            
                            # Extraer porcentaje de uso
                            percent_match = re.search(r'(\d+)%', use_percent)
                            if percent_match:
                                usage_percent = int(percent_match.group(1))
                                
                                result['filesystems'][filesystem] = {
                                    'size': size,
                                    'used': used,
                                    'available': avail,
                                    'usage_percent': usage_percent,
                                    'mountpoint': mountpoint
                                }
                                
                                # Verificar si el uso de disco es alto
                                if usage_percent > 95:
                                    result['issues'].append({
                                        'type': 'high_disk_usage',
                                        'filesystem': filesystem,
                                        'mountpoint': mountpoint,
                                        'usage_percent': usage_percent,
                                        'message': f"Uso de disco muy alto en {mountpoint}: {usage_percent}%"
                                    })
                                elif usage_percent > 85:
                                    result['warnings'].append({
                                        'type': 'moderate_disk_usage',
                                        'filesystem': filesystem,
                                        'mountpoint': mountpoint,
                                        'usage_percent': usage_percent,
                                        'message': f"Uso de disco moderadamente alto en {mountpoint}: {usage_percent}%"
                                    })
            except Exception as e:
                result['issues'].append({
                    'type': 'disk_usage_check_error',
                    'message': f"Error al verificar uso de disco: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar uso de disco: {e}")
            return {
                'issues': [{
                    'type': 'disk_check_error',
                    'message': f"Error al verificar uso de disco: {str(e)}"
                }]
            }
    
    def check_network_usage(self):
        """Verificar uso de red"""
        try:
            result = {
                'interfaces': {},
                'connections': {},
                'issues': [],
                'warnings': []
            }
            
            # Obtener información de interfaces de red
            try:
                ifconfig_result = subprocess.run(
                    ['ifconfig'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if ifconfig_result.returncode == 0:
                    interfaces = {}
                    current_interface = None
                    
                    for line in ifconfig_result.stdout.split('\n'):
                        # Identificar interfaces
                        interface_match = re.match(r'^(\S+):', line)
                        if interface_match:
                            current_interface = interface_match.group(1)
                            interfaces[current_interface] = {
                                'rx_bytes': 0,
                                'tx_bytes': 0,
                                'rx_packets': 0,
                                'tx_packets': 0,
                                'status': 'up'
                            }
                        
                        # Extraer estadísticas
                        if current_interface and 'RX packets' in line:
                            rx_match = re.search(r'RX packets:(\d+)', line)
                            if rx_match:
                                interfaces[current_interface]['rx_packets'] = int(rx_match.group(1))
                            
                            bytes_match = re.search(r'bytes:(\d+)', line)
                            if bytes_match:
                                interfaces[current_interface]['rx_bytes'] = int(bytes_match.group(1))
                        
                        elif current_interface and 'TX packets' in line:
                            tx_match = re.search(r'TX packets:(\d+)', line)
                            if tx_match:
                                interfaces[current_interface]['tx_packets'] = int(tx_match.group(1))
                            
                            bytes_match = re.search(r'bytes:(\d+)', line)
                            if bytes_match:
                                interfaces[current_interface]['tx_bytes'] = int(bytes_match.group(1))
                    
                    result['interfaces'] = interfaces
            except Exception as e:
                result['issues'].append({
                    'type': 'network_interfaces_check_error',
                    'message': f"Error al verificar interfaces de red: {str(e)}"
                })
            
            # Obtener información de conexiones de red
            try:
                netstat_result = subprocess.run(
                    ['netstat', '-an'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if netstat_result.returncode == 0:
                    connections = {
                        'tcp': 0,
                        'udp': 0,
                        'listening': 0,
                        'established': 0
                    }
                    
                    for line in netstat_result.stdout.split('\n'):
                        if line.startswith('tcp') or line.startswith('tcp6'):
                            connections['tcp'] += 1
                            
                            if 'LISTEN' in line:
                                connections['listening'] += 1
                            elif 'ESTABLISHED' in line:
                                connections['established'] += 1
                        elif line.startswith('udp') or line.startswith('udp6'):
                            connections['udp'] += 1
                    
                    result['connections'] = connections
                    
                    # Verificar si hay demasiadas conexiones
                    if connections['listening'] > 100:
                        result['warnings'].append({
                            'type': 'many_listening_connections',
                            'count': connections['listening'],
                            'message': f"Muchas conexiones en escucha: {connections['listening']}"
                        })
                    
                    if connections['established'] > 1000:
                        result['warnings'].append({
                            'type': 'many_established_connections',
                            'count': connections['established'],
                            'message': f"Muchas conexiones establecidas: {connections['established']}"
                        })
            except Exception as e:
                result['issues'].append({
                    'type': 'network_connections_check_error',
                    'message': f"Error al verificar conexiones de red: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar uso de red: {e}")
            return {
                'issues': [{
                    'type': 'network_check_error',
                    'message': f"Error al verificar uso de red: {str(e)}"
                }]
            }
    
    def diagnose_network(self):
        """Verificar la configuración y estado de la red"""
        try:
            results = {
                'interfaces': {},
                'connectivity': {},
                'dns': {},
                'firewall': {},
                'summary': {
                    'checks_performed': 0,
                    'issues_found': 0,
                    'warnings': 0
                }
            }
            
            # Verificar interfaces de red
            print(f"   Verificando interfaces de red...")
            interfaces_result = self.check_network_interfaces()
            results['interfaces'] = interfaces_result
            results['summary']['checks_performed'] += 1
            
            if interfaces_result['issues']:
                results['summary']['issues_found'] += len(interfaces_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(interfaces_result['issues'])} problemas de interfaces{Color.END}")
            elif interfaces_result['warnings']:
                results['summary']['warnings'] += len(interfaces_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(interfaces_result['warnings'])} advertencias de interfaces{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de interfaces de red{Color.END}")
            
            # Verificar conectividad
            print(f"   Verificando conectividad...")
            connectivity_result = self.check_connectivity()
            results['connectivity'] = connectivity_result
            results['summary']['checks_performed'] += 1
            
            if connectivity_result['issues']:
                results['summary']['issues_found'] += len(connectivity_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(connectivity_result['issues'])} problemas de conectividad{Color.END}")
            elif connectivity_result['warnings']:
                results['summary']['warnings'] += len(connectivity_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(connectivity_result['warnings'])} advertencias de conectividad{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de conectividad{Color.END}")
            
            # Verificar DNS
            print(f"   Verificando DNS...")
            dns_result = self.check_dns()
            results['dns'] = dns_result
            results['summary']['checks_performed'] += 1
            
            if dns_result['issues']:
                results['summary']['issues_found'] += len(dns_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(dns_result['issues'])} problemas de DNS{Color.END}")
            elif dns_result['warnings']:
                results['summary']['warnings'] += len(dns_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(dns_result['warnings'])} advertencias de DNS{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de DNS{Color.END}")
            
            # Verificar firewall
            print(f"   Verificando firewall...")
            firewall_result = self.check_firewall()
            results['firewall'] = firewall_result
            results['summary']['checks_performed'] += 1
            
            if firewall_result['issues']:
                results['summary']['issues_found'] += len(firewall_result['issues'])
                print(f"   {Color.RED}Se encontraron {len(firewall_result['issues'])} problemas de firewall{Color.END}")
            elif firewall_result['warnings']:
                results['summary']['warnings'] += len(firewall_result['warnings'])
                print(f"   {Color.YELLOW}Se encontraron {len(firewall_result['warnings'])} advertencias de firewall{Color.END}")
            else:
                print(f"   {Color.GREEN}No se encontraron problemas de firewall{Color.END}")
            
            # Mostrar resumen
            print(f"   Resumen: {results['summary']['checks_performed']} verificaciones realizadas, {results['summary']['issues_found']} problemas encontrados")
            
            return {
                'success': True,
                'results': results
            }
        except Exception as e:
            logger.error(f"Error en diagnóstico de red: {e}")
            return {
                'success': False,
                'message': f"Error en diagnóstico de red: {str(e)}"
            }
    
    def check_network_interfaces(self):
        """Verificar interfaces de red"""
        try:
            result = {
                'interfaces': {},
                'issues': [],
                'warnings': []
            }
            
            # Obtener información de interfaces de red
            try:
                ip_result = subprocess.run(
                    ['ip', 'addr', 'show'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if ip_result.returncode == 0:
                    interfaces = {}
                    current_interface = None
                    
                    for line in ip_result.stdout.split('\n'):
                        # Identificar interfaces
                        interface_match = re.match(r'^\d+:\s+(\S+):', line)
                        if interface_match:
                            current_interface = interface_match.group(1)
                            
                            # Verificar si la interfaz está activa
                            is_up = 'UP' in line
                            
                            interfaces[current_interface] = {
                                'is_up': is_up,
                                'addresses': []
                            }
                        
                        # Extraer direcciones IP
                        elif current_interface and 'inet' in line:
                            addr_match = re.search(r'inet\s+(\S+)', line)
                            if addr_match:
                                interfaces[current_interface]['addresses'].append(addr_match.group(1))
                    
                    result['interfaces'] = interfaces
                    
                    # Verificar si hay interfaces sin configuración IP
                    for interface_name, interface_info in interfaces.items():
                        if interface_info['is_up'] and not interface_info['addresses']:
                            if not interface_name.startswith('lo'):
                                result['issues'].append({
                                    'type': 'interface_without_ip',
                                    'interface': interface_name,
                                    'message': f"La interfaz {interface_name} está activa pero no tiene dirección IP"
                                })
                        elif not interface_info['is_up'] and not interface_name.startswith('lo'):
                            result['warnings'].append({
                                'type': 'interface_down',
                                'interface': interface_name,
                                'message': f"La interfaz {interface_name} está inactiva"
                            })
            except Exception as e:
                result['issues'].append({
                    'type': 'network_interfaces_check_error',
                    'message': f"Error al verificar interfaces de red: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar interfaces de red: {e}")
            return {
                'issues': [{
                    'type': 'network_interfaces_check_error',
                    'message': f"Error al verificar interfaces de red: {str(e)}"
                }]
            }
    
    def check_connectivity(self):
        """Verificar conectividad de red"""
        try:
            result = {
                'external': {},
                'local': {},
                'issues': [],
                'warnings': []
            }
            
            # Verificar conectividad externa
            try:
                # Hacer ping a Google DNS
                ping_result = subprocess.run(
                    ['ping', '-c', '4', '8.8.8.8'],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if ping_result.returncode == 0:
                    # Analizar resultado de ping
                    ping_lines = ping_result.stdout.split('\n')
                    
                    for line in ping_lines:
                        if 'packets transmitted' in line:
                            stats_match = re.search(r'(\d+) packets transmitted, (\d+) received', line)
                            if stats_match:
                                transmitted = int(stats_match.group(1))
                                received = int(stats_match.group(2))
                                
                                result['external']['google_dns'] = {
                                    'transmitted': transmitted,
                                    'received': received,
                                    'loss_percent': ((transmitted - received) / transmitted) * 100,
                                    'success': received > 0
                                }
                                
                                if received == 0:
                                    result['issues'].append({
                                        'type': 'no_external_connectivity',
                                        'target': '8.8.8.8',
                                        'message': "No hay conectividad externa (ping a 8.8.8.8 falló)"
                                    })
                                elif ((transmitted - received) / transmitted) * 100 > 20:
                                    result['warnings'].append({
                                        'type': 'high_packet_loss',
                                        'target': '8.8.8.8',
                                        'loss_percent': ((transmitted - received) / transmitted) * 100,
                                        'message': f"Alta pérdida de paquetes: {((transmitted - received) / transmitted) * 100:.2f}%"
                                    })
                                
                                break
                else:
                    result['issues'].append({
                        'type': 'no_external_connectivity',
                        'target': '8.8.8.8',
                        'message': "No hay conectividad externa (ping a 8.8.8.8 falló)"
                    })
            except Exception as e:
                result['issues'].append({
                    'type': 'external_connectivity_check_error',
                    'message': f"Error al verificar conectividad externa: {str(e)}"
                })
            
            # Verificar conectividad local
            try:
                # Hacer ping a localhost
                ping_result = subprocess.run(
                    ['ping', '-c', '4', '127.0.0.1'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if ping_result.returncode == 0:
                    # Analizar resultado de ping
                    ping_lines = ping_result.stdout.split('\n')
                    
                    for line in ping_lines:
                        if 'packets transmitted' in line:
                            stats_match = re.search(r'(\d+) packets transmitted, (\d+) received', line)
                            if stats_match:
                                transmitted = int(stats_match.group(1))
                                received = int(stats_match.group(2))
                                
                                result['local']['localhost'] = {
                                    'transmitted': transmitted,
                                    'received': received,
                                    'loss_percent': ((transmitted - received) / transmitted) * 100,
                                    'success': received > 0
                                }
                                
                                if received == 0:
                                    result['issues'].append({
                                        'type': 'no_local_connectivity',
                                        'target': '127.0.0.1',
                                        'message': "No hay conectividad local (ping a 127.0.0.1 falló)"
                                    })
                                
                                break
                else:
                    result['issues'].append({
                        'type': 'no_local_connectivity',
                        'target': '127.0.0.1',
                        'message': "No hay conectividad local (ping a 127.0.0.1 falló)"
                    })
            except Exception as e:
                result['issues'].append({
                    'type': 'local_connectivity_check_error',
                    'message': f"Error al verificar conectividad local: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar conectividad: {e}")
            return {
                'issues': [{
                    'type': 'connectivity_check_error',
                    'message': f"Error al verificar conectividad: {str(e)}"
                }]
            }
    
    def check_dns(self):
        """Verificar configuración de DNS"""
        try:
            result = {
                'resolution': {},
                'servers': [],
                'issues': [],
                'warnings': []
            }
            
            # Obtener servidores DNS configurados
            try:
                resolv_result = subprocess.run(
                    ['cat', '/etc/resolv.conf'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if resolv_result.returncode == 0:
                    dns_servers = []
                    
                    for line in resolv_result.stdout.split('\n'):
                        if line.startswith('nameserver'):
                            server = line.split()[1]
                            dns_servers.append(server)
                    
                    result['servers'] = dns_servers
                    
                    if not dns_servers:
                        result['issues'].append({
                            'type': 'no_dns_servers',
                            'message': "No hay servidores DNS configurados"
                        })
            except Exception as e:
                result['issues'].append({
                    'type': 'dns_servers_check_error',
                    'message': f"Error al verificar servidores DNS: {str(e)}"
                })
            
            # Verificar resolución de nombres
            try:
                # Resolver un dominio conocido
                nslookup_result = subprocess.run(
                    ['nslookup', 'google.com'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if nslookup_result.returncode == 0:
                    result['resolution']['google.com'] = {
                        'success': True,
                        'output': nslookup_result.stdout
                    }
                else:
                    result['issues'].append({
                        'type': 'dns_resolution_failed',
                        'domain': 'google.com',
                        'message': "Falló la resolución de nombres para google.com"
                    })
            except Exception as e:
                result['issues'].append({
                    'type': 'dns_resolution_check_error',
                    'message': f"Error al verificar resolución de nombres: {str(e)}"
                })
            
            return result
        except Exception as e:
            logger.error(f"Error al verificar DNS: {e}")
            return {
                'issues': [{
                    'type': 'dns_check_error',
                    'message': f"Error al verificar DNS: {str(e)}"
                }]
            }
    
    def run_repair_command(self, command, parameters=None):
        """Ejecutar un comando de reparación"""
        try:
            if command == 'fix_permissions':
                return self.fix_permissions()
            elif command == 'fix_services':
                return self.fix_services()
            elif command == 'fix_ssl':
                return self.fix_ssl()
            else:
                return {
                    'success': False,
                    'message': f"Comando de reparación no soportado: {command}"
                }
        except Exception as e:
            logger.error(f"Error al ejecutar comando de reparación: {e}")
            return {
                'success': False,
                'message': f"Error al ejecutar comando de reparación: {str(e)}"
            }
    
    def fix_permissions(self):
        """Reparar permisos de archivos y directorios"""
        try:
            print(f"{Color.YELLOW}Reparando permisos de archivos y directorios críticos...{Color.END}")
            
            result = {
                'fixed': [],
                'errors': [],
                'summary': {
                    'total': 0,
                    'fixed': 0,
                    'errors': 0
                }
            }
            
            # Lista de archivos y directorios críticos y sus permisos correctos
            critical_paths = [
                {'path': '/etc/passwd', 'perms': '644', 'owner': 'root', 'group': 'root'},
                {'path': '/etc/shadow', 'perms': '600', 'owner': 'root', 'group': 'shadow'},
                {'path': '/etc/group', 'perms': '644', 'owner': 'root', 'group': 'root'},
                {'path': '/etc/gshadow', 'perms': '600', 'owner': 'root', 'group': 'shadow'},
                {'path': '/etc/ssh/sshd_config', 'perms': '600', 'owner': 'root', 'group': 'root'},
                {'path': '/etc/ssh/ssh_host_rsa_key', 'perms': '600', 'owner': 'root', 'group': 'root'},
                {'path': '/etc/ssh/ssh_host_rsa_key.pub', 'perms': '644', 'owner': 'root', 'group': 'root'},
                {'path': '/var/www', 'perms': '755', 'owner': 'root', 'group': 'root'},
                {'path': '/var/log', 'perms': '755', 'owner': 'root', 'group': 'root'},
                {'path': '/etc/webmin', 'perms': '755', 'owner': 'root', 'group': 'root'}
            ]
            
            for item in critical_paths:
                path = item['path']
                perms = item['perms']
                owner = item['owner']
                group = item['group']
                
                if os.path.exists(path):
                    result['summary']['total'] += 1
                    
                    try:
                        # Obtener permisos actuales
                        stat_info = os.stat(path)
                        current_perms = oct(stat_info.st_mode)[-3:]
                        
                        # Verificar si los permisos son correctos
                        if current_perms != perms:
                            # Corregir permisos
                            subprocess.run(['chmod', perms, path], check=True)
                            
                            # Corregir propietario y grupo
                            subprocess.run(['chown', f"{owner}:{group}", path], check=True)
                            
                            result['fixed'].append({
                                'path': path,
                                'old_perms': current_perms,
                                'new_perms': perms,
                                'message': f"Permisos corregidos de {current_perms} a {perms}"
                            })
                            
                            result['summary']['fixed'] += 1
                            print(f"   {Color.GREEN}✓{Color.END} Permisos corregidos: {path} ({current_perms} -> {perms})")
                        else:
                            print(f"   {Color.GREEN}✓{Color.END} Permisos correctos: {path} ({perms})")
                    except Exception as e:
                        result['errors'].append({
                            'path': path,
                            'error': str(e),
                            'message': f"Error al corregir permisos: {str(e)}"
                        })
                        
                        result['summary']['errors'] += 1
                        print(f"   {Color.RED}✗{Color.END} Error al corregir permisos: {path} - {str(e)}")
                else:
                    print(f"   {Color.YELLOW}!{Color.END} Ruta no encontrada: {path}")
            
            # Mostrar resumen
            print(f"   Resumen: {result['summary']['fixed']} correcciones, {result['summary']['errors']} errores")
            
            return {
                'success': result['summary']['fixed'] > 0,
                'result': result
            }
        except Exception as e:
            logger.error(f"Error al reparar permisos: {e}")
            return {
                'success': False,
                'message': f"Error al reparar permisos: {str(e)}"
            }
    
    def fix_services(self):
        """Intentar reparar servicios caídos"""
        try:
            print(f"{Color.YELLOW}Intentando reparar servicios caídos...{Color.END}")
            
            result = {
                'services': {},
                'fixed': [],
                'failed': [],
                'summary': {
                    'total': 0,
                    'fixed': 0,
                    'failed': 0
                }
            }
            
            # Obtener estado de los servicios
            for service in self.config['services']:
                try:
                    # Verificar estado del servicio
                    status_result = subprocess.run(
                        ['systemctl', 'is-active', service],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    status = status_result.stdout.strip()
                    
                    if status != 'active':
                        result['summary']['total'] += 1
                        
                        print(f"   Intentando reparar servicio: {service} (estado: {status})")
                        
                        # Intentar iniciar el servicio
                        start_result = subprocess.run(
                            ['systemctl', 'start', service],
                            capture_output=True,
                            text=True,
                            timeout=30
                        )
                        
                        if start_result.returncode == 0:
                            # Verificar si el servicio se inició correctamente
                            verify_result = subprocess.run(
                                ['systemctl', 'is-active', service],
                                capture_output=True,
                                text=True,
                                timeout=10
                            )
                            
                            if verify_result.stdout.strip() == 'active':
                                result['fixed'].append(service)
                                result['summary']['fixed'] += 1
                                
                                result['services'][service] = {
                                    'old_status': status,
                                    'new_status': 'active',
                                    'success': True
                                }
                                
                                print(f"   {Color.GREEN}✓{Color.END} Servicio reparado: {service}")
                            else:
                                result['failed'].append(service)
                                result['summary']['failed'] += 1
                                
                                result['services'][service] = {
                                    'old_status': status,
                                    'new_status': verify_result.stdout.strip(),
                                    'success': False,
                                    'error': start_result.stderr
                                }
                                
                                print(f"   {Color.RED}✗{Color.END} No se pudo reparar el servicio: {service}")
                        else:
                            result['failed'].append(service)
                            result['summary']['failed'] += 1
                            
                            result['services'][service] = {
                                'old_status': status,
                                'new_status': status,
                                'success': False,
                                'error': start_result.stderr
                            }
                            
                            print(f"   {Color.RED}✗{Color.END} Error al iniciar el servicio: {service} - {start_result.stderr}")
                    else:
                        print(f"   {Color.GREEN}✓{Color.END} Servicio ya está activo: {service}")
                except Exception as e:
                    result['failed'].append(service)
                    result['summary']['failed'] += 1
                    
                    result['services'][service] = {
                        'success': False,
                        'error': str(e)
                    }
                    
                    print(f"   {Color.RED}✗{Color.END} Error al verificar el servicio: {service} - {str(e)}")
            
            # Mostrar resumen
            print(f"   Resumen: {result['summary']['fixed']} servicios reparados, {result['summary']['failed']} no se pudieron reparar")
            
            return {
                'success': result['summary']['fixed'] > 0,
                'result': result
            }
        except Exception as e:
            logger.error(f"Error al reparar servicios: {e}")
            return {
                'success': False,
                'message': f"Error al reparar servicios: {str(e)}"
            }
    
    def fix_ssl(self):
        """Reparar problemas con certificados SSL"""
        try:
            print(f"{Color.YELLOW}Reparando problemas con certificados SSL...{Color.END}")
            
            result = {
                'certificates': {},
                'fixed': [],
                'errors': [],
                'summary': {
                    'total': 0,
                    'fixed': 0,
                    'errors': 0
                }
            }
            
            # Buscar certificados SSL en ubicaciones comunes
            cert_paths = [
                '/etc/ssl/certs',
                '/etc/apache2/ssl',
                '/etc/nginx/ssl',
                '/etc/postfix/ssl',
                '/etc/dovecot/ssl'
            ]
            
            for cert_path in cert_paths:
                if os.path.exists(cert_path):
                    for cert_file in os.listdir(cert_path):
                        if cert_file.endswith('.crt') or cert_file.endswith('.pem'):
                            cert_full_path = os.path.join(cert_path, cert_file)
                            
                            try:
                                # Verificar certificado
                                cmd = [
                                    'openssl', 'x509',
                                    '-in', cert_full_path,
                                    '-noout',
                                    '-dates'
                                ]
                                
                                openssl_result = subprocess.run(
                                    cmd,
                                    capture_output=True,
                                    text=True,
                                    timeout=10
                                )
                                
                                if openssl_result.returncode == 0:
                                    # Extraer fechas
                                    not_before = ''
                                    not_after = ''
                                    
                                    for line in openssl_result.stdout.split('\n'):
                                        if line.startswith('notBefore='):
                                            not_before = line.split('=', 1)[1]
                                        elif line.startswith('notAfter='):
                                            not_after = line.split('=', 1)[1]
                                    
                                    # Convertir fechas a objetos datetime
                                    not_before_dt = datetime.strptime(not_before, '%b %d %H:%M:%S %Y %Z')
                                    not_after_dt = datetime.strptime(not_after, '%b %d %H:%M:%S %Y %Z')
                                    
                                    # Verificar si el certificado está expirado
                                    now = datetime.now()
                                    days_until_expiry = (not_after_dt - now).days
                                    
                                    result['summary']['total'] += 1
                                    
                                    if days_until_expiry < 0:
                                        # Certificado expirado
                                        print(f"   {Color.RED}✗{Color.END} Certificado expirado: {cert_file}")
                                        
                                        result['certificates'][cert_full_path] = {
                                            'not_before': not_before,
                                            'not_after': not_after,
                                            'days_until_expiry': days_until_expiry,
                                            'expired': True,
                                            'fixable': False
                                        }
                                        
                                        result['errors'].append({
                                            'type': 'expired_certificate',
                                            'path': cert_full_path,
                                            'message': f"El certificado ha expirado hace {abs(days_until_expiry)} días"
                                        })
                                    elif days_until_expiry < 30:
                                        # Certificado expirará pronto
                                        print(f"   {Color.YELLOW}!{Color.END} Certificado expirará pronto: {cert_file}")
                                        
                                        # Intentar renovar certificado con Let's Encrypt
                                        renewed = self.renew_ssl_certificate(cert_full_path)
                                        
                                        if renewed:
                                            result['fixed'].append(cert_full_path)
                                            result['summary']['fixed'] += 1
                                            
                                            result['certificates'][cert_full_path] = {
                                                'not_before': not_before,
                                                'not_after': not_after,
                                                'days_until_expiry': days_until_expiry,
                                                'expired': False,
                                                'renewed': True
                                            }
                                            
                                            print(f"   {Color.GREEN}✓{Color.END} Certificado renovado: {cert_file}")
                                        else:
                                            result['certificates'][cert_full_path] = {
                                                'not_before': not_before,
                                                'not_after': not_after,
                                                'days_until_expiry': days_until_expiry,
                                                'expired': False,
                                                'renewed': False
                                            }
                                            
                                            result['errors'].append({
                                                'type': 'certificate_renewal_failed',
                                                'path': cert_full_path,
                                                'message': f"No se pudo renovar el certificado: {cert_file}"
                                            })
                                    else:
                                        print(f"   {Color.GREEN}✓{Color.END} Certificado válido: {cert_file}")
                                        
                                        result['certificates'][cert_full_path] = {
                                            'not_before': not_before,
                                            'not_after': not_after,
                                            'days_until_expiry': days_until_expiry,
                                            'expired': False,
                                            'renewed': False
                                        }
                            except Exception as e:
                                result['errors'].append({
                                    'type': 'certificate_check_error',
                                    'path': cert_full_path,
                                    'message': f"Error al verificar certificado: {str(e)}"
                                })
            # Mostrar resumen
            print(f"   Resumen: {result['summary']['fixed']} certificados renovados, {result['summary']['errors']} con errores")
            
            return {
                'success': result['summary']['fixed'] > 0,
                'result': result
            }
        except Exception as e:
            logger.error(f"Error al reparar certificados SSL: {e}")
            return {
                'success': False,
                'message': f"Error al reparar certificados SSL: {str(e)}"
            }
    
    def renew_ssl_certificate(self, cert_path):
        """Intentar renovar un certificado SSL con Let's Encrypt"""
        try:
            # Intentar renovar certificado con certbot
            result = subprocess.run(
                ['certbot', 'renew', '--cert-name', os.path.basename(cert_path).replace('.crt', '')],
                capture_output=True,
                text=True,
                timeout=300
            )
            
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Error al renovar certificado SSL: {e}")
            return False
    
    def run_info_command(self, command, parameters=None):
        """Ejecutar un comando de información"""
        try:
            if command == 'info_system':
                return self.info_system()
            elif command == 'info_services':
                return self.info_services()
            elif command == 'info_logs':
                return self.info_logs()
            else:
                return {
                    'success': False,
                    'message': f"Comando de información no soportado: {command}"
                }
        except Exception as e:
            logger.error(f"Error al ejecutar comando de información: {e}")
            return {
                'success': False,
                'message': f"Error al ejecutar comando de información: {str(e)}"
            }
    
    def info_system(self):
        """Mostrar información detallada del sistema"""
        try:
            print(f"{Color.CYAN}Información del Sistema{Color.END}")
            print(f"{Color.CYAN}==================={Color.END}")
            print()
            
            # Información básica del sistema
            try:
                uname_result = subprocess.run(
                    ['uname', '-a'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if uname_result.returncode == 0:
                    print(f"{Color.YELLOW}Sistema Operativo:{Color.END} {uname_result.stdout.strip()}")
            except Exception as e:
                print(f"{Color.RED}Error al obtener información del sistema: {str(e)}{Color.END}")
            
            # Información del kernel
            try:
                kernel_version = subprocess.run(
                    ['uname', '-r'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if kernel_version.returncode == 0:
                    print(f"{Color.YELLOW}Versión del Kernel:{Color.END} {kernel_version.stdout.strip()}")
            except Exception as e:
                print(f"{Color.RED}Error al obtener versión del kernel: {str(e)}{Color.END}")
            
            # Información del hardware
            try:
                cpuinfo_result = subprocess.run(
                    ['cat', '/proc/cpuinfo'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if cpuinfo_result.returncode == 0:
                    cpu_lines = cpuinfo_result.stdout.split('\n')
                    
                    # Contar núcleos
                    core_count = 0
                    model_name = ''
                    
                    for line in cpu_lines:
                        if line.startswith('model name'):
                            model_name = line.split(':', 1)[1].strip()
                        elif line.startswith('processor'):
                            core_count += 1
                    
                    print(f"{Color.YELLOW}CPU:{Color.END} {model_name}")
                    print(f"{Color.YELLOW}Núcleos:{Color.END} {core_count}")
            except Exception as e:
                print(f"{Color.RED}Error al obtener información de la CPU: {str(e)}{Color.END}")
            
            # Información de memoria
            try:
                mem_result = subprocess.run(
                    ['cat', '/proc/meminfo'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if mem_result.returncode == 0:
                    mem_info = {}
                    
                    for line in mem_result.stdout.strip().split('\n'):
                        if ':' in line:
                            key, value = line.split(':', 1)
                            mem_info[key.strip()] = value.strip()
                    
                    if 'MemTotal' in mem_info:
                        total_mem = int(mem_info['MemTotal'].split()[0]) // 1024 // 1024  # GB
                        print(f"{Color.YELLOW}Memoria Total:{Color.END} {total_mem} GB")
                    
                    if 'MemAvailable' in mem_info:
                        avail_mem = int(mem_info['MemAvailable'].split()[0]) // 1024 // 1024  # GB
                        print(f"{Color.YELLOW}Memoria Disponible:{Color.END} {avail_mem} GB")
            except Exception as e:
                print(f"{Color.RED}Error al obtener información de memoria: {str(e)}{Color.END}")
            
            # Información de disco
            try:
                df_result = subprocess.run(
                    ['df', '-h', '/'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if df_result.returncode == 0:
                    lines = df_result.stdout.strip().split('\n')
                    
                    if len(lines) >= 2:
                        parts = lines[1].split()
                        
                        if len(parts) >= 6:
                            size = parts[1]
                            used = parts[2]
                            avail = parts[3]
                            use_percent = parts[4]
                            mountpoint = parts[5]
                            
                            print(f"{Color.YELLOW}Disco ({mountpoint}):{Color.END} {used}/{size} ({use_percent})")
            except Exception as e:
                print(f"{Color.RED}Error al obtener información de disco: {str(e)}{Color.END}")
            
            # Información de tiempo de actividad
            try:
                uptime_result = subprocess.run(
                    ['cat', '/proc/uptime'],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                
                if uptime_result.returncode == 0:
                    uptime_seconds = float(uptime_result.stdout.split()[0])
                    uptime_days = int(uptime_seconds // 86400)
                    uptime_hours = int((uptime_seconds % 86400) // 3600)
                    uptime_minutes = int((uptime_seconds % 3600) // 60)
                    
                    print(f"{Color.YELLOW}Tiempo de Actividad:{Color.END} {uptime_days}d {uptime_hours}h {uptime_minutes}m")
            except Exception as e:
                print(f"{Color.RED}Error al obtener tiempo de actividad: {str(e)}{Color.END}")
            
            print()
            
            return {
                'success': True,
                'message': 'Información del sistema mostrada'
            }
        except Exception as e:
            logger.error(f"Error al mostrar información del sistema: {e}")
            return {
                'success': False,
                'message': f"Error al mostrar información del sistema: {str(e)}"
            }
    
    def info_services(self):
        """Mostrar información detallada de los servicios"""
        try:
            print(f"{Color.CYAN}Información de Servicios{Color.END}")
            print(f"{Color.CYAN}========================{Color.END}")
            print()
            
            for service in self.config['services']:
                try:
                    # Obtener estado del servicio
                    status_result = subprocess.run(
                        ['systemctl', 'show', service, '--property=Description,LoadState,ActiveState,SubState'],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    if status_result.returncode == 0:
                        print(f"{Color.YELLOW}{service}:{Color.END}")
                        
                        lines = status_result.stdout.strip().split('\n')
                        
                        for line in lines:
                            if '=' in line:
                                key, value = line.split('=', 1)
                                print(f"  {key}: {value}")
                        
                        print()
                    else:
                        print(f"{Color.RED}Error al obtener información del servicio: {service}{Color.END}")
                        print()
                except Exception as e:
                    print(f"{Color.RED}Error al verificar el servicio {service}: {str(e)}{Color.END}")
                    print()
            
            return {
                'success': True,
                'message': 'Información de servicios mostrada'
            }
        except Exception as e:
            logger.error(f"Error al mostrar información de servicios: {e}")
            return {
                'success': False,
                'message': f"Error al mostrar información de servicios: {str(e)}"
            }
    
    def info_logs(self):
        """Mostrar información de los logs del sistema"""
        try:
            print(f"{Color.CYAN}Información de Logs{Color.END}")
            print(f"{Color.CYAN}================={Color.END}")
            print()
            
            # Logs del sistema
            print(f"{Color.YELLOW}Logs del Sistema:{Color.END}")
            
            try:
                journalctl_result = subprocess.run(
                    ['journalctl', '--list-boots', '--no-pager'],
                    capture_output=True,
                    text=True,
                    timeout=10
                )
                
                if journalctl_result.returncode == 0:
                    lines = journalctl_result.stdout.strip().split('\n')
                    
                    for line in lines[:5]:  # Mostrar solo los primeros 5 boots
                        print(f"  {line}")
                    
                    if len(lines) > 5:
                        print(f"  ... y {len(lines) - 5} más")
            except Exception as e:
                print(f"  {Color.RED}Error al obtener logs del sistema: {str(e)}{Color.END}")
            
            print()
            
            # Logs de Virtualmin
            virtualmin_log_path = '/var/webmin/virtualmin/miniserv.log'
            
            if os.path.exists(virtualmin_log_path):
                print(f"{Color.YELLOW}Logs de Virtualmin:{Color.END}")
                
                try:
                    tail_result = subprocess.run(
                        ['tail', '-10', virtualmin_log_path],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    if tail_result.returncode == 0:
                        lines = tail_result.stdout.strip().split('\n')
                        
                        for line in lines:
                            print(f"  {line}")
                except Exception as e:
                    print(f"  {Color.RED}Error al obtener logs de Virtualmin: {str(e)}{Color.END}")
            else:
                print(f"{Color.YELLOW}Logs de Virtualmin:{Color.END} No encontrados")
            
            print()
            
            # Logs de Apache/Nginx
            apache_log_path = '/var/log/apache2/error.log'
            nginx_log_path = '/var/log/nginx/error.log'
            
            if os.path.exists(apache_log_path):
                print(f"{Color.YELLOW}Logs de Apache:{Color.END}")
                
                try:
                    tail_result = subprocess.run(
                        ['tail', '-10', apache_log_path],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    if tail_result.returncode == 0:
                        lines = tail_result.stdout.strip().split('\n')
                        
                        for line in lines:
                            print(f"  {line}")
                except Exception as e:
                    print(f"  {Color.RED}Error al obtener logs de Apache: {str(e)}{Color.END}")
                
                print()
            elif os.path.exists(nginx_log_path):
                print(f"{Color.YELLOW}Logs de Nginx:{Color.END}")
                
                try:
                    tail_result = subprocess.run(
                        ['tail', '-10', nginx_log_path],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    if tail_result.returncode == 0:
                        lines = tail_result.stdout.strip().split('\n')
                        
                        for line in lines:
                            print(f"  {line}")
                except Exception as e:
                    print(f"  {Color.RED}Error al obtener logs de Nginx: {str(e)}{Color.END}")
                
                print()
            
            # Logs de MySQL/PostgreSQL
            mysql_log_path = '/var/log/mysql/error.log'
            postgresql_log_path = '/var/log/postgresql/postgresql-*.log'
            
            if os.path.exists(mysql_log_path):
                print(f"{Color.YELLOW}Logs de MySQL:{Color.END}")
                
                try:
                    tail_result = subprocess.run(
                        ['tail', '-10', mysql_log_path],
                        capture_output=True,
                        text=True,
                        timeout=10
                    )
                    
                    if tail_result.returncode == 0:
                        lines = tail_result.stdout.strip().split('\n')
                        
                        for line in lines:
                            print(f"  {line}")
                except Exception as e:
                    print(f"  {Color.RED}Error al obtener logs de MySQL: {str(e)}{Color.END}")
                
                print()
            else:
                # Intentar con PostgreSQL
                import glob
                
                postgresql_logs = glob.glob('/var/log/postgresql/postgresql-*.log')
                
                if postgresql_logs:
                    print(f"{Color.YELLOW}Logs de PostgreSQL:{Color.END}")
                    
                    try:
                        tail_result = subprocess.run(
                            ['tail', '-10', postgresql_logs[0]],
                            capture_output=True,
                            text=True,
                            timeout=10
                        )
                        
                        if tail_result.returncode == 0:
                            lines = tail_result.stdout.strip().split('\n')
                            
                            for line in lines:
                                print(f"  {line}")
                    except Exception as e:
                        print(f"  {Color.RED}Error al obtener logs de PostgreSQL: {str(e)}{Color.END}")
                    
                    print()
            
            return {
                'success': True,
                'message': 'Información de logs mostrada'
            }
        except Exception as e:
            logger.error(f"Error al mostrar información de logs: {e}")
            return {
                'success': False,
                'message': f"Error al mostrar información de logs: {str(e)}"
            }
    
    def run_utility_command(self, command, parameters=None):
        """Ejecutar un comando de utilidad"""
        try:
            if command == 'help':
                return self.show_help()
            elif command == 'exit':
                self.running = False
                return {
                    'success': True,
                    'message': 'Saliendo del asistente interactivo'
                }
            elif command == 'clear':
                os.system('clear')
                return {
                    'success': True,
                    'message': 'Pantalla limpiada'
                }
            elif command == 'history':
                return self.show_history()
            else:
                return {
                    'success': False,
                    'message': f"Comando de utilidad no soportado: {command}"
                }
        except Exception as e:
            logger.error(f"Error al ejecutar comando de utilidad: {e}")
            return {
                'success': False,
                'message': f"Error al ejecutar comando de utilidad: {str(e)}"
            }
    
    def show_help(self):
        """Mostrar ayuda sobre comandos disponibles"""
        try:
            print(f"{Color.CYAN}Asistente Interactivo de Virtualmin Enterprise{Color.END}")
            print(f"{Color.CYAN}========================================={Color.END}")
            print()
            
            print(f"{Color.YELLOW}Comandos Disponibles:{Color.END}")
            print()
            
            # Agrupar comandos por categoría
            categories = {}
            
            for command_id, command in self.commands.items():
                category = command['category']
                
                if category not in categories:
                    categories[category] = []
                
                categories[category].append({
                    'id': command_id,
                    'name': command['name'],
                    'description': command['description']
                })
            
            # Mostrar comandos por categoría
            for category, commands in categories.items():
                print(f"{Color.GREEN}{category.title()}:{Color.END}")
                
                for command in commands:
                    print(f"  {Color.CYAN}{command['id']}{Color.END} - {command['description']}")
                
                print()
            
            # Mostrar ejemplos de uso
            print(f"{Color.YELLOW}Ejemplos de Uso:{Color.END}")
            print(f"  {Color.CYAN}diagnose_all{Color.END} - Realizar un diagnóstico completo del sistema")
            print(f"  {Color.CYAN}fix_permissions{Color.END} - Reparar permisos de archivos y directorios")
            print(f"  {Color.CYAN}info_system{Color.END} - Mostrar información del sistema")
            print(f"  {Color.CYAN}help{Color.END} - Mostrar esta ayuda")
            print(f"  {Color.CYAN}exit{Color.END} - Salir del asistente")
            print()
            
            return {
                'success': True,
                'message': 'Ayuda mostrada'
            }
        except Exception as e:
            logger.error(f"Error al mostrar ayuda: {e}")
            return {
                'success': False,
                'message': f"Error al mostrar ayuda: {str(e)}"
            }
    
    def show_history(self):
        """Mostrar el historial de comandos"""
        try:
            print(f"{Color.CYAN}Historial de Comandos{Color.END}")
            print(f"{Color.CYAN}===================={Color.END}")
            print()
            
            if not self.history:
                print(f"{Color.YELLOW}No hay comandos en el historial{Color.END}")
            else:
                for i, item in enumerate(self.history[-10:], 1):  # Mostrar solo los últimos 10
                    timestamp = item['timestamp'].strftime('%Y-%m-%d %H:%M:%S')
                    command = item['command']
                    parameters = item['parameters']
                    
                    print(f"{i}. {timestamp} - {command}")
                    
                    if parameters:
                        print(f"   Parámetros: {json.dumps(parameters)}")
            
            print()
            
            return {
                'success': True,
                'message': 'Historial mostrado'
            }
        except Exception as e:
            logger.error(f"Error al mostrar historial: {e}")
            return {
                'success': False,
                'message': f"Error al mostrar historial: {str(e)}"
            }
    
    def generate_recommendations(self, results):
        """Generar recomendaciones basadas en los resultados del diagnóstico"""
        try:
            recommendations = []
            
            # Recomendaciones de servicios
            if 'services' in results and results['services']['success']:
                services_result = results['services']['results']
                
                for service_name, service_info in services_result['services'].items():
                    if not service_info['success']:
                        recommendations.append({
                            'title': f"Reparar servicio {service_name}",
                            'description': f"El servicio {service_name} está caído. Intenta iniciarlo manualmente o ejecuta el comando 'fix_services'.",
                            'category': 'services',
                            'priority': 'high'
                        })
            
            # Recomendaciones de seguridad
            if 'security' in results and results['security']['success']:
                security_result = results['security']['results']
                
                # Recomendaciones de SSL
                if 'ssl' in security_result and 'issues' in security_result['ssl']:
                    for issue in security_result['ssl']['issues']:
                        if issue['type'] == 'expired_certificate':
                            recommendations.append({
                                'title': "Renovar certificado SSL expirado",
                                'description': f"El certificado en {issue['path']} ha expirado. Renueva el certificado lo antes posible.",
                                'category': 'security',
                                'priority': 'critical'
                            })
                        elif issue['type'] == 'expiring_soon_certificate':
                            recommendations.append({
                                'title': "Renovar certificado SSL próximo a expirar",
                                'description': f"El certificado en {issue['path']} expirará en {issue['message']}. Renueva el certificado antes de que expire.",
                                'category': 'security',
                                'priority': 'high'
                            })
                
                # Recomendaciones de permisos
                if 'permissions' in security_result and 'issues' in security_result['permissions']:
                    for issue in security_result['permissions']['issues']:
                        if issue['type'] == 'incorrect_permissions':
                            recommendations.append({
                                'title': "Corregir permisos incorrectos",
                                'description': f"Los permisos en {issue['path']} son incorrectos. Corrige los permisos a {issue['expected_perms']}.",
                                'category': 'security',
                                'priority': 'medium'
                            })
                
                # Recomendaciones de firewall
                if 'firewall' in security_result and 'issues' in security_result['firewall']:
                    for issue in security_result['firewall']['issues']:
                        if issue['type'] == 'firewall_inactive':
                            recommendations.append({
                                'title': "Activar firewall",
                                'description': "El firewall está inactivo. Activa el firewall para mejorar la seguridad del sistema.",
                                'category': 'security',
                                'priority': 'high'
                            })
                
                # Recomendaciones de vulnerabilidades
                if 'vulnerabilities' in security_result and 'issues' in security_result['vulnerabilities']:
                    for issue in security_result['vulnerabilities']['issues']:
                        if issue['type'] == 'security_update':
                            recommendations.append({
                                'title': "Aplicar actualización de seguridad",
                                'description': f"Hay una actualización de seguridad disponible para {issue['package']}. Aplica la actualización lo antes posible.",
                                'category': 'security',
                                'priority': 'high'
                            })
                        elif issue['type'] == 'multiple_root_users':
                            recommendations.append({
                                'title': "Revisar usuarios con UID 0",
                                'description': f"Hay múltiples usuarios con UID 0: {issue['message']}. Revisa estos usuarios y elimina los que no sean necesarios.",
                                'category': 'security',
                                'priority': 'critical'
                            })
            
            # Recomendaciones de rendimiento
            if 'performance' in results and results['performance']['success']:
                performance_result = results['performance']['results']
                
                # Recomendaciones de CPU
                if 'cpu' in performance_result and 'issues' in performance_result['cpu']:
                    for issue in performance_result['cpu']['issues']:
                        if issue['type'] == 'high_cpu_usage':
                            recommendations.append({
                                'title': "Reducir uso de CPU",
                                'description': f"El uso de CPU es muy alto ({issue['value']:.2f}%). Identifica y optimiza los procesos que consumen más CPU.",
                                'category': 'performance',
                                'priority': 'high'
                            })
                
                # Recomendaciones de memoria
                if 'memory' in performance_result and 'issues' in performance_result['memory']:
                    for issue in performance_result['memory']['issues']:
                        if issue['type'] == 'high_memory_usage':
                            recommendations.append({
                                'title': "Reducir uso de memoria",
                                'description': f"El uso de memoria es muy alto ({issue['value']:.2f}%). Identifica y optimiza los procesos que consumen más memoria.",
                                'category': 'performance',
                                'priority': 'high'
                            })
                
                # Recomendaciones de disco
                if 'disk' in performance_result and 'issues' in performance_result['disk']:
                    for issue in performance_result['disk']['issues']:
                        if issue['type'] == 'high_disk_usage':
                            recommendations.append({
                                'title': "Liberar espacio en disco",
                                'description': f"El uso de disco en {issue['mountpoint']} es muy alto ({issue['usage_percentage']}%). Libera espacio en disco eliminando archivos innecesarios o moviéndolos a otro almacenamiento.",
                                'category': 'performance',
                                'priority': 'high'
                            })
            
            # Recomendaciones de red
            if 'network' in results and results['network']['success']:
                network_result = results['network']['results']
                
                # Recomendaciones de interfaces
                if 'interfaces' in network_result and 'issues' in network_result['interfaces']:
                    for issue in network_result['interfaces']['issues']:
                        if issue['type'] == 'interface_without_ip':
                            recommendations.append({
                                'title': "Configurar dirección IP",
                                'description': f"La interfaz {issue['interface']} está activa pero no tiene dirección IP. Configura una dirección IP estática o DHCP.",
                                'category': 'network',
                                'priority': 'high'
                            })
                
                # Recomendaciones de conectividad
                if 'connectivity' in network_result and 'issues' in network_result['connectivity']:
                    for issue in network_result['connectivity']['issues']:
                        if issue['type'] == 'no_external_connectivity':
                            recommendations.append({
                                'title': "Restaurar conectividad externa",
                                'description': "No hay conectividad externa. Verifica la configuración de red y el estado de la conexión a internet.",
                                'category': 'network',
                                'priority': 'critical'
                            })
                
                # Recomendaciones de DNS
                if 'dns' in network_result and 'issues' in network_result['dns']:
                    for issue in network_result['dns']['issues']:
                        if issue['type'] == 'no_dns_servers':
                            recommendations.append({
                                'title': "Configurar servidores DNS",
                                'description': "No hay servidores DNS configurados. Configura servidores DNS válidos en /etc/resolv.conf.",
                                'category': 'network',
                                'priority': 'high'
                            })
                        elif issue['type'] == 'dns_resolution_failed':
                            recommendations.append({
                                'title': "Reparar resolución de DNS",
                                'description': "La resolución de nombres está fallando. Verifica la configuración de DNS y el estado de los servidores DNS.",
                                'category': 'network',
                                'priority': 'high'
                            })
            
            return recommendations
        except Exception as e:
            logger.error(f"Error al generar recomendaciones: {e}")
            return []
    
    def generate_diagnostic_report(self, diagnostic_id, results, recommendations):
        """Generar un informe de diagnóstico"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.reports_dir, f"diagnostic_report_{timestamp}.html")
            
            # Contenido HTML
            html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Informe de Diagnóstico - {diagnostic_id}</title>
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
        .section {{
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ddd;
        }}
        .section-title {{
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }}
        .status {{
            margin-bottom: 15px;
            padding: 8px 12px;
            border-radius: 4px;
            font-weight: bold;
            text-align: center;
        }}
        .status.success {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .status.warning {{
            background-color: #fff3cd;
            color: #856404;
        }}
        .status.error {{
            background-color: #f8d7da;
            color: #721c24;
        }}
        .table {{
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 15px;
        }}
        .table th, .table td {{
            padding: 8px 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }}
        .table th {{
            background-color: #f2f2f2;
            font-weight: bold;
        }}
        .recommendation {{
            margin-bottom: 15px;
            padding: 10px;
            border-radius: 4px;
            background-color: #f8f9fa;
            border-left: 4px solid #007bff;
        }}
        .recommendation-title {{
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .recommendation.critical {{
            border-left-color: #dc3545;
        }}
        .recommendation.high {{
            border-left-color: #fd7e14;
        }}
        .recommendation.medium {{
            border-left-color: #20c997;
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
            <h1>Informe de Diagnóstico</h1>
            <p>ID: {diagnostic_id}</p>
            <p>Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        </div>
        
        <div class="section">
            <div class="section-title">Resumen</div>
"""
            
            # Añadir resumen de resultados
            if 'services' in results:
                services_result = results['services']['results']
                services_summary = services_result['summary']
                
                html_content += f"""
            <div class="status {'success' if services_summary['stopped'] == 0 else 'warning'}">
                Servicios: {services_summary['running']} en ejecución, {services_summary['stopped']} detenidos, {services_summary['failed']} con errores
            </div>
"""
            
            if 'security' in results:
                security_result = results['security']['results']
                security_summary = security_result['summary']
                
                html_content += f"""
            <div class="status {'success' if security_summary['issues_found'] == 0 else 'warning'}">
                Seguridad: {security_summary['checks_performed']} verificaciones realizadas, {security_summary['issues_found']} problemas encontrados
            </div>
"""
            
            if 'performance' in results:
                performance_result = results['performance']['results']
                performance_summary = performance_result['summary']
                
                html_content += f"""
            <div class="status {'success' if performance_summary['issues_found'] == 0 else 'warning'}">
                Rendimiento: {performance_summary['checks_performed']} verificaciones realizadas, {performance_summary['issues_found']} problemas encontrados
            </div>
"""
            
            if 'network' in results:
                network_result = results['network']['results']
                network_summary = network_result['summary']
                
                html_content += f"""
            <div class="status {'success' if network_summary['issues_found'] == 0 else 'warning'}">
                Red: {network_summary['checks_performed']} verificaciones realizadas, {network_summary['issues_found']} problemas encontrados
            </div>
"""
            
            html_content += """
        </div>
"""
            
            # Añadir detalles de servicios
            if 'services' in results:
                services_result = results['services']['results']
                
                html_content += f"""
        <div class="section">
            <div class="section-title">Servicios</div>
            <table class="table">
                <tr>
                    <th>Servicio</th>
                    <th>Estado</th>
                    <th>Descripción</th>
                </tr>
"""
                
                for service_name, service_info in services_result['services'].items():
                    status_class = 'success' if service_info['success'] else 'error'
                    status_text = 'Activo' if service_info['success'] else 'Inactivo'
                    description = service_info['info'].get('Description', 'N/A')
                    
                    html_content += f"""
                <tr>
                    <td>{service_name}</td>
                    <td class="{status_class}">{status_text}</td>
                    <td>{description}</td>
                </tr>
"""
                
                html_content += """
            </table>
        </div>
"""
            
            # Añadir detalles de seguridad
            if 'security' in results:
                security_result = results['security']['results']
                
                html_content += f"""
        <div class="section">
            <div class="section-title">Seguridad</div>
"""
                
                # Problemas de SSL
                if 'ssl' in security_result and 'issues' in security_result['ssl']:
                    ssl_issues = security_result['ssl']['issues']
                    
                    if ssl_issues:
                        html_content += f"""
            <h3>Certificados SSL</h3>
            <div class="status error">Se encontraron {len(ssl_issues)} problemas con certificados SSL</div>
            <table class="table">
                <tr>
                    <th>Tipo</th>
                    <th>Ruta</th>
                    <th>Mensaje</th>
                </tr>
"""
                        
                        for issue in ssl_issues:
                            html_content += f"""
                <tr>
                    <td>{issue['type']}</td>
                    <td>{issue['path']}</td>
                    <td>{issue['message']}</td>
                </tr>
"""
                        
                        html_content += """
            </table>
                    """
                    else:
                        html_content += """
            <div class="status success">No se encontraron problemas con certificados SSL</div>
"""
                
                # Problemas de permisos
                if 'permissions' in security_result and 'issues' in security_result['permissions']:
                    permission_issues = security_result['permissions']['issues']
                    
                    if permission_issues:
                        html_content += f"""
            <h3>Permisos</h3>
            <div class="status error">Se encontraron {len(permission_issues)} problemas de permisos</div>
            <table class="table">
                <tr>
                    <th>Tipo</th>
                    <th>Ruta</th>
                    <th>Permisos Actuales</th>
                    <th>Permisos Esperados</th>
                </tr>
"""
                        
                        for issue in permission_issues:
                            html_content += f"""
                <tr>
                    <td>{issue['type']}</td>
                    <td>{issue['path']}</td>
                    <td>{issue['current_perms']}</td>
                    <td>{issue['expected_perms']}</td>
                </tr>
"""
                        
                        html_content += """
            </table>
                    """
                    else:
                        html_content += """
            <div class="status success">No se encontraron problemas de permisos</div>
"""
                
                # Problemas de firewall
                if 'firewall' in security_result and 'issues' in security_result['firewall']:
                    firewall_issues = security_result['firewall']['issues']
                    
                    if firewall_issues:
                        html_content += f"""
            <h3>Firewall</h3>
            <div class="status error">Se encontraron {len(firewall_issues)} problemas con el firewall</div>
            <table class="table">
                <tr>
                    <th>Tipo</th>
                    <th>Mensaje</th>
                </tr>
"""
                        
                        for issue in firewall_issues:
                            html_content += f"""
                <tr>
                    <td>{issue['type']}</td>
                    <td>{issue['message']}</td>
                </tr>
"""
                        
                        html_content += """
            </table>
                    """
                    else:
                        html_content += """
            <div class="status success">No se encontraron problemas con el firewall</div>
"""
                
                # Problemas de vulnerabilidades
                if 'vulnerabilities' in security_result and 'issues' in security_result['vulnerabilities']:
                    vulnerability_issues = security_result['vulnerabilities']['issues']
                    
                    if vulnerability_issues:
                        html_content += f"""
            <h3>Vulnerabilidades</h3>
            <div class="status error">Se encontraron {len(vulnerability_issues)} vulnerabilidades</div>
            <table class="table">
                <tr>
                    <th>Tipo</th>
                    <th>Paquete</th>
                    <th>Mensaje</th>
                </tr>
"""
                        
                        for issue in vulnerability_issues:
                            html_content += f"""
                <tr>
                    <td>{issue['type']}</td>
                    <td>{issue.get('package', 'N/A')}</td>
                    <td>{issue['message']}</td>
                </tr>
"""
                        
                        html_content += """
            </table>
                    """
                    else:
                        html_content += """
            <div class="status success">No se encontraron vulnerabilidades críticas</div>
"""
                
                html_content += """
        </div>
"""
            
            # Añadir recomendaciones
            if recommendations:
                html_content += f"""
        <div class="section">
            <div class="section-title">Recomendaciones</div>
"""
                
                for recommendation in recommendations:
                    priority_class = recommendation['priority']
                    
                    html_content += f"""
            <div class="recommendation {priority_class}">
                <div class="recommendation-title">{recommendation['title']}</div>
                <div>{recommendation['description']}</div>
            </div>
"""
                
                html_content += """
        </div>
"""
            
            # Cerrar HTML
            html_content += f"""
    </div>
    
    <div class="footer">
        <p>Informe generado por Asistente Interactivo de Virtualmin Enterprise</p>
        <p>Fecha de generación: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    </div>
</body>
</html>
"""
            
            # Escribir archivo HTML
            with open(report_file, 'w') as f:
                f.write(html_content)
            
            logger.info(f"Informe de diagnóstico generado: {report_file}")
            return report_file
        except Exception as e:
            logger.error(f"Error al generar informe de diagnóstico: {e}")
            return None
    
    def start_interactive_mode(self):
        """Iniciar modo interactivo"""
        try:
            print(f"{Color.CYAN}Asistente Interactivo de Virtualmin Enterprise{Color.END}")
            print(f"{Color.CYAN}========================================={Color.END}")
            print(f"{Color.CYAN}Escribe 'help' para ver los comandos disponibles{Color.END}")
            print(f"{Color.CYAN}Escribe 'exit' para salir{Color.END}")
            print()
            
            session_id = str(int(time.time()))
            
            # Bucle principal del modo interactivo
            while self.running:
                try:
                    # Mostrar prompt
                    command_input = input(f"{Color.GREEN}virtualmin-assistant>{Color.END} ").strip()
                    
                    # Procesar comando
                    if command_input:
                        # Guardar en historial
                        self.save_to_history(session_id, command_input)
                        
                        # Dividir comando y parámetros
                        parts = command_input.split()
                        command = parts[0]
                        parameters = parts[1:] if len(parts) > 1 else []
                        
                        # Ejecutar comando
                        result = self.run_command(command, parameters)
                        
                        if not result['success']:
                            print(f"{Color.RED}Error: {result['message']}{Color.END}")
                except KeyboardInterrupt:
                    print(f"\n{Color.YELLOW}Use 'exit' para salir{Color.END}")
                except EOFError:
                    print(f"\n{Color.YELLOW}Use 'exit' para salir{Color.END}")
            
            print(f"{Color.CYAN}¡Hasta luego!{Color.END}")
            
            return True
        except Exception as e:
            logger.error(f"Error en modo interactivo: {e}")
            return False
    
    def save_to_history(self, session_id, command):
        """Guardar comando en el historial"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO history (session_id, command, timestamp)
                VALUES (?, ?, ?)
            ''', (session_id, command, datetime.now()))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al guardar en historial: {e}")
            return False

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Asistente Interactivo de Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/assistant/assistant_config.json')
    parser.add_argument('--command', help='Ejecutar un comando específico')
    parser.add_argument('--parameters', help='Parámetros para el comando (formato JSON)')
    parser.add_argument('--interactive', action='store_true', help='Iniciar modo interactivo')
    parser.add_argument('--install', action='store_true', help='Instalar el asistente')
    
    args = parser.parse_args()
    
    if args.install:
        # Instalar el asistente
        install_assistant()
        return
    
    # Inicializar asistente
    assistant = InteractiveAssistant(args.config)
    
    if args.interactive:
        # Iniciar modo interactivo
        assistant.start_interactive_mode()
    elif args.command:
        # Ejecutar comando específico
        parameters = {}
        
        if args.parameters:
            try:
                parameters = json.loads(args.parameters)
            except json.JSONDecodeError:
                parameters = {'param': args.parameters}
        
        result = assistant.run_command(args.command, parameters)
        
        if result['success']:
            print(f"Comando ejecutado exitosamente")
            if 'message' in result:
                print(f"Mensaje: {result['message']}")
        else:
            print(f"Error al ejecutar comando: {result['message']}")
            sys.exit(1)
    else:
        # Iniciar modo interactivo por defecto
        assistant.start_interactive_mode()

def install_assistant():
    """Instalar el asistente"""
    try:
        print("Instalando Asistente Interactivo de Virtualmin Enterprise...")
        
        # Crear directorios necesarios
        directories = [
            '/opt/virtualmin-enterprise/assistant',
            '/opt/virtualmin-enterprise/assistant/commands',
            '/opt/virtualmin-enterprise/assistant/reports',
            '/var/log/virtualmin-enterprise'
        ]
        
        for directory in directories:
            os.makedirs(directory, exist_ok=True)
        
        # Crear enlace simbólico
        script_path = os.path.abspath(__file__)
        link_path = '/usr/local/bin/virtualmin-assistant'
        
        if os.path.exists(link_path):
            os.remove(link_path)
        
        os.symlink(script_path, link_path)
        
        # Crear servicio systemd
        service_content = """[Unit]
Description=Virtualmin Enterprise Interactive Assistant
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 """ + script_path + """ --interactive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
        
        with open('/etc/systemd/system/virtualmin-assistant.service', 'w') as f:
            f.write(service_content)
        
        # Recargar systemd y habilitar servicio
        subprocess.run(['systemctl', 'daemon-reload'], check=True)
        subprocess.run(['systemctl', 'enable', 'virtualmin-assistant'], check=False)
        
        print("Asistente Interactivo de Virtualmin Enterprise instalado exitosamente")
        print("Para iniciar el asistente en modo interactivo, ejecuta:")
        print("  sudo systemctl start virtualmin-assistant")
        print("O para ejecutar un comando específico, ejecuta:")
        print("  virtualmin-assistant --command <comando>")
        print("")
        print("Para ver los comandos disponibles, ejecuta:")
        print("  virtualmin-assistant --command help")
        
        return True
    except Exception as e:
        print(f"Error al instalar el asistente: {e}")
        return False

if __name__ == "__main__":
    main()