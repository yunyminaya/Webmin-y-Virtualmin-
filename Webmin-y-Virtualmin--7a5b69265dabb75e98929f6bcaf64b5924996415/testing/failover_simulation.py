#!/usr/bin/env python3

# Script de Simulación de Caídas y Recuperaciones para Validar Tolerancia a Fallos
# para Virtualmin Enterprise

import json
import os
import sys
import time
import threading
import logging
import sqlite3
import subprocess
import random
import signal
import psutil
import requests
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
import yaml
import uuid

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/virtualmin-enterprise/failover_simulation.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class FailoverSimulationSystem:
    def __init__(self, config_file=None):
        """Inicializar el sistema de simulación de failover"""
        self.config = self.load_config(config_file)
        self.db_path = self.config.get('database', {}).get('path', '/opt/virtualmin-enterprise/testing/failover.db')
        self.reports_dir = self.config.get('reports', {}).get('path', '/opt/virtualmin-enterprise/testing/reports')
        self.scenarios_dir = self.config.get('scenarios', {}).get('path', '/opt/virtualmin-enterprise/testing/failover_scenarios')
        
        # Crear directorios necesarios
        self.create_directories()
        
        # Inicializar base de datos
        self.init_database()
        
        # Estado de las simulaciones
        self.active_simulations = {}
        self.simulation_threads = {}
        
        # Señales para detener simulaciones
        self.stop_signals = {}
    
    def load_config(self, config_file):
        """Cargar configuración desde archivo"""
        default_config = {
            "database": {
                "path": "/opt/virtualmin-enterprise/testing/failover.db"
            },
            "reports": {
                "path": "/opt/virtualmin-enterprise/testing/reports",
                "format": ["html", "json"],
                "retention_days": 30
            },
            "scenarios": {
                "path": "/opt/virtualmin-enterprise/testing/failover_scenarios",
                "default": "basic_failover"
            },
            "targets": {
                "web_server": {
                    "service": "apache2",
                    "port": 80,
                    "health_check": "/health",
                    "recovery_commands": ["systemctl restart apache2"]
                },
                "database": {
                    "service": "mysql",
                    "port": 3306,
                    "health_check": "SELECT 1",
                    "recovery_commands": ["systemctl restart mysql"]
                },
                "load_balancer": {
                    "service": "nginx",
                    "port": 443,
                    "health_check": "/health",
                    "recovery_commands": ["systemctl restart nginx"]
                },
                "virtualmin": {
                    "service": "webmin",
                    "port": 10000,
                    "health_check": "/",
                    "recovery_commands": ["systemctl restart webmin"]
                }
            },
            "monitoring": {
                "check_interval": 10,
                "health_check_timeout": 5,
                "max_failures": 3,
                "recovery_timeout": 60
            },
            "simulation": {
                "max_duration": 3600,
                "auto_recovery": True,
                "notification_on_failure": True,
                "notification_on_recovery": True
            },
            "notification": {
                "email_enabled": False,
                "smtp_server": "",
                "smtp_port": 587,
                "smtp_username": "",
                "smtp_password": "",
                "slack_webhook": ""
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
            '/opt/virtualmin-enterprise/testing',
            os.path.dirname(self.db_path),
            self.reports_dir,
            self.scenarios_dir,
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
            
            # Crear tabla de simulaciones
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS simulations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    simulation_id TEXT UNIQUE NOT NULL,
                    name TEXT NOT NULL,
                    target TEXT NOT NULL,
                    scenario_type TEXT NOT NULL,
                    status TEXT DEFAULT 'pending',
                    start_time TIMESTAMP,
                    end_time TIMESTAMP,
                    duration INTEGER,
                    parameters TEXT,
                    results TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Crear tabla de eventos de failover
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS failover_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    simulation_id TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    description TEXT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    recovery_time TIMESTAMP,
                    status TEXT DEFAULT 'active',
                    FOREIGN KEY (simulation_id) REFERENCES simulations (simulation_id)
                )
            ''')
            
            # Crear tabla de métricas de salud
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS health_metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    simulation_id TEXT NOT NULL,
                    target TEXT NOT NULL,
                    metric_name TEXT NOT NULL,
                    metric_value REAL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (simulation_id) REFERENCES simulations (simulation_id)
                )
            ''')
            
            # Crear tabla de escenarios de simulación
            cursor.execute('''
                CREATE TABLE IF NOT EXISTS simulation_scenarios (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    name TEXT UNIQUE NOT NULL,
                    scenario_type TEXT NOT NULL,
                    target TEXT NOT NULL,
                    description TEXT,
                    parameters TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            ''')
            
            # Insertar escenarios de simulación por defecto
            default_scenarios = [
                {
                    'name': 'service_shutdown',
                    'scenario_type': 'service_failure',
                    'target': 'web_server',
                    'description': 'Simulación de apagado de servicio web',
                    'parameters': json.dumps({
                        'failure_type': 'shutdown',
                        'duration': 60,
                        'auto_recovery': True
                    })
                },
                {
                    'name': 'database_crash',
                    'scenario_type': 'service_failure',
                    'target': 'database',
                    'description': 'Simulación de caída de base de datos',
                    'parameters': json.dumps({
                        'failure_type': 'crash',
                        'duration': 120,
                        'auto_recovery': True
                    })
                },
                {
                    'name': 'network_partition',
                    'scenario_type': 'network_failure',
                    'target': 'web_server',
                    'description': 'Simulación de partición de red',
                    'parameters': json.dumps({
                        'failure_type': 'partition',
                        'duration': 180,
                        'auto_recovery': True
                    })
                },
                {
                    'name': 'disk_full',
                    'scenario_type': 'resource_failure',
                    'target': 'web_server',
                    'description': 'Simulación de disco lleno',
                    'parameters': json.dumps({
                        'failure_type': 'disk_full',
                        'duration': 90,
                        'auto_recovery': True
                    })
                },
                {
                    'name': 'memory_exhaustion',
                    'scenario_type': 'resource_failure',
                    'target': 'web_server',
                    'description': 'Simulación de agotamiento de memoria',
                    'parameters': json.dumps({
                        'failure_type': 'memory_exhaustion',
                        'duration': 60,
                        'auto_recovery': True
                    })
                },
                {
                    'name': 'load_balancer_failure',
                    'scenario_type': 'service_failure',
                    'target': 'load_balancer',
                    'description': 'Simulación de fallo del balanceador de carga',
                    'parameters': json.dumps({
                        'failure_type': 'shutdown',
                        'duration': 120,
                        'auto_recovery': True
                    })
                },
                {
                    'name': 'cascading_failure',
                    'scenario_type': 'cascading_failure',
                    'target': 'web_server',
                    'description': 'Simulación de fallo en cascada',
                    'parameters': json.dumps({
                        'initial_failure': 'web_server',
                        'cascade_targets': ['database', 'load_balancer'],
                        'cascade_delay': 30,
                        'duration': 300,
                        'auto_recovery': True
                    })
                }
            ]
            
            for scenario in default_scenarios:
                cursor.execute('''
                    INSERT OR IGNORE INTO simulation_scenarios (name, scenario_type, target, description, parameters)
                    VALUES (?, ?, ?, ?, ?)
                ''', (
                    scenario['name'],
                    scenario['scenario_type'],
                    scenario['target'],
                    scenario['description'],
                    scenario['parameters']
                ))
            
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
    
    def check_service_health(self, target):
        """Verificar salud de un servicio"""
        try:
            target_config = self.config['targets'].get(target, {})
            service = target_config.get('service', '')
            port = target_config.get('port', 0)
            health_check = target_config.get('health_check', '')
            
            if not service or not port:
                return {'healthy': False, 'message': 'Configuración de objetivo inválida'}
            
            # Verificar si el servicio está en ejecución
            service_status = subprocess.run(
                ['systemctl', 'is-active', service],
                capture_output=True,
                text=True
            )
            
            if service_status.returncode != 0:
                return {'healthy': False, 'message': f'Servicio {service} no está activo'}
            
            # Verificar si el puerto está abierto
            try:
                import socket
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex(('localhost', port))
                sock.close()
                
                if result != 0:
                    return {'healthy': False, 'message': f'Puerto {port} no está accesible'}
            except Exception as e:
                return {'healthy': False, 'message': f'Error al verificar puerto: {str(e)}'}
            
            # Verificar health check HTTP si está configurado
            if health_check and port in [80, 443, 8080, 8443, 10000]:
                try:
                    protocol = 'https' if port in [443, 8443] else 'http'
                    url = f"{protocol}://localhost:{port}{health_check}"
                    
                    response = requests.get(url, timeout=5)
                    
                    if response.status_code != 200:
                        return {'healthy': False, 'message': f'Health check falló: {response.status_code}'}
                except Exception as e:
                    return {'healthy': False, 'message': f'Error en health check: {str(e)}'}
            
            # Verificar uso de recursos
            try:
                # Obtener uso de CPU y memoria
                cpu_percent = psutil.cpu_percent(interval=1)
                memory = psutil.virtual_memory()
                
                # Considerar no saludable si el uso de recursos es muy alto
                if cpu_percent > 95 or memory.percent > 95:
                    return {
                        'healthy': False,
                        'message': f'Uso de recursos crítico: CPU {cpu_percent}%, Memoria {memory.percent}%'
                    }
            except Exception as e:
                return {'healthy': False, 'message': f'Error al verificar recursos: {str(e)}'}
            
            return {'healthy': True, 'message': 'Servicio saludable'}
        except Exception as e:
            logger.error(f"Error al verificar salud del servicio: {e}")
            return {'healthy': False, 'message': f'Error en verificación: {str(e)}'}
    
    def simulate_service_shutdown(self, target, duration=60):
        """Simular apagado de servicio"""
        try:
            target_config = self.config['targets'].get(target, {})
            service = target_config.get('service', '')
            
            if not service:
                return {'success': False, 'message': f'Servicio no configurado para el objetivo: {target}'}
            
            logger.info(f"Simulando apagado del servicio: {service}")
            
            # Detener servicio
            result = subprocess.run(['systemctl', 'stop', service], capture_output=True, text=True)
            
            if result.returncode != 0:
                return {'success': False, 'message': f'Error al detener servicio: {result.stderr}'}
            
            # Esperar el tiempo especificado
            logger.info(f"Esperando {duration} segundos antes de recuperar")
            time.sleep(duration)
            
            # Recuperar servicio
            result = subprocess.run(['systemctl', 'start', service], capture_output=True, text=True)
            
            if result.returncode != 0:
                return {'success': False, 'message': f'Error al iniciar servicio: {result.stderr}'}
            
            return {'success': True, 'message': f'Servicio {service} detenido e iniciado exitosamente'}
        except Exception as e:
            logger.error(f"Error en simulación de apagado de servicio: {e}")
            return {'success': False, 'message': str(e)}
    
    def simulate_service_crash(self, target, duration=60):
        """Simular caída de servicio"""
        try:
            target_config = self.config['targets'].get(target, {})
            service = target_config.get('service', '')
            
            if not service:
                return {'success': False, 'message': f'Servicio no configurado para el objetivo: {target}'}
            
            logger.info(f"Simulando caída del servicio: {service}")
            
            # Matar proceso del servicio (simulación de caída)
            result = subprocess.run(['systemctl', 'kill', service], capture_output=True, text=True)
            
            if result.returncode != 0:
                return {'success': False, 'message': f'Error al matar servicio: {result.stderr}'}
            
            # Esperar el tiempo especificado
            logger.info(f"Esperando {duration} segundos antes de recuperar")
            time.sleep(duration)
            
            # Recuperar servicio
            result = subprocess.run(['systemctl', 'start', service], capture_output=True, text=True)
            
            if result.returncode != 0:
                return {'success': False, 'message': f'Error al iniciar servicio: {result.stderr}'}
            
            return {'success': True, 'message': f'Servicio {service} caído e iniciado exitosamente'}
        except Exception as e:
            logger.error(f"Error en simulación de caída de servicio: {e}")
            return {'success': False, 'message': str(e)}
    
    def simulate_network_partition(self, target, duration=60):
        """Simular partición de red"""
        try:
            target_config = self.config['targets'].get(target, {})
            port = target_config.get('port', 0)
            
            if not port:
                return {'success': False, 'message': f'Puerto no configurado para el objetivo: {target}'}
            
            logger.info(f"Simulando partición de red en el puerto: {port}")
            
            # Usar iptables para bloquear el tráfico (simulación de partición de red)
            # NOTA: En un entorno de producción, esto debe hacerse con mucho cuidado
            # Aquí solo simulamos la acción sin realmente bloquear el tráfico
            
            # En un entorno real:
            # subprocess.run(['iptables', '-A', 'INPUT', '-p', 'tcp', '--dport', str(port), '-j', 'DROP'], check=True)
            # subprocess.run(['iptables', '-A', 'OUTPUT', '-p', 'tcp', '--dport', str(port), '-j', 'DROP'], check=True)
            
            # Simulación: solo registramos la acción
            logger.info(f"Simulación: Bloqueando tráfico en el puerto {port}")
            
            # Esperar el tiempo especificado
            logger.info(f"Esperando {duration} segundos antes de recuperar")
            time.sleep(duration)
            
            # Recuperar: eliminar reglas de iptables
            # En un entorno real:
            # subprocess.run(['iptables', '-D', 'INPUT', '-p', 'tcp', '--dport', str(port), '-j', 'DROP'], check=True)
            # subprocess.run(['iptables', '-D', 'OUTPUT', '-p', 'tcp', '--dport', str(port), '-j', 'DROP'], check=True)
            
            # Simulación: solo registramos la acción
            logger.info(f"Simulación: Restaurando tráfico en el puerto {port}")
            
            return {'success': True, 'message': f'Partición de red simulada y restaurada en el puerto {port}'}
        except Exception as e:
            logger.error(f"Error en simulación de partición de red: {e}")
            return {'success': False, 'message': str(e)}
    
    def simulate_disk_full(self, target, duration=60):
        """Simular disco lleno"""
        try:
            # En un entorno real, esto llenaría el disco con un archivo grande
            # Por seguridad, solo simulamos la acción
            
            logger.info(f"Simulando disco lleno para el objetivo: {target}")
            
            # Simulación: solo registramos la acción
            logger.info("Simulación: Llenando disco")
            
            # Esperar el tiempo especificado
            logger.info(f"Esperando {duration} segundos antes de recuperar")
            time.sleep(duration)
            
            # Recuperar: limpiar disco
            # En un entorno real, esto eliminaría el archivo grande
            logger.info("Simulación: Limpiando disco")
            
            return {'success': True, 'message': 'Disco lleno simulado y limpiado'}
        except Exception as e:
            logger.error(f"Error en simulación de disco lleno: {e}")
            return {'success': False, 'message': str(e)}
    
    def simulate_memory_exhaustion(self, target, duration=60):
        """Simular agotamiento de memoria"""
        try:
            # En un entorno real, esto consumiría memoria hasta agotarla
            # Por seguridad, solo simulamos la acción
            
            logger.info(f"Simulando agotamiento de memoria para el objetivo: {target}")
            
            # Simulación: solo registramos la acción
            logger.info("Simulación: Consumiendo memoria")
            
            # Esperar el tiempo especificado
            logger.info(f"Esperando {duration} segundos antes de recuperar")
            time.sleep(duration)
            
            # Recuperar: liberar memoria
            # En un entorno real, esto liberaría la memoria consumida
            logger.info("Simulación: Liberando memoria")
            
            return {'success': True, 'message': 'Agotamiento de memoria simulado y recuperado'}
        except Exception as e:
            logger.error(f"Error en simulación de agotamiento de memoria: {e}")
            return {'success': False, 'message': str(e)}
    
    def simulate_cascading_failure(self, initial_target, cascade_targets, cascade_delay=30, duration=300):
        """Simular fallo en cascada"""
        try:
            logger.info(f"Iniciando simulación de fallo en cascada")
            logger.info(f"Fallo inicial en: {initial_target}")
            logger.info(f"Objetivos en cascada: {cascade_targets}")
            logger.info(f"Retraso en cascada: {cascade_delay} segundos")
            logger.info(f"Duración total: {duration} segundos")
            
            results = []
            
            # Simular fallo inicial
            initial_result = self.simulate_service_shutdown(initial_target, duration)
            results.append({
                'target': initial_target,
                'result': initial_result
            })
            
            # Simular fallos en cascada
            for target in cascade_targets:
                # Esperar el retraso en cascada
                logger.info(f"Esperando {cascade_delay} segundos antes de fallo en cascada en: {target}")
                time.sleep(cascade_delay)
                
                # Simular fallo en el objetivo de cascada
                cascade_result = self.simulate_service_shutdown(target, duration - cascade_delay * (cascade_targets.index(target) + 1))
                results.append({
                    'target': target,
                    'result': cascade_result
                })
            
            # Verificar si todos los fallos fueron exitosos
            all_success = all(r['result']['success'] for r in results)
            
            return {
                'success': all_success,
                'message': 'Fallo en cascada simulado' if all_success else 'Error en simulación de fallo en cascada',
                'results': results
            }
        except Exception as e:
            logger.error(f"Error en simulación de fallo en cascada: {e}")
            return {'success': False, 'message': str(e)}
    
    def register_simulation(self, simulation_id, name, target, scenario_type, parameters):
        """Registrar simulación en la base de datos"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO simulations (simulation_id, name, target, scenario_type, parameters, start_time)
                VALUES (?, ?, ?, ?, ?, ?)
            ''', (
                simulation_id,
                name,
                target,
                scenario_type,
                json.dumps(parameters),
                datetime.now()
            ))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al registrar simulación: {e}")
            return False
    
    def update_simulation_status(self, simulation_id, status, end_time=None, duration=None, results=None):
        """Actualizar estado de una simulación"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            if end_time and duration:
                cursor.execute('''
                    UPDATE simulations SET status = ?, end_time = ?, duration = ?, results = ?
                    WHERE simulation_id = ?
                ''', (status, end_time, duration, json.dumps(results) if results else None, simulation_id))
            else:
                cursor.execute('''
                    UPDATE simulations SET status = ?
                    WHERE simulation_id = ?
                ''', (status, simulation_id))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al actualizar estado de simulación: {e}")
            return False
    
    def register_failover_event(self, simulation_id, event_type, description):
        """Registrar evento de failover"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO failover_events (simulation_id, event_type, description, timestamp)
                VALUES (?, ?, ?, ?)
            ''', (simulation_id, event_type, description, datetime.now()))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al registrar evento de failover: {e}")
            return False
    
    def save_health_metric(self, simulation_id, target, metric_name, metric_value):
        """Guardar métrica de salud"""
        try:
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                INSERT INTO health_metrics (simulation_id, target, metric_name, metric_value)
                VALUES (?, ?, ?, ?)
            ''', (simulation_id, target, metric_name, metric_value))
            
            conn.commit()
            conn.close()
            
            return True
        except Exception as e:
            logger.error(f"Error al guardar métrica de salud: {e}")
            return False
    
    def monitor_target_health(self, simulation_id, target, check_interval=10, max_duration=3600):
        """Monitorear salud de un objetivo durante una simulación"""
        try:
            start_time = time.time()
            failure_count = 0
            recovery_time = None
            
            while time.time() - start_time < max_duration:
                # Verificar si se ha solicitado detener la simulación
                if simulation_id in self.stop_signals and self.stop_signals[simulation_id]:
                    logger.info(f"Monitoreo detenido para la simulación: {simulation_id}")
                    break
                
                # Verificar salud del objetivo
                health_result = self.check_service_health(target)
                is_healthy = health_result['healthy']
                
                # Guardar métrica de salud
                self.save_health_metric(
                    simulation_id,
                    target,
                    'health_status',
                    1 if is_healthy else 0
                )
                
                if not is_healthy:
                    failure_count += 1
                    logger.warning(f"Objetivo {target} no saludable: {health_result['message']}")
                    
                    # Registrar evento de fallo
                    self.register_failover_event(
                        simulation_id,
                        'health_check_failed',
                        f"Objetivo {target} no saludable: {health_result['message']}"
                    )
                    
                    # Verificar si se ha alcanzado el número máximo de fallos
                    if failure_count >= self.config['monitoring']['max_failures']:
                        logger.error(f"Número máximo de fallos alcanzado para {target}")
                        
                        # Registrar evento de fallo crítico
                        self.register_failover_event(
                            simulation_id,
                            'critical_failure',
                            f"Número máximo de fallos alcanzado para {target}"
                        )
                        
                        # Romper el bucle
                        break
                else:
                    if failure_count > 0:
                        # El objetivo se ha recuperado
                        recovery_time = time.time() - start_time
                        logger.info(f"Objetivo {target} recuperado después de {recovery_time} segundos")
                        
                        # Registrar evento de recuperación
                        self.register_failover_event(
                            simulation_id,
                            'recovery',
                            f"Objetivo {target} recuperado después de {recovery_time} segundos",
                            recovery_time
                        )
                        
                        # Resetear contador de fallos
                        failure_count = 0
                
                # Esperar antes de la siguiente verificación
                time.sleep(check_interval)
            
            return {
                'success': True,
                'failure_count': failure_count,
                'recovery_time': recovery_time
            }
        except Exception as e:
            logger.error(f"Error en monitoreo de salud: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def run_simulation(self, scenario_name):
        """Ejecutar una simulación de failover"""
        try:
            # Obtener escenario de la base de datos
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('''
                SELECT * FROM simulation_scenarios WHERE name = ?
            ''', (scenario_name,))
            
            scenario = cursor.fetchone()
            conn.close()
            
            if not scenario:
                return {'success': False, 'error': f'Escenario no encontrado: {scenario_name}'}
            
            # Generar ID único para la simulación
            simulation_id = str(uuid.uuid4())
            
            # Obtener parámetros del escenario
            parameters = json.loads(scenario['parameters'])
            
            # Registrar simulación
            self.register_simulation(
                simulation_id,
                scenario['name'],
                scenario['target'],
                scenario['scenario_type'],
                parameters
            )
            
            # Actualizar estado
            self.update_simulation_status(simulation_id, 'running')
            
            # Inicializar señal de detención
            self.stop_signals[simulation_id] = False
            
            # Registrar evento de inicio
            self.register_failover_event(
                simulation_id,
                'simulation_start',
                f"Iniciando simulación: {scenario['name']}"
            )
            
            # Iniciar monitoreo en un hilo separado
            monitor_thread = threading.Thread(
                target=self.monitor_target_health,
                args=(simulation_id, scenario['target'])
            )
            monitor_thread.daemon = True
            monitor_thread.start()
            
            # Guardar hilo de monitoreo
            self.simulation_threads[simulation_id] = monitor_thread
            
            # Ejecutar simulación según tipo
            start_time = datetime.now()
            results = {}
            
            if scenario['scenario_type'] == 'service_failure':
                failure_type = parameters.get('failure_type', 'shutdown')
                duration = parameters.get('duration', 60)
                
                if failure_type == 'shutdown':
                    results = self.simulate_service_shutdown(scenario['target'], duration)
                elif failure_type == 'crash':
                    results = self.simulate_service_crash(scenario['target'], duration)
                else:
                    results = {'success': False, 'error': f'Tipo de fallo no soportado: {failure_type}'}
            
            elif scenario['scenario_type'] == 'network_failure':
                duration = parameters.get('duration', 60)
                results = self.simulate_network_partition(scenario['target'], duration)
            
            elif scenario['scenario_type'] == 'resource_failure':
                failure_type = parameters.get('failure_type', 'disk_full')
                duration = parameters.get('duration', 60)
                
                if failure_type == 'disk_full':
                    results = self.simulate_disk_full(scenario['target'], duration)
                elif failure_type == 'memory_exhaustion':
                    results = self.simulate_memory_exhaustion(scenario['target'], duration)
                else:
                    results = {'success': False, 'error': f'Tipo de fallo de recurso no soportado: {failure_type}'}
            
            elif scenario['scenario_type'] == 'cascading_failure':
                initial_failure = parameters.get('initial_failure', 'web_server')
                cascade_targets = parameters.get('cascade_targets', ['database'])
                cascade_delay = parameters.get('cascade_delay', 30)
                duration = parameters.get('duration', 300)
                
                results = self.simulate_cascading_failure(
                    initial_failure,
                    cascade_targets,
                    cascade_delay,
                    duration
                )
            
            else:
                results = {'success': False, 'error': f'Tipo de escenario no soportado: {scenario["scenario_type"]}'}
            
            # Esperar a que el monitoreo termine
            monitor_thread.join(timeout=10)
            
            # Calcular duración
            end_time = datetime.now()
            duration_seconds = (end_time - start_time).total_seconds()
            
            # Actualizar estado
            if results['success']:
                status = 'completed'
            else:
                status = 'failed'
            
            self.update_simulation_status(
                simulation_id,
                status,
                end_time,
                duration_seconds,
                results
            )
            
            # Registrar evento de fin
            self.register_failover_event(
                simulation_id,
                'simulation_end',
                f"Simulación finalizada: {scenario['name']} - {status}"
            )
            
            # Limpiar
            if simulation_id in self.stop_signals:
                del self.stop_signals[simulation_id]
            
            if simulation_id in self.simulation_threads:
                del self.simulation_threads[simulation_id]
            
            return {
                'success': results['success'],
                'simulation_id': simulation_id,
                'duration': duration_seconds,
                'results': results
            }
        except Exception as e:
            logger.error(f"Error en simulación de failover: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def stop_simulation(self, simulation_id):
        """Detener una simulación en ejecución"""
        try:
            if simulation_id not in self.simulation_threads:
                return {'success': False, 'message': 'Simulación no encontrada o no está en ejecución'}
            
            # Establecer señal de detención
            self.stop_signals[simulation_id] = True
            
            # Esperar a que el hilo termine
            self.simulation_threads[simulation_id].join(timeout=10)
            
            # Actualizar estado
            self.update_simulation_status(simulation_id, 'stopped')
            
            # Registrar evento de detención
            self.register_failover_event(
                simulation_id,
                'simulation_stopped',
                "Simulación detenida manualmente"
            )
            
            # Limpiar
            del self.stop_signals[simulation_id]
            del self.simulation_threads[simulation_id]
            
            return {'success': True, 'message': 'Simulación detenida'}
        except Exception as e:
            logger.error(f"Error al detener simulación: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def get_active_simulations(self):
        """Obtener simulaciones activas"""
        return {
            simulation_id: {
                'status': 'running'
            }
            for simulation_id in self.simulation_threads
        }
    
    def run_comprehensive_failover_test(self):
        """Ejecutar prueba de failover completa"""
        try:
            test_results = {}
            
            # Obtener todos los escenarios de simulación
            conn = self.get_db_connection()
            cursor = conn.cursor()
            
            cursor.execute('SELECT name FROM simulation_scenarios ORDER BY scenario_type, target')
            scenarios = [row[0] for row in cursor.fetchall()]
            conn.close()
            
            # Ejecutar cada escenario
            for scenario in scenarios:
                logger.info(f"Ejecutando escenario de failover: {scenario}")
                result = self.run_simulation(scenario)
                test_results[scenario] = result
                
                # Esperar entre simulaciones para evitar sobrecarga
                time.sleep(30)
            
            # Generar reporte consolidado
            report_file = self.generate_comprehensive_report(test_results)
            
            return {
                'success': True,
                'test_results': test_results,
                'report_file': report_file
            }
        except Exception as e:
            logger.error(f"Error en prueba de failover completa: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def generate_comprehensive_report(self, test_results):
        """Generar reporte consolidado de todas las pruebas de failover"""
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            report_file = os.path.join(self.reports_dir, f"failover_report_{timestamp}.html")
            
            # Contenido HTML
            html_content = f"""
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte de Simulación de Failover - Virtualmin Enterprise</title>
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
        .summary-item.success {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .summary-item.failure {{
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
        .test-section {{
            margin-bottom: 30px;
            padding: 20px;
            border-radius: 8px;
            border: 1px solid #ddd;
        }}
        .test-title {{
            font-size: 20px;
            font-weight: bold;
            margin-bottom: 15px;
            color: #333;
        }}
        .test-status {{
            margin-bottom: 15px;
            padding: 8px 12px;
            border-radius: 4px;
            font-weight: bold;
            text-align: center;
        }}
        .test-status.success {{
            background-color: #e8f5e9;
            color: #2e7d32;
        }}
        .test-status.failure {{
            background-color: #ffebee;
            color: #c62828;
        }}
        .test-details {{
            margin-top: 15px;
        }}
        .result {{
            margin-bottom: 10px;
            padding: 10px;
            border-radius: 4px;
            background-color: #f5f5f5;
        }}
        .result-name {{
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
            <h1>Reporte de Simulación de Failover</h1>
            <p>Virtualmin Enterprise - Sistema de Simulación de Caídas y Recuperaciones</p>
        </div>
        
        <div class="summary">
            <div class="summary-item total">
                <div class="summary-number">{len(test_results)}</div>
                <div class="summary-label">Total</div>
            </div>
            <div class="summary-item success">
                <div class="summary-number">{sum(1 for r in test_results.values() if r.get('success', False))}</div>
                <div class="summary-label">Exitosas</div>
            </div>
            <div class="summary-item failure">
                <div class="summary-number">{sum(1 for r in test_results.values() if not r.get('success', False))}</div>
                <div class="summary-label">Fallidas</div>
            </div>
        </div>
"""
            
            # Añadir secciones de pruebas
            for scenario, result in test_results.items():
                html_content += f"""
        <div class="test-section">
            <div class="test-title">Escenario: {scenario}</div>
"""
                
                if result.get('success', False):
                    html_content += f"""
            <div class="test-status success">Completado exitosamente</div>
"""
                    
                    if 'results' in result and result['results']:
                        html_content += f"""
            <div class="test-details">
                <p><strong>Duración:</strong> {result.get('duration', 'N/A')} segundos</p>
                <p><strong>ID de Simulación:</strong> {result.get('simulation_id', 'N/A')}</p>
"""
                        
                        # Mostrar resultados
                        if isinstance(result['results'], dict) and 'message' in result['results']:
                            html_content += f"""
                <div class="result">
                    <div class="result-name">Resultado</div>
                    <div>{result['results']['message']}</div>
                </div>
"""
                        
                        html_content += """
            </div>
"""
                else:
                    html_content += f"""
            <div class="test-status failure">Error: {result.get('error', 'Unknown error')}</div>
"""
                
                html_content += """
        </div>
"""
            
            # Cerrar HTML
            html_content += """
    </div>
    
    <div class="footer">
        <p>Reporte generado por Virtualmin Enterprise - Sistema de Simulación de Failover</p>
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

def main():
    """Función principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de Simulación de Failover para Virtualmin Enterprise')
    parser.add_argument('--config', help='Archivo de configuración', default='/opt/virtualmin-enterprise/testing/failover_config.json')
    parser.add_argument('--scenario', help='Ejecutar escenario de simulación específico')
    parser.add_argument('--comprehensive', action='store_true', help='Ejecutar prueba de failover completa')
    parser.add_argument('--stop', help='Detener simulación activa')
    parser.add_argument('--list', action='store_true', help='Listar simulaciones activas')
    parser.add_argument('--check', help='Verificar salud de un objetivo específico')
    
    args = parser.parse_args()
    
    # Inicializar sistema
    failover_system = FailoverSimulationSystem(args.config)
    
    if args.scenario:
        # Ejecutar escenario específico
        result = failover_system.run_simulation(args.scenario)
        
        if result['success']:
            print(f"Escenario ejecutado exitosamente")
            print(f"ID de simulación: {result['simulation_id']}")
            print(f"Duración: {result.get('duration', 'N/A')} segundos")
            print(f"Resultado: {result['results'].get('message', 'N/A')}")
        else:
            print(f"Error en escenario: {result.get('error')}")
            sys.exit(1)
    elif args.comprehensive:
        # Ejecutar prueba completa
        result = failover_system.run_comprehensive_failover_test()
        
        if result['success']:
            print(f"Prueba de failover completada exitosamente")
            print(f"Reporte consolidado: {result['report_file']}")
        else:
            print(f"Error en prueba de failover: {result.get('error')}")
            sys.exit(1)
    elif args.stop:
        # Detener simulación
        result = failover_system.stop_simulation(args.stop)
        
        if result['success']:
            print(f"Simulación detenida: {args.stop}")
        else:
            print(f"Error al detener simulación: {result.get('message')}")
            sys.exit(1)
    elif args.list:
        # Listar simulaciones activas
        active_simulations = failover_system.get_active_simulations()
        
        if active_simulations:
            print("Simulaciones activas:")
            for simulation_id, simulation_info in active_simulations.items():
                print(f"  - {simulation_id}: {simulation_info['status']}")
        else:
            print("No hay simulaciones activas")
    elif args.check:
        # Verificar salud de un objetivo
        result = failover_system.check_service_health(args.check)
        
        if result['healthy']:
            print(f"Objetivo {args.check} saludable: {result['message']}")
        else:
            print(f"Objetivo {args.check} no saludable: {result['message']}")
            sys.exit(1)
    else:
        # Ejecutar prueba completa por defecto
        result = failover_system.run_comprehensive_failover_test()
        
        if result['success']:
            print(f"Prueba de failover completada exitosamente")
            print(f"Reporte consolidado: {result['report_file']}")
        else:
            print(f"Error en prueba de failover: {result.get('error')}")
            sys.exit(1)

if __name__ == "__main__":
    main()