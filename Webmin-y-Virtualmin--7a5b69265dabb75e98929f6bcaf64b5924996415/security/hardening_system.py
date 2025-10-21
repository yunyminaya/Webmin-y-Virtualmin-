#!/usr/bin/env python3

# Sistema de Hardening Automático con Escaneo de Vulnerabilidades
# para Virtualmin Enterprise

import json
import os
import sys
import time
import hashlib
import subprocess
import re
import logging
import sqlite3
import requests
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import configparser

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/hardening.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class HardeningSystem:
    def __init__(self, config_file=None):
        """Inicializar el sistema de hardening"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/security/hardening.db')
        self.reports_dir = self.config.get('reports', {}).get('path', '/opt/virtualmin-enterprise/security/reports')
        self.scanners_dir = self.config.get('scanners', {}).get('path', '/opt/virtualmin-enterprise/security/scanners')
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/security/hardening.db"
            },
            "reports": {
                "path": "/opt/virtualmin-enterprise/security/reports",
                "format": ["html", "json", "pdf"],
                "retention_days": 90
            },
            "scanners": {
                "path": "/opt/virtualmin-enterprise/security/scanners",
                "nmap": True,
                "lynis": True,
                "openvas": False,
                "nikto": True,
                "sslscan": True,
                "trivy": True
            },
            "hardening": {
                "auto_apply": False,
                "require_confirmation": True,
                "backup_before_changes": True,
                "schedule": "weekly",
                "categories": [
                    "system",
                    "network",
                    "services",
                    "filesystem",
                    "ssl",
                    "users",
                    "firewall"
                ]
            },
            "notification": {
                "email_enabled": False,
                "smtp_server": "",
                "smtp_port": 587,
                "smtp_username": "",
                "smtp_password": "",
                "slack_webhook": "",
                "critical_threshold": 5
            },
            "compliance": {
                "standards": ["cis", "nist", "pci-dss"],
                "profile": "level-1"
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
            '/opt/virtualmin-enterprise/security',
            os.path.dirname(self.db_path),
            self.reports_dir,
            self.scanners_dir,
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
            
            # Crear tabla de escaneos
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS scans (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    scan_type TEXT NOT NULL,
                    scanner TEXT NOT NULL,
                    target TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    results TEXT,
                    vulnerabilities_count INTEGER DEFAULT 0,
                    high_count INTEGER DEFAULT 0,
                    medium_count INTEGER DEFAULT 0,
                    low_count INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de vulnerabilidades
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS vulnerabilities (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    scan_id INTEGER,
                    title TEXT NOT NULL,
                    description TEXT,
                    severity TEXT,
                    category TEXT,
                    cve_id TEXT,
                    cvss_score REAL,
                    affected_service TEXT,
                    affected_port INTEGER,
                    recommendation TEXT,
                    references TEXT,
                    status TEXT DEFAULT 'open',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (scan_id) REFERENCES scans (id)
                )
            ''')
            
            # Crear tabla de acciones de hardening
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS hardening_actions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    vulnerability_id INTEGER,
                    action_type TEXT NOT NULL,
                    command TEXT,
                    description TEXT,
                    status TEXT DEFAULT 'pending',
                    result TEXT,
                    applied_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (vulnerability_id) REFERENCES vulnerabilities (id)
                )
            ''')
            
            # Crear tabla de backups
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS backups (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    file_path TEXT NOT NULL,
                    file_hash TEXT,
                    description TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de configuraciones de hardening
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS hardening_configs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    category TEXT NOT NULL,
                    name TEXT NOT NULL,
                    value TEXT,
                    default_value TEXT,
                    description TEXT,
                    is_applied BOOLEAN DEFAULT 0,
                    applied_at TIMESTAMP,
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
    
    def run_command(self, command, timeout=300, capture_output=True):
        """Ejecutar comando del sistema"""
        try:
            logger.info(f"Ejecutando comando: {command}")
            
            if capture_output:
                result = subprocess.run(
                    command,
                    shell=True,
                    timeout=timeout,
                    capture_output=True,
                    text=True
                )
                return {
                    'success': result.returncode == 0,
                    'stdout': result.stdout,
                    'stderr': result.stderr,
                    'returncode': result.returncode
                }
            else:
                result = subprocess.run(
                    command,
                    shell=True,
                    timeout=timeout
                )
                return {
                    'success': result.returncode == 0,
                    'returncode': result.returncode
                }
        except subprocess.TimeoutExpired:
            logger.error(f"Comando expiró: {command}")
            return {
                'success': False,
                'error': 'Command timed out'
            }
        except Exception as e:
            logger.error(f"Error al ejecutar comando: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def backup_file(self, file_path):
        """Crear backup de un archivo antes de modificarlo"""
        try:
            if not os.path.exists(file_path):
                return {'success': False, 'message': f'El archivo no existe: {file_path}'}
            
            # Crear directorio de backups si no existe
            backup_dir = os.path.join(self.reports_dir, 'backups')
            os.makedirs(backup_dir, exist_ok=True)
            
            # Generar nombre de archivo de backup
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = os.path.basename(file_path)
            backup_path = os.path.join(backup_dir, f"{filename}.{timestamp}.bak")
            
            # Copiar archivo
            subprocess.run(['cp', file_path, backup_path], check=True)
            
            # Calcular hash del archivo
            file_hash = self.calculate_file_hash(file_path)
            
            # Guardar información del backup en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO backups (file_path, file_hash, description)
                VALUES (?, ?, ?)
            ''', (file_path, file_hash, f"Backup automático antes de modificación"))
            
            conn.commit()
            conn.close()
            
            logger.info(f"Backup creado: {backup_path}")
            return {
                'success': True,
                'backup_path': backup_path,
                'file_hash': file_hash
            }
        except Exception as e:
            logger.error(f"Error al crear backup: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def calculate_file_hash(self, file_path):
        """Calcular hash SHA256 de un archivo"""
        try:
            sha256_hash = hashlib.sha256()
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    sha256_hash.update(chunk)
            return sha256_hash.hexdigest()
        except Exception as e:
            logger.error(f"Error al calcular hash del archivo: {e}")
            return None
    
    def scan_with_nmap(self, target, options="-sV -sC -O"):
        """Realizar escaneo con Nmap"""
        if not self.config['scanners']['nmap']:
            return {'success': False, 'message': 'Nmap scanner no está habilitado'}
        
        try:
            command = f"nmap {options} {target}"
            result = self.run_command(command, timeout=600)
            
            if result['success']:
                # Guardar resultados en la base de datos
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                scan_id = cursor.execute('''
                    INSERT INTO scans (scan_type, scanner, target, status, start_time, end_time, results)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    'network',
                    'nmap',
                    target,
                    'completed',
                    datetime.now(),
                    datetime.now(),
                    result['stdout']
                )).lastrowid
                
                # Procesar resultados para extraer vulnerabilidades
                vulnerabilities = self.parse_nmap_results(result['stdout'], scan_id)
                
                # Actualizar contador de vulnerabilidades
                cursor.execute('''
                    UPDATE scans SET 
                    vulnerabilities_count = ?,
                    high_count = ?,
                    medium_count = ?,
                    low_count = ?
                    WHERE id = ?
                ''', (
                    len(vulnerabilities),
                    sum(1 for v in vulnerabilities if v['severity'] == 'high'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'medium'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'low'),
                    scan_id
                ))
                
                conn.commit()
                conn.close()
                
                return {
                    'success': True,
                    'scan_id': scan_id,
                    'vulnerabilities': vulnerabilities
                }
            else:
                return {
                    'success': False,
                    'error': result.get('stderr', 'Unknown error')
                }
        except Exception as e:
            logger.error(f"Error en escaneo Nmap: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def parse_nmap_results(self, nmap_output, scan_id):
        """Procesar resultados de Nmap para extraer vulnerabilidades"""
        vulnerabilities = []
        
        try:
            # Extraer información de servicios y puertos
            port_pattern = r'(\d+)/(\w+)\s+open\s+(\w+)\s+(.+)'
            service_pattern = r'(.+):\s+(.+)'
            
            for line in nmap_output.split('\n'):
                port_match = re.search(port_pattern, line)
                if port_match:
                    port = int(port_match.group(1))
                    protocol = port_match.group(2)
                    state = port_match.group(3)
                    service = port_match.group(4)
                    
                    # Buscar vulnerabilidades conocidas para este servicio
                    if 'ssl' in service.lower() or 'https' in service.lower():
                        vulnerabilities.append({
                            'scan_id': scan_id,
                            'title': f'Servicio SSL/TLS en puerto {port}',
                            'description': f'Se detectó un servicio SSL/TLS en el puerto {port}',
                            'severity': 'medium',
                            'category': 'ssl',
                            'affected_service': service,
                            'affected_port': port,
                            'recommendation': 'Verificar configuración SSL/TLS y actualizar certificados'
                        })
                    
                    if 'ssh' in service.lower():
                        vulnerabilities.append({
                            'scan_id': scan_id,
                            'title': f'Servicio SSH en puerto {port}',
                            'description': f'Se detectó un servicio SSH en el puerto {port}',
                            'severity': 'low',
                            'category': 'services',
                            'affected_service': service,
                            'affected_port': port,
                            'recommendation': 'Asegurar configuración SSH y deshabilitar autenticación por contraseña'
                        })
            
            # Guardar vulnerabilidades en la base de datos
            if vulnerabilities:
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                for vuln in vulnerabilities:
                    cursor.execute('''
                        INSERT INTO vulnerabilities (
                            scan_id, title, description, severity, category,
                            affected_service, affected_port, recommendation
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        vuln['scan_id'],
                        vuln['title'],
                        vuln['description'],
                        vuln['severity'],
                        vuln['category'],
                        vuln['affected_service'],
                        vuln['affected_port'],
                        vuln['recommendation']
                    ))
                
                conn.commit()
                conn.close()
            
            return vulnerabilities
        except Exception as e:
            logger.error(f"Error al procesar resultados de Nmap: {e}")
            return []
    
    def scan_with_lynis(self, target="localhost"):
        """Realizar escaneo con Lynis"""
        if not self.config['scanners']['lynis']:
            return {'success': False, 'message': 'Lynis scanner no está habilitado'}
        
        try:
            # Verificar si Lynis está instalado
            check_result = self.run_command("which lynis")
            if not check_result['success']:
                # Instalar Lynis
                install_result = self.run_command("apt-get update && apt-get install -y lynis")
                if not install_result['success']:
                    return {'success': False, 'message': 'No se pudo instalar Lynis'}
            
            # Crear directorio para reportes de Lynis
            lynis_report_dir = os.path.join(self.reports_dir, 'lynis')
            os.makedirs(lynis_report_dir, exist_ok=True)
            
            # Ejecutar escaneo
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(lynis_report_dir, f"lynis_report_{timestamp}.dat")
            
            command = f"lynis audit system --report-file {report_file}"
            result = self.run_command(command, timeout=600)
            
            if result['success']:
                # Guardar resultados en la base de datos
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                scan_id = cursor.execute('''
                    INSERT INTO scans (scan_type, scanner, target, status, start_time, end_time, results)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    'system',
                    'lynis',
                    target,
                    'completed',
                    datetime.now(),
                    datetime.now(),
                    report_file
                )).lastrowid
                
                # Procesar resultados para extraer vulnerabilidades
                vulnerabilities = self.parse_lynis_results(report_file, scan_id)
                
                # Actualizar contador de vulnerabilidades
                cursor.execute('''
                    UPDATE scans SET 
                    vulnerabilities_count = ?,
                    high_count = ?,
                    medium_count = ?,
                    low_count = ?
                    WHERE id = ?
                ''', (
                    len(vulnerabilities),
                    sum(1 for v in vulnerabilities if v['severity'] == 'high'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'medium'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'low'),
                    scan_id
                ))
                
                conn.commit()
                conn.close()
                
                return {
                    'success': True,
                    'scan_id': scan_id,
                    'report_file': report_file,
                    'vulnerabilities': vulnerabilities
                }
            else:
                return {
                    'success': False,
                    'error': result.get('stderr', 'Unknown error')
                }
        except Exception as e:
            logger.error(f"Error en escaneo Lynis: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def parse_lynis_results(self, report_file, scan_id):
        """Procesar resultados de Lynis para extraer vulnerabilidades"""
        vulnerabilities = []
        
        try:
            # Leer archivo de reporte
            with open(report_file, 'r') as f:
                report_content = f.read()
            
            # Extraer advertencias y sugerencias
            warning_pattern = r'\[(\d+)\]\s+(WARNING|SUGGESTION)\s+(.+?)\s+\[(.+?)\]'
            
            for match in re.finditer(warning_pattern, report_content, re.MULTILINE | re.DOTALL):
                test_id = match.group(1)
                warning_type = match.group(2)
                description = match.group(3).strip()
                category = match.group(4).strip()
                
                # Determinar severidad
                if warning_type == 'WARNING':
                    severity = 'medium'
                else:  # SUGGESTION
                    severity = 'low'
                
                # Buscar recomendación
                recommendation_pattern = rf'\[{test_id}\].*?Recommendation:\s+(.+?)(?:\n\[|\n$)'
                recommendation_match = re.search(recommendation_pattern, report_content, re.MULTILINE | re.DOTALL)
                recommendation = recommendation_match.group(1).strip() if recommendation_match else "Consultar documentación de Lynis"
                
                vulnerabilities.append({
                    'scan_id': scan_id,
                    'title': f'Lynis {warning_type}: {description[:50]}...',
                    'description': description,
                    'severity': severity,
                    'category': category.lower().replace(' ', '_'),
                    'recommendation': recommendation
                })
            
            # Guardar vulnerabilidades en la base de datos
            if vulnerabilities:
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                for vuln in vulnerabilities:
                    cursor.execute('''
                        INSERT INTO vulnerabilities (
                            scan_id, title, description, severity, category, recommendation
                        ) VALUES (?, ?, ?, ?, ?, ?)
                    ''', (
                        vuln['scan_id'],
                        vuln['title'],
                        vuln['description'],
                        vuln['severity'],
                        vuln['category'],
                        vuln['recommendation']
                    ))
                
                conn.commit()
                conn.close()
            
            return vulnerabilities
        except Exception as e:
            logger.error(f"Error al procesar resultados de Lynis: {e}")
            return []
    
    def scan_with_nikto(self, target):
        """Realizar escaneo con Nikto"""
        if not self.config['scanners']['nikto']:
            return {'success': False, 'message': 'Nikto scanner no está habilitado'}
        
        try:
            # Verificar si Nikto está instalado
            check_result = self.run_command("which nikto")
            if not check_result['success']:
                # Instalar Nikto
                install_result = self.run_command("apt-get update && apt-get install -y nikto")
                if not install_result['success']:
                    return {'success': False, 'message': 'No se pudo instalar Nikto'}
            
            # Crear directorio para reportes de Nikto
            nikto_report_dir = os.path.join(self.reports_dir, 'nikto')
            os.makedirs(nikto_report_dir, exist_ok=True)
            
            # Ejecutar escaneo
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(nikto_report_dir, f"nikto_report_{timestamp}.xml")
            
            command = f"nikto -h {target} -o {report_file} -Format xml"
            result = self.run_command(command, timeout=600)
            
            if result['success']:
                # Guardar resultados en la base de datos
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                scan_id = cursor.execute('''
                    INSERT INTO scans (scan_type, scanner, target, status, start_time, end_time, results)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    'web',
                    'nikto',
                    target,
                    'completed',
                    datetime.now(),
                    datetime.now(),
                    report_file
                )).lastrowid
                
                # Procesar resultados para extraer vulnerabilidades
                vulnerabilities = self.parse_nikto_results(report_file, scan_id)
                
                # Actualizar contador de vulnerabilidades
                cursor.execute('''
                    UPDATE scans SET 
                    vulnerabilities_count = ?,
                    high_count = ?,
                    medium_count = ?,
                    low_count = ?
                    WHERE id = ?
                ''', (
                    len(vulnerabilities),
                    sum(1 for v in vulnerabilities if v['severity'] == 'high'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'medium'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'low'),
                    scan_id
                ))
                
                conn.commit()
                conn.close()
                
                return {
                    'success': True,
                    'scan_id': scan_id,
                    'report_file': report_file,
                    'vulnerabilities': vulnerabilities
                }
            else:
                return {
                    'success': False,
                    'error': result.get('stderr', 'Unknown error')
                }
        except Exception as e:
            logger.error(f"Error en escaneo Nikto: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def parse_nikto_results(self, report_file, scan_id):
        """Procesar resultados de Nikto para extraer vulnerabilidades"""
        vulnerabilities = []
        
        try:
            # Leer archivo XML
            import xml.etree.ElementTree as ET
            
            tree = ET.parse(report_file)
            root = tree.getroot()
            
            # Extraer elementos item (vulnerabilidades)
            for item in root.findall('.//item'):
                osvdb = item.get('osvdb', '')
                title = item.findtext('message', '').strip()
                
                # Determinar severidad basada en OSVDB
                if osvdb:
                    osvdb_id = int(osvdb)
                    if osvdb_id >= 10000:
                        severity = 'high'
                    elif osvdb_id >= 1000:
                        severity = 'medium'
                    else:
                        severity = 'low'
                else:
                    severity = 'medium'  # Por defecto
                
                # Extraer información adicional
                description = title
                category = 'web'
                
                # Buscar recomendación
                recommendation = "Consultar documentación de seguridad web para más detalles"
                
                vulnerabilities.append({
                    'scan_id': scan_id,
                    'title': f'Nikto: {title[:50]}...',
                    'description': description,
                    'severity': severity,
                    'category': category,
                    'cve_id': f"OSVDB-{osvdb}" if osvdb else None,
                    'recommendation': recommendation
                })
            
            # Guardar vulnerabilidades en la base de datos
            if vulnerabilities:
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                for vuln in vulnerabilities:
                    cursor.execute('''
                        INSERT INTO vulnerabilities (
                            scan_id, title, description, severity, category, cve_id, recommendation
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        vuln['scan_id'],
                        vuln['title'],
                        vuln['description'],
                        vuln['severity'],
                        vuln['category'],
                        vuln['cve_id'],
                        vuln['recommendation']
                    ))
                
                conn.commit()
                conn.close()
            
            return vulnerabilities
        except Exception as e:
            logger.error(f"Error al procesar resultados de Nikto: {e}")
            return []
    
    def scan_with_sslscan(self, target):
        """Realizar escaneo con SSLScan"""
        if not self.config['scanners']['sslscan']:
            return {'success': False, 'message': 'SSLScan scanner no está habilitado'}
        
        try:
            # Verificar si SSLScan está instalado
            check_result = self.run_command("which sslscan")
            if not check_result['success']:
                # Instalar SSLScan
                install_result = self.run_command("apt-get update && apt-get install -y sslscan")
                if not install_result['success']:
                    return {'success': False, 'message': 'No se pudo instalar SSLScan'}
            
            # Crear directorio para reportes de SSLScan
            sslscan_report_dir = os.path.join(self.reports_dir, 'sslscan')
            os.makedirs(sslscan_report_dir, exist_ok=True)
            
            # Ejecutar escaneo
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(sslscan_report_dir, f"sslscan_report_{timestamp}.xml")
            
            command = f"sslscan --xml={report_file} {target}"
            result = self.run_command(command, timeout=300)
            
            if result['success']:
                # Guardar resultados en la base de datos
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                scan_id = cursor.execute('''
                    INSERT INTO scans (scan_type, scanner, target, status, start_time, end_time, results)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    'ssl',
                    'sslscan',
                    target,
                    'completed',
                    datetime.now(),
                    datetime.now(),
                    report_file
                )).lastrowid
                
                # Procesar resultados para extraer vulnerabilidades
                vulnerabilities = self.parse_sslscan_results(report_file, scan_id)
                
                # Actualizar contador de vulnerabilidades
                cursor.execute('''
                    UPDATE scans SET 
                    vulnerabilities_count = ?,
                    high_count = ?,
                    medium_count = ?,
                    low_count = ?
                    WHERE id = ?
                ''', (
                    len(vulnerabilities),
                    sum(1 for v in vulnerabilities if v['severity'] == 'high'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'medium'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'low'),
                    scan_id
                ))
                
                conn.commit()
                conn.close()
                
                return {
                    'success': True,
                    'scan_id': scan_id,
                    'report_file': report_file,
                    'vulnerabilities': vulnerabilities
                }
            else:
                return {
                    'success': False,
                    'error': result.get('stderr', 'Unknown error')
                }
        except Exception as e:
            logger.error(f"Error en escaneo SSLScan: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def parse_sslscan_results(self, report_file, scan_id):
        """Procesar resultados de SSLScan para extraer vulnerabilidades"""
        vulnerabilities = []
        
        try:
            # Leer archivo XML
            import xml.etree.ElementTree as ET
            
            tree = ET.parse(report_file)
            root = tree.getroot()
            
            # Extraer información sobre certificados
            for cert in root.findall('.//certificate'):
                # Verificar si el certificado está autofirmado
                self_signed = cert.findtext('self-signed', '0')
                if self_signed == '1':
                    vulnerabilities.append({
                        'scan_id': scan_id,
                        'title': 'Certificado SSL autofirmado',
                        'description': 'El certificado SSL está autofirmado, lo que no proporciona validación de confianza',
                        'severity': 'medium',
                        'category': 'ssl',
                        'recommendation': 'Obtener un certificado SSL de una autoridad de certificación confiable'
                    })
                
                # Verificar si el certificado ha expirado
                not_after = cert.findtext('not-after')
                if not_after:
                    try:
                        expiry_date = datetime.strptime(not_after, '%Y-%m-%d %H:%M:%S')
                        if expiry_date < datetime.now():
                            vulnerabilities.append({
                                'scan_id': scan_id,
                                'title': 'Certificado SSL expirado',
                                'description': f'El certificado SSL expiró el {not_after}',
                                'severity': 'high',
                                'category': 'ssl',
                                'recommendation': 'Renovar el certificado SSL inmediatamente'
                            })
                    except ValueError:
                        pass
            
            # Extraer información sobre protocolos y cifrados
            for test in root.findall('.//ssltest'):
                protocol = test.get('protocol', '')
                
                # Verificar protocolos débiles
                if protocol in ['SSLv2', 'SSLv3']:
                    vulnerabilities.append({
                        'scan_id': scan_id,
                        'title': f'Protocolo SSL débil detectado: {protocol}',
                        'description': f'Se detectó el uso del protocolo {protocol}, que tiene vulnerabilidades conocidas',
                        'severity': 'high',
                        'category': 'ssl',
                        'recommendation': f'Deshabilitar el protocolo {protocol} y usar TLS 1.2 o superior'
                    })
            
            # Guardar vulnerabilidades en la base de datos
            if vulnerabilities:
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                for vuln in vulnerabilities:
                    cursor.execute('''
                        INSERT INTO vulnerabilities (
                            scan_id, title, description, severity, category, recommendation
                        ) VALUES (?, ?, ?, ?, ?, ?)
                    ''', (
                        vuln['scan_id'],
                        vuln['title'],
                        vuln['description'],
                        vuln['severity'],
                        vuln['category'],
                        vuln['recommendation']
                    ))
                
                conn.commit()
                conn.close()
            
            return vulnerabilities
        except Exception as e:
            logger.error(f"Error al procesar resultados de SSLScan: {e}")
            return []
    
    def scan_with_trivy(self, target):
        """Realizar escaneo con Trivy"""
        if not self.config['scanners']['trivy']:
            return {'success': False, 'message': 'Trivy scanner no está habilitado'}
        
        try:
            # Verificar si Trivy está instalado
            check_result = self.run_command("which trivy")
            if not check_result['success']:
                # Instalar Trivy
                install_result = self.run_command("apt-get update && apt-get install -y wget apt-transport-https gnupg lsb-release && wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add - && echo \"deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main\" | tee -a /etc/apt/sources.list.d/trivy.list && apt-get update && apt-get install -y trivy")
                if not install_result['success']:
                    return {'success': False, 'message': 'No se pudo instalar Trivy'}
            
            # Crear directorio para reportes de Trivy
            trivy_report_dir = os.path.join(self.reports_dir, 'trivy')
            os.makedirs(trivy_report_dir, exist_ok=True)
            
            # Ejecutar escaneo
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(trivy_report_dir, f"trivy_report_{timestamp}.json")
            
            command = f"trivy image --format json --output {report_file} {target}"
            result = self.run_command(command, timeout=600)
            
            if result['success']:
                # Guardar resultados en la base de datos
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                scan_id = cursor.execute('''
                    INSERT INTO scans (scan_type, scanner, target, status, start_time, end_time, results)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                ''', (
                    'container',
                    'trivy',
                    target,
                    'completed',
                    datetime.now(),
                    datetime.now(),
                    report_file
                )).lastrowid
                
                # Procesar resultados para extraer vulnerabilidades
                vulnerabilities = self.parse_trivy_results(report_file, scan_id)
                
                # Actualizar contador de vulnerabilidades
                cursor.execute('''
                    UPDATE scans SET 
                    vulnerabilities_count = ?,
                    high_count = ?,
                    medium_count = ?,
                    low_count = ?
                    WHERE id = ?
                ''', (
                    len(vulnerabilities),
                    sum(1 for v in vulnerabilities if v['severity'] == 'high'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'medium'),
                    sum(1 for v in vulnerabilities if v['severity'] == 'low'),
                    scan_id
                ))
                
                conn.commit()
                conn.close()
                
                return {
                    'success': True,
                    'scan_id': scan_id,
                    'report_file': report_file,
                    'vulnerabilities': vulnerabilities
                }
            else:
                return {
                    'success': False,
                    'error': result.get('stderr', 'Unknown error')
                }
        except Exception as e:
            logger.error(f"Error en escaneo Trivy: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def parse_trivy_results(self, report_file, scan_id):
        """Procesar resultados de Trivy para extraer vulnerabilidades"""
        vulnerabilities = []
        
        try:
            # Leer archivo JSON
            with open(report_file, 'r') as f:
                report_data = json.load(f)
            
            # Extraer vulnerabilidades
            for result in report_data.get('Results', []):
                for vuln in result.get('Vulnerabilities', []):
                    # Mapear severidad
                    severity = vuln.get('Severity', 'UNKNOWN').lower()
                    if severity in ['critical', 'high']:
                        mapped_severity = 'high'
                    elif severity in ['medium']:
                        mapped_severity = 'medium'
                    else:
                        mapped_severity = 'low'
                    
                    vulnerabilities.append({
                        'scan_id': scan_id,
                        'title': vuln.get('Title', 'Vulnerabilidad sin título'),
                        'description': vuln.get('Description', ''),
                        'severity': mapped_severity,
                        'category': 'container',
                        'cve_id': vuln.get('VulnerabilityID', ''),
                        'cvss_score': vuln.get('CVSS', {}).get('nvd', {}).get('V3Score'),
                        'references': json.dumps(vuln.get('References', [])),
                        'recommendation': vuln.get('Solution', 'Consultar documentación de seguridad')
                    })
            
            # Guardar vulnerabilidades en la base de datos
            if vulnerabilities:
                conn = self.get_db_connection()
                cursor = conn.cursor()
                
                for vuln in vulnerabilities:
                    cursor.execute('''
                        INSERT INTO vulnerabilities (
                            scan_id, title, description, severity, category, cve_id, cvss_score, references, recommendation
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        vuln['scan_id'],
                        vuln['title'],
                        vuln['description'],
                        vuln['severity'],
                        vuln['category'],
                        vuln['cve_id'],
                        vuln['cvss_score'],
                        vuln['references'],
                        vuln['recommendation']
                    ))
                
                conn.commit()
                conn.close()
            
            return vulnerabilities
        except Exception as e:
            logger.error(f"Error al procesar resultados de Trivy: {e}")
            return []
    
    def apply_hardening_rules(self, category=None, auto_apply=False):
        """Aplicar reglas de hardening"""
        try:
            # Definir reglas de hardening
            hardening_rules = self.get_hardening_rules()
            
            applied_rules = []
            
            for rule in hardening_rules:
                # Filtrar por categoría si se especifica
                if category and rule['category'] != category:
                    continue
                
                # Verificar si la regla ya está aplicada
                if self.is_rule_applied(rule['id']):
                    continue
                
                # Aplicar regla
                if auto_apply or self.config['hardening']['auto_apply']:
                    result = self.apply_hardening_rule(rule)
                    if result['success']:
                        applied_rules.append(rule)
                        logger.info(f"Regla de hardening aplicada: {rule['name']}")
                    else:
                        logger.error(f"Error al aplicar regla de hardening {rule['name']}: {result.get('error')}")
                else:
                    # Solo mostrar recomendación
                    logger.info(f"Recomendación de hardening: {rule['name']} - {rule['description']}")
                    applied_rules.append(rule)
            
            return {
                'success': True,
                'applied_rules': applied_rules,
                'count': len(applied_rules)
            }
        except Exception as e:
            logger.error(f"Error al aplicar reglas de hardening: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_hardening_rules(self):
        """Obtener reglas de hardening"""
        return [
            {
                'id': 'ssh_disable_root_login',
                'category': 'ssh',
                'name': 'Deshabilitar login de root por SSH',
                'description': 'Deshabilitar el inicio de sesión directo del usuario root por SSH',
                'file_path': '/etc/ssh/sshd_config',
                'pattern': r'^PermitRootLogin\s+yes',
                'replacement': 'PermitRootLogin no',
                'command': 'systemctl restart sshd'
            },
            {
                'id': 'ssh_disable_password_auth',
                'category': 'ssh',
                'name': 'Deshabilitar autenticación por contraseña SSH',
                'description': 'Deshabilitar la autenticación por contraseña en SSH y requerir claves SSH',
                'file_path': '/etc/ssh/sshd_config',
                'pattern': r'^#?PasswordAuthentication\s+yes',
                'replacement': 'PasswordAuthentication no',
                'command': 'systemctl restart sshd'
            },
            {
                'id': 'ssh_change_port',
                'category': 'ssh',
                'name': 'Cambiar puerto SSH por defecto',
                'description': 'Cambiar el puerto SSH del 22 al 2222 para reducir escaneos automatizados',
                'file_path': '/etc/ssh/sshd_config',
                'pattern': r'^#?Port\s+22',
                'replacement': 'Port 2222',
                'command': 'systemctl restart sshd'
            },
            {
                'id': 'sysctl_disable_ip_forward',
                'category': 'network',
                'name': 'Deshabilitar reenvío de paquetes IP',
                'description': 'Deshabilitar el reenvío de paquetes IP para evitar ataques de enrutamiento',
                'file_path': '/etc/sysctl.conf',
                'pattern': r'^#?net\.ipv4\.ip_forward\s*=\s*1',
                'replacement': 'net.ipv4.ip_forward = 0',
                'command': 'sysctl -p'
            },
            {
                'id': 'sysctl_disable_source_routing',
                'category': 'network',
                'name': 'Deshabilitar enrutamiento de origen',
                'description': 'Deshabilitar el enrutamiento de origen para evitar ataques de spoofing',
                'file_path': '/etc/sysctl.conf',
                'pattern': r'^#?net\.ipv4\.conf\.all\.accept_source_route\s*=\s*1',
                'replacement': 'net.ipv4.conf.all.accept_source_route = 0',
                'command': 'sysctl -p'
            },
            {
                'id': 'sysctl_disable_redirects',
                'category': 'network',
                'name': 'Deshabilitar redirecciones ICMP',
                'description': 'Deshabilitar las redirecciones ICMP para evitar ataques de redirección',
                'file_path': '/etc/sysctl.conf',
                'pattern': r'^#?net\.ipv4\.conf\.all\.accept_redirects\s*=\s*1',
                'replacement': 'net.ipv4.conf.all.accept_redirects = 0',
                'command': 'sysctl -p'
            },
            {
                'id': 'system_disable_core_dumps',
                'category': 'system',
                'name': 'Deshabilitar volcados de core',
                'description': 'Deshabilitar los volcados de core para evitar exposición de información sensible',
                'file_path': '/etc/security/limits.conf',
                'pattern': r'^#?\*\s+soft\s+core\s+0',
                'replacement': '* soft core 0',
                'command': ''
            },
            {
                'id': 'system_restrict_file_permissions',
                'category': 'filesystem',
                'name': 'Restringir permisos de archivos críticos',
                'description': 'Establecer permisos restrictivos en archivos críticos del sistema',
                'file_path': '',
                'pattern': '',
                'replacement': '',
                'command': 'chmod 600 /etc/shadow /etc/gshadow && chmod 644 /etc/passwd /etc/group'
            },
            {
                'id': 'apache_hide_server_version',
                'category': 'services',
                'name': 'Ocultar versión del servidor Apache',
                'description': 'Ocultar la versión del servidor Apache en las cabeceras HTTP',
                'file_path': '/etc/apache2/conf-available/security.conf',
                'pattern': r'^#?ServerTokens\s+OS',
                'replacement': 'ServerTokens Prod',
                'command': 'systemctl restart apache2'
            },
            {
                'id': 'apache_disable_trace',
                'category': 'services',
                'name': 'Deshabilitar método TRACE en Apache',
                'description': 'Deshabilitar el método HTTP TRACE para evitar ataques XST',
                'file_path': '/etc/apache2/conf-available/security.conf',
                'pattern': r'^#?TraceEnable\s+On',
                'replacement': 'TraceEnable Off',
                'command': 'systemctl restart apache2'
            },
            {
                'id': 'nginx_hide_server_version',
                'category': 'services',
                'name': 'Ocultar versión del servidor Nginx',
                'description': 'Ocultar la versión del servidor Nginx en las cabeceras HTTP',
                'file_path': '/etc/nginx/nginx.conf',
                'pattern': r'^#?server_tokens\s+on;',
                'replacement': 'server_tokens off;',
                'command': 'systemctl restart nginx'
            },
            {
                'id': 'mysql_disable_local_infile',
                'category': 'services',
                'name': 'Deshabilitar LOAD DATA LOCAL en MySQL',
                'description': 'Deshabilitar la función LOAD DATA LOCAL en MySQL para evitar ataques de lectura de archivos',
                'file_path': '/etc/mysql/my.cnf',
                'pattern': r'^#?local_infile\s*=\s*1',
                'replacement': 'local_infile = 0',
                'command': 'systemctl restart mysql'
            }
        ]
    
    def is_rule_applied(self, rule_id):
        """Verificar si una regla de hardening ya está aplicada"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT COUNT(*) FROM hardening_configs
                WHERE name = ? AND is_applied = 1
            ''', (rule_id,))
            
            count = cursor.fetchone()[0]
            conn.close()
            
            return count > 0
        except Exception as e:
            logger.error(f"Error al verificar si la regla está aplicada: {e}")
            return False
    
    def apply_hardening_rule(self, rule):
        """Aplicar una regla de hardening específica"""
        try:
            # Crear backup antes de aplicar cambios
            if rule['file_path'] and self.config['hardening']['backup_before_changes']:
                backup_result = self.backup_file(rule['file_path'])
                if not backup_result['success']:
                    return {
                        'success': False,
                        'error': f"Error al crear backup: {backup_result.get('error')}"
                    }
            
            # Aplicar cambios en archivo si es necesario
            if rule['file_path'] and rule['pattern'] and os.path.exists(rule['file_path']):
                # Leer archivo
                with open(rule['file_path'], 'r') as f:
                    content = f.read()
                
                # Verificar si el patrón existe
                if re.search(rule['pattern'], content):
                    # Reemplazar patrón
                    new_content = re.sub(rule['pattern'], rule['replacement'], content)
                    
                    # Escribir archivo modificado
                    with open(rule['file_path'], 'w') as f:
                        f.write(new_content)
                    
                    logger.info(f"Archivo modificado: {rule['file_path']}")
                else:
                    # Añadir línea si el patrón no existe
                    with open(rule['file_path'], 'a') as f:
                        f.write(f"\n{rule['replacement']}\n")
                    
                    logger.info(f"Línea añadida al archivo: {rule['file_path']}")
            
            # Ejecutar comando si es necesario
            if rule['command']:
                command_result = self.run_command(rule['command'])
                if not command_result['success']:
                    return {
                        'success': False,
                        'error': f"Error al ejecutar comando: {command_result.get('error')}"
                    }
            
            # Guardar información de la regla aplicada en la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT OR REPLACE INTO hardening_configs
                (category, name, value, default_value, description, is_applied, applied_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                rule['category'],
                rule['id'],
                rule['replacement'],
                rule['pattern'],
                rule['description'],
                1,
                datetime.now()
            ))
            
            conn.commit()
            conn.close()
            
            return {
                'success': True,
                'message': f"Regla de hardening aplicada: {rule['name']}"
            }
        except Exception as e:
            logger.error(f"Error al aplicar regla de hardening: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_report(self, scan_id, format='html'):
        """Generar reporte de escaneo"""
        try:
            # Obtener información del escaneo
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT * FROM scans WHERE id = ?
            ''', (scan_id,))
            
            scan = cursor.fetchone()
            
            if not scan:
                return {'success': False, 'message': 'Escaneo no encontrado'}
            
            # Obtener vulnerabilidades
            cursor.execute('''
                SELECT * FROM vulnerabilities WHERE scan_id = ? ORDER BY severity DESC
            ''', (scan_id,))
            
            vulnerabilities = cursor.fetchall()
            
            conn.close()
            
            # Generar reporte según formato
            if format == 'html':
                report_file = self.generate_html_report(scan, vulnerabilities)
            elif format == 'json':
                report_file = self.generate_json_report(scan, vulnerabilities)
            elif format == 'pdf':
                report_file = self.generate_pdf_report(scan, vulnerabilities)
            else:
                return {'success': False, 'message': f'Formato no soportado: {format}'}
            
            return {
                'success': True,
                'report_file': report_file
            }
        except Exception as e:
            logger.error(f"Error al generar reporte: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_html_report(self, scan, vulnerabilities):
        """Generar reporte en formato HTML"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.reports_dir, f"scan_report_{scan['id']}_{timestamp}.html")
            
            # Contenido HTML
            html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Escaneo - Virtualmin Enterprise</title>
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
        .summary-item.high {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .summary-item.medium {{
            background-color: #fff8e1;
            color: #f57c00;
        }}
        .summary-item.low {{
            background-color: #e8f5e9;
            color: #2e7d32;
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
        .vulnerabilities {{
            margin-top: 30px;
        }}
        .vulnerability {{
            margin-bottom: 20px;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #ddd;
        }}
        .vulnerability.high {{
            border-left-color: #c62828;
            background-color: #ffebee;
        }}
        .vulnerability.medium {{
            border-left-color: #f57c00;
            background-color: #fff8e1;
        }}
        .vulnerability.low {{
            border-left-color: #2e7d32;
            background-color: #e8f5e9;
        }}
        .vulnerability-title {{
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 10px;
        }}
        .vulnerability-description {{
            margin-bottom: 10px;
        }}
        .vulnerability-meta {{
            font-size: 14px;
            color: #666;
        }}
        .vulnerability-recommendation {{
            margin-top: 10px;
            padding: 10px;
            background-color: #f5f5f5;
            border-radius: 4px;
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
            <h1>Reporte de Escaneo de Seguridad</h1>
            <p>Virtualmin Enterprise - Sistema de Hardening Automático</p>
        </div>
        
        <div class="summary">
            <div class="summary-item total">
                <div class="summary-number">{scan['vulnerabilities_count']}</div>
                <div class="summary-label">Total</div>
            </div>
            <div class="summary-item high">
                <div class="summary-number">{scan['high_count']}</div>
                <div class="summary-label">Altas</div>
            </div>
            <div class="summary-item medium">
                <div class="summary-number">{scan['medium_count']}</div>
                <div class="summary-label">Medias</div>
            </div>
            <div class="summary-item low">
                <div class="summary-number">{scan['low_count']}</div>
                <div class="summary-label">Bajas</div>
            </div>
        </div>
        
        <div class="scan-info">
            <h2>Información del Escaneo</h2>
            <p><strong>Tipo:</strong> {scan['scan_type']}</p>
            <p><strong>Escáner:</strong> {scan['scanner']}</p>
            <p><strong>Objetivo:</strong> {scan['target']}</p>
            <p><strong>Fecha:</strong> {scan['start_time']}</p>
        </div>
        
        <div class="vulnerabilities">
            <h2>Vulnerabilidades Encontradas</h2>
"""
            
            # Añadir vulnerabilidades
            for vuln in vulnerabilities:
                severity_class = vuln['severity']
                html_content += f"""
            <div class="vulnerability {severity_class}">
                <div class="vulnerability-title">{vuln['title']}</div>
                <div class="vulnerability-description">{vuln['description']}</div>
                <div class="vulnerability-meta">
                    <p><strong>Severidad:</strong> {vuln['severity']}</p>
                    <p><strong>Categoría:</strong> {vuln['category']}</p>
"""
                
                if vuln['cve_id']:
                    html_content += f"                    <p><strong>CVE:</strong> {vuln['cve_id']}</p>\n"
                
                if vuln['cvss_score']:
                    html_content += f"                    <p><strong>CVSS:</strong> {vuln['cvss_score']}</p>\n"
                
                if vuln['affected_service']:
                    html_content += f"                    <p><strong>Servicio:</strong> {vuln['affected_service']}</p>\n"
                
                if vuln['affected_port']:
                    html_content += f"                    <p><strong>Puerto:</strong> {vuln['affected_port']}</p>\n"
                
                html_content += f"""
                </div>
                <div class="vulnerability-recommendation">
                    <strong>Recomendación:</strong> {vuln['recommendation']}
                </div>
            </div>
"""
            
            # Cerrar HTML
            html_content += """
        </div>
        
        <div class="footer">
            <p>Reporte generado por Virtualmin Enterprise - Sistema de Hardening Automático</p>
            <p>Fecha de generación: """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """</p>
        </div>
    </div>
</body>
</html>
"""
            
            # Escribir archivo HTML
            with open(report_file, 'w') as f:
                f.write(html_content)
            
            logger.info(f"Reporte HTML generado: {report_file}")
            return report_file
        except Exception as e:
            logger.error(f"Error al generar reporte HTML: {e}")
            return None
    
    def generate_json_report(self, scan, vulnerabilities):
        """Generar reporte en formato JSON"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.reports_dir, f"scan_report_{scan['id']}_{timestamp}.json")
            
            # Crear estructura JSON
            report_data = {
                'scan': {
                    'id': scan['id'],
                    'type': scan['scan_type'],
                    'scanner': scan['scanner'],
                    'target': scan['target'],
                    'status': scan['status'],
                    'start_time': scan['start_time'],
                    'end_time': scan['end_time'],
                    'vulnerabilities_count': scan['vulnerabilities_count'],
                    'high_count': scan['high_count'],
                    'medium_count': scan['medium_count'],
                    'low_count': scan['low_count']
                },
                'vulnerabilities': []
            }
            
            # Añadir vulnerabilidades
            for vuln in vulnerabilities:
                vuln_data = {
                    'id': vuln['id'],
                    'title': vuln['title'],
                    'description': vuln['description'],
                    'severity': vuln['severity'],
                    'category': vuln['category'],
                    'recommendation': vuln['recommendation']
                }
                
                if vuln['cve_id']:
                    vuln_data['cve_id'] = vuln['cve_id']
                
                if vuln['cvss_score']:
                    vuln_data['cvss_score'] = vuln['cvss_score']
                
                if vuln['affected_service']:
                    vuln_data['affected_service'] = vuln['affected_service']
                
                if vuln['affected_port']:
                    vuln_data['affected_port'] = vuln['affected_port']
                
                if vuln['references']:
                    vuln_data['references'] = json.loads(vuln['references'])
                
                report_data['vulnerabilities'].append(vuln_data)
            
            # Escribir archivo JSON
            with open(report_file, 'w') as f:
                json.dump(report_data, f, indent=2)
            
            logger.info(f"Reporte JSON generado: {report_file}")
            return report_file
        except Exception as e:
            logger.error(f"Error al generar reporte JSON: {e}")
            return None
    
    def generate_pdf_report(self, scan, vulnerabilities):
        """Generar reporte en formato PDF"""
        try:
            # Verificar si wkhtmltopdf está instalado
            check_result = self.run_command("which wkhtmltopdf")
            if not check_result['success']:
                # Instalar wkhtmltopdf
                install_result = self.run_command("apt-get update && apt-get install -y wkhtmltopdf")
                if not install_result['success']:
                    logger.error("No se pudo instalar wkhtmltopdf")
                    return None
            
            # Generar reporte HTML primero
            html_report = self.generate_html_report(scan, vulnerabilities)
            
            if not html_report:
                return None
            
            # Convertir HTML a PDF
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            pdf_report = os.path.join(self.reports_dir, f"scan_report_{scan['id']}_{timestamp}.pdf")
            
            command = f"wkhtmltopdf {html_report} {pdf_report}"
            result = self.run_command(command)
            
            if result['success']:
                logger.info(f"Reporte PDF generado: {pdf_report}")
                return pdf_report
            else:
                logger.error(f"Error al generar PDF: {result.get('stderr')}")
                return None
        except Exception as e:
            logger.error(f"Error al generar reporte PDF: {e}")
            return None
    
    def run_comprehensive_scan(self, target="localhost"):
        """Ejecutar escaneo de seguridad completo"""
        try:
            scan_results = {}
            
            # Escaneo de red con Nmap
            if self.config['scanners']['nmap']:
                logger.info("Iniciando escaneo de red con Nmap...")
                nmap_result = self.scan_with_nmap(target)
                scan_results['nmap'] = nmap_result
            
            # Escaneo de sistema con Lynis
            if self.config['scanners']['lynis']:
                logger.info("Iniciando escaneo de sistema con Lynis...")
                lynis_result = self.scan_with_lynis()
                scan_results['lynis'] = lynis_result
            
            # Escaneo web con Nikto
            if self.config['scanners']['nikto'] and target.startswith('http'):
                logger.info("Iniciando escaneo web con Nikto...")
                nikto_result = self.scan_with_nikto(target)
                scan_results['nikto'] = nikto_result
            
            # Escaneo SSL con SSLScan
            if self.config['scanners']['sslscan'] and (target.startswith('https') or target == "localhost"):
                logger.info("Iniciando escaneo SSL con SSLScan...")
                sslscan_result = self.scan_with_sslscan(target)
                scan_results['sslscan'] = sslscan_result
            
            # Escaneo de contenedores con Trivy
            if self.config['scanners']['trivy']:
                logger.info("Iniciando escaneo de contenedores con Trivy...")
                trivy_result = self.scan_with_trivy("ubuntu:latest")
                scan_results['trivy'] = trivy_result
            
            # Aplicar reglas de hardening
            logger.info("Aplicando reglas de hardening...")
            hardening_result = self.apply_hardening_rules()
            scan_results['hardening'] = hardening_result
            
            # Generar reporte consolidado
            logger.info("Generando reporte consolidado...")
            report_file = self.generate_consolidated_report(scan_results)
            
            return {
                'success': True,
                'scan_results': scan_results,
                'report_file': report_file
            }
        except Exception as e:
            logger.error(f"Error en escaneo completo: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_consolidated_report(self, scan_results):
        """Generar reporte consolidado de todos los escaneos"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.reports_dir, f"comprehensive_report_{timestamp}.html")
            
            # Contenido HTML
            html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Seguridad Consolidado - Virtualmin Enterprise</title>
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
        .summary-item.high {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .summary-item.medium {{
            background-color: #fff8e1;
            color: #f57c00;
        }}
        .summary-item.low {{
            background-color: #e8f5e9;
            color: #2e7d32;
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
        .scan-section {{
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ddd;
        }}
        .scan-title {{
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }}
        .scan-status {{
            margin-bottom: 15px;
            padding: 8px 12px;
            border-radius: 4px;
            font-weight: bold;
            text-align: center;
        }}
        .scan-status.success {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .scan-status.error {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .scan-details {{
            margin-top: 15px;
        }}
        .vulnerability {{
            margin-bottom: 10px;
            padding: 10px;
            border-radius: 4px;
            border-left: 4px solid #ddd;
        }}
        .vulnerability.high {{
            border-left-color: #c62828;
            background-color: #ffebee;
        }}
        .vulnerability.medium {{
            border-left-color: #f57c00;
            background-color: #fff8e1;
        }}
        .vulnerability.low {{
            border-left-color: #2e7d32;
            background-color: #e8f5e9;
        }}
        .vulnerability-title {{
            font-weight: bold;
            margin-bottom: 5px;
        }}
        .hardening-section {{
            margin-top: 30px;
        }}
        .hardening-rule {{
            margin-bottom: 10px;
            padding: 10px;
            border-radius: 4px;
            background-color: #f5f5f5;
        }}
        .rule-name {{
            font-weight: bold;
            margin-bottom: 5px;
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
            <h1>Reporte de Seguridad Consolidado</h1>
            <p>Virtualmin Enterprise - Sistema de Hardening Automático</p>
        </div>
        
        <div class="summary">
            <div class="summary-item total">
                <div class="summary-number">{self.get_total_vulnerabilities(scan_results)}</div>
                <div class="summary-label">Total</div>
            </div>
            <div class="summary-item high">
                <div class="summary-number">{self.get_high_vulnerabilities(scan_results)}</div>
                <div class="summary-label">Altas</div>
            </div>
            <div class="summary-item medium">
                <div class="summary-number">{self.get_medium_vulnerabilities(scan_results)}</div>
                <div class="summary-label">Medias</div>
            </div>
            <div class="summary-item low">
                <div class="summary-number">{self.get_low_vulnerabilities(scan_results)}</div>
                <div class="summary-label">Bajas</div>
            </div>
        </div>
"""
            
            # Añadir secciones de escaneo
            for scanner, result in scan_results.items():
                if scanner == 'hardening':
                    continue
                
                html_content += f"""
        <div class="scan-section">
            <div class="scan-title">Escaneo con {scanner.upper()}</div>
"""
                
                if result['success']:
                    html_content += f"""
            <div class="scan-status success">Completado exitosamente</div>
"""
                    
                    if 'vulnerabilities' in result and result['vulnerabilities']:
                        html_content += f"""
            <div class="scan-details">
                <p><strong>Vulnerabilidades encontradas:</strong> {len(result['vulnerabilities'])}</p>
"""
                        
                        # Mostrar las 5 vulnerabilidades más críticas
                        for vuln in result['vulnerabilities'][:5]:
                            html_content += f"""
                <div class="vulnerability {vuln['severity']}">
                    <div class="vulnerability-title">{vuln['title']}</div>
                    <div class="vulnerability-description">{vuln['description']}</div>
                </div>
"""
                        
                        html_content += """
            </div>
"""
                else:
                    html_content += f"""
            <div class="scan-status error">Error: {result.get('error', 'Unknown error')}</div>
"""
                
                html_content += """
        </div>
"""
            
            # Añadir sección de hardening
            if 'hardening' in scan_results:
                html_content += """
        <div class="hardening-section">
            <div class="scan-title">Reglas de Hardening Aplicadas</div>
"""
                
                if scan_results['hardening']['success']:
                    html_content += f"""
            <div class="scan-status success">Completado exitosamente</div>
            <p><strong>Reglas aplicadas:</strong> {scan_results['hardening']['count']}</p>
"""
                    
                    for rule in scan_results['hardening']['applied_rules']:
                        html_content += f"""
            <div class="hardening-rule">
                <div class="rule-name">{rule['name']}</div>
                <div>{rule['description']}</div>
            </div>
"""
                else:
                    html_content += f"""
            <div class="scan-status error">Error: {scan_results['hardening'].get('error', 'Unknown error')}</div>
"""
                
                html_content += """
        </div>
"""
            
            # Cerrar HTML
            html_content += """
    </div>
    
    <div class="footer">
        <p>Reporte generado por Virtualmin Enterprise - Sistema de Hardening Automático</p>
        <p>Fecha de generación: """ + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + """</p>
    </div>
</body>
</html>
"""
            
            # Escribir archivo HTML
            with open(report_file, 'w') as f:
                f.write(html_content)
            
            logger.info(f"Reporte consolidado generado: {report_file}")
            return report_file
        except Exception as e:
            logger.error(f"Error al generar reporte consolidado: {e}")
            return None
    
    def get_total_vulnerabilities(self, scan_results):
        """Obtener el número total de vulnerabilidades"""
        total = 0
        for scanner, result in scan_results.items():
            if scanner == 'hardening':
                continue
            if result['success'] and 'vulnerabilities' in result:
                total += len(result['vulnerabilities'])
        return total
    
    def get_high_vulnerabilities(self, scan_results):
        """Obtener el número de vulnerabilidades altas"""
        total = 0
        for scanner, result in scan_results.items():
            if scanner == 'hardening':
                continue
            if result['success'] and 'vulnerabilities' in result:
                total += sum(1 for v in result['vulnerabilities'] if v['severity'] == 'high')
        return total
    
    def get_medium_vulnerabilities(self, scan_results):
        """Obtener el número de vulnerabilidades medias"""
        total = 0
        for scanner, result in scan_results.items():
            if scanner == 'hardening':
                continue
            if result['success'] and 'vulnerabilities' in result:
                total += sum(1 for v in result['vulnerabilities'] if v['severity'] == 'medium')
        return total
    
    def get_low_vulnerabilities(self, scan_results):
        """Obtener el número de vulnerabilidades bajas"""
        total = 0
        for scanner, result in scan_results.items():
            if scanner == 'hardening':
                continue
            if result['success'] and 'vulnerabilities' in result:
                total += sum(1 for v in result['vulnerabilities'] if v['severity'] == 'low')
        return total

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de Hardening Automático con Escaneo de Vulnerabilidades para Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/security/hardening_config.json')
    parser.add_argument('--scan', help='Ejecutar escaneo específico', choices=['nmap', 'lynis', 'nikto', 'sslscan', 'trivy', 'comprehensive'])
    parser.add_argument('--target', help='Objetivo del escaneo', default='localhost')
    parser.add_argument('--hardening', action='store_true', help='Aplicar reglas de hardening')
    parser.add_argument('--category', help='Categoría de hardening a aplicar')
    parser.add_argument('--report', help='Generar reporte para un escaneo específico')
    parser.add_argument('--format', help='Formato del reporte', choices=['html', 'json', 'pdf'], default='html')
    parser.add_argument('--auto-apply', action='store_true', help='Aplicar automáticamente las correcciones')
    
    args = parser.parse_args()
    
    # Inicializar sistema
    hardening_system = HardeningSystem(args.config)
    
    if args.scan:
        # Ejecutar escaneo específico
        if args.scan == 'nmap':
            result = hardening_system.scan_with_nmap(args.target)
        elif args.scan == 'lynis':
            result = hardening_system.scan_with_lynis(args.target)
        elif args.scan == 'nikto':
            result = hardening_system.scan_with_nikto(args.target)
        elif args.scan == 'sslscan':
            result = hardening_system.scan_with_sslscan(args.target)
        elif args.scan == 'trivy':
            result = hardening_system.scan_with_trivy(args.target)
        elif args.scan == 'comprehensive':
            result = hardening_system.run_comprehensive_scan(args.target)
        
        if result['success']:
            print(f"Escaneo completado exitosamente")
            if 'scan_id' in result:
                print(f"ID del escaneo: {result['scan_id']}")
                print(f"Vulnerabilidades encontradas: {len(result.get('vulnerabilities', []))}")
        else:
            print(f"Error en escaneo: {result.get('error')}")
            sys.exit(1)
    elif args.hardening:
        # Aplicar reglas de hardening
        result = hardening_system.apply_hardening_rules(args.category, args.auto_apply)
        
        if result['success']:
            print(f"Reglas de hardening aplicadas: {result['count']}")
        else:
            print(f"Error al aplicar reglas de hardening: {result.get('error')}")
            sys.exit(1)
    elif args.report:
        # Generar reporte
        result = hardening_system.generate_report(int(args.report), args.format)
        
        if result['success']:
            print(f"Reporte generado: {result['report_file']}")
        else:
            print(f"Error al generar reporte: {result.get('error')}")
            sys.exit(1)
    else:
        # Ejecutar escaneo completo por defecto
        result = hardening_system.run_comprehensive_scan(args.target)
        
        if result['success']:
            print(f"Escaneo completo realizado exitosamente")
            print(f"Reporte generado: {result['report_file']}")
        else:
            print(f"Error en escaneo completo: {result.get('error')}")
            sys.exit(1)

if __name__ == "__main__":
    main()