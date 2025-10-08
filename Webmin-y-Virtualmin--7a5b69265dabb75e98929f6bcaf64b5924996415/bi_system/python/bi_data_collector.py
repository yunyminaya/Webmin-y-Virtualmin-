#!/usr/bin/env python3
"""
Colección de Datos BI para Webmin/Virtualmin
Integra con el sistema de monitoreo existente y almacena datos en PostgreSQL
"""

import os
import sys
import json
import time
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
import logging
import socket
import subprocess
import configparser

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/bi_data_collector.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class BIDataCollector:
    def __init__(self, config_file=None):
        self.hostname = socket.gethostname()
        self.config_file = config_file or os.path.join(
            os.path.dirname(__file__), '..', 'bi_database.conf'
        )
        self.db_config = self.load_config()
        self.db_conn = None

    def load_config(self):
        """Cargar configuración de base de datos"""
        config = configparser.ConfigParser()
        config.read(self.config_file)

        return {
            'host': config.get('DEFAULT', 'DB_HOST', fallback='localhost'),
            'port': config.getint('DEFAULT', 'DB_PORT', fallback=5432),
            'database': config.get('DEFAULT', 'DB_NAME', fallback='webmin_bi'),
            'user': config.get('DEFAULT', 'DB_USER', fallback='webmin_bi'),
            'password': config.get('DEFAULT', 'DB_PASS', fallback='')
        }

    def connect_db(self):
        """Conectar a la base de datos PostgreSQL"""
        try:
            self.db_conn = psycopg2.connect(**self.db_config)
            self.db_conn.autocommit = True
            logger.info("Conectado a la base de datos BI")
            return True
        except Exception as e:
            logger.error(f"Error conectando a la base de datos: {e}")
            return False

    def get_system_metrics(self):
        """Obtener métricas del sistema usando comandos del sistema"""
        metrics = {
            'timestamp': datetime.now(),
            'hostname': self.hostname
        }

        try:
            # CPU Usage
            result = subprocess.run(['top', '-bn1'], capture_output=True, text=True, timeout=10)
            cpu_line = [line for line in result.stdout.split('\n') if 'Cpu(s)' in line]
            if cpu_line:
                cpu_parts = cpu_line[0].split()
                idle_index = cpu_parts.index('id,') if 'id,' in cpu_parts else -1
                if idle_index > 0:
                    idle_percent = float(cpu_parts[idle_index - 1])
                    metrics['cpu_usage'] = 100.0 - idle_percent

            # Memory Usage
            with open('/proc/meminfo', 'r') as f:
                mem_info = {}
                for line in f:
                    if ':' in line:
                        key, value = line.split(':', 1)
                        mem_info[key.strip()] = int(value.strip().split()[0])

                if 'MemTotal' in mem_info and 'MemAvailable' in mem_info:
                    total = mem_info['MemTotal']
                    available = mem_info['MemAvailable']
                    metrics['memory_usage'] = ((total - available) / total) * 100

            # Disk Usage (root partition)
            result = subprocess.run(['df', '/'], capture_output=True, text=True, timeout=10)
            lines = result.stdout.strip().split('\n')
            if len(lines) >= 2:
                parts = lines[1].split()
                if len(parts) >= 5:
                    metrics['disk_usage'] = float(parts[4].rstrip('%'))

            # Load Average
            with open('/proc/loadavg', 'r') as f:
                load_avg = f.read().strip().split()[0]
                metrics['load_average'] = float(load_avg)

            # Network I/O (simplified - eth0 or enp*)
            try:
                with open('/proc/net/dev', 'r') as f:
                    for line in f:
                        if 'eth0:' in line or 'enp' in line:
                            parts = line.split()
                            if len(parts) >= 10:
                                metrics['network_rx'] = int(parts[1])
                                metrics['network_tx'] = int(parts[9])
                            break
            except:
                pass

        except Exception as e:
            logger.error(f"Error obteniendo métricas del sistema: {e}")

        return metrics

    def get_service_status(self):
        """Obtener estado de servicios críticos"""
        services = []
        critical_services = [
            'webmin', 'apache2', 'httpd', 'mysql', 'mariadb', 'postgresql',
            'postfix', 'dovecot', 'nginx', 'docker', 'sshd'
        ]

        for service in critical_services:
            try:
                result = subprocess.run(
                    ['systemctl', 'is-active', service],
                    capture_output=True, text=True, timeout=5
                )
                status = result.stdout.strip()

                # Obtener PID y uso de recursos si está corriendo
                pid = None
                memory_mb = None
                cpu_percent = None

                if status == 'active':
                    try:
                        pid_result = subprocess.run(
                            ['systemctl', 'show', service, '--property=MainPID'],
                            capture_output=True, text=True, timeout=5
                        )
                        pid_line = pid_result.stdout.strip()
                        if '=' in pid_line:
                            pid = int(pid_line.split('=')[1])

                        if pid and pid > 0:
                            # Obtener uso de memoria y CPU del proceso
                            ps_result = subprocess.run(
                                ['ps', '-p', str(pid), '-o', 'pmem,pcpu'],
                                capture_output=True, text=True, timeout=5
                            )
                            if ps_result.returncode == 0:
                                lines = ps_result.stdout.strip().split('\n')
                                if len(lines) >= 2:
                                    parts = lines[1].split()
                                    if len(parts) >= 2:
                                        memory_mb = float(parts[0]) * 10  # aproximado
                                        cpu_percent = float(parts[1])
                    except:
                        pass

                services.append({
                    'timestamp': datetime.now(),
                    'hostname': self.hostname,
                    'service_name': service,
                    'status': 'running' if status == 'active' else 'stopped',
                    'pid': pid,
                    'memory_mb': memory_mb,
                    'cpu_percent': cpu_percent
                })

            except Exception as e:
                logger.error(f"Error obteniendo estado del servicio {service}: {e}")

        return services

    def collect_from_existing_monitoring(self):
        """Recopilar datos del sistema de monitoreo existente"""
        log_dir = '/var/log/webmin_devops'

        if not os.path.exists(log_dir):
            return None

        # Buscar el archivo de reporte más reciente
        try:
            files = [f for f in os.listdir(log_dir) if f.startswith('status_report_') and f.endswith('.json')]
            if not files:
                return None

            latest_file = max(files, key=lambda x: os.path.getctime(os.path.join(log_dir, x)))
            filepath = os.path.join(log_dir, latest_file)

            with open(filepath, 'r') as f:
                data = json.load(f)

            return data

        except Exception as e:
            logger.error(f"Error leyendo datos del monitoreo existente: {e}")
            return None

    def store_system_metrics(self, metrics):
        """Almacenar métricas del sistema en la base de datos"""
        if not self.db_conn:
            return False

        try:
            with self.db_conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO system_metrics
                    (timestamp, hostname, cpu_usage, memory_usage, disk_usage,
                     load_average, network_rx, network_tx)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    metrics['timestamp'],
                    metrics['hostname'],
                    metrics.get('cpu_usage'),
                    metrics.get('memory_usage'),
                    metrics.get('disk_usage'),
                    metrics.get('load_average'),
                    metrics.get('network_rx'),
                    metrics.get('network_tx')
                ))

            logger.debug("Métricas del sistema almacenadas")
            return True

        except Exception as e:
            logger.error(f"Error almacenando métricas del sistema: {e}")
            return False

    def store_service_status(self, services):
        """Almacenar estado de servicios en la base de datos"""
        if not self.db_conn or not services:
            return False

        try:
            with self.db_conn.cursor() as cursor:
                psycopg2.extras.execute_batch(cursor, """
                    INSERT INTO service_status
                    (timestamp, hostname, service_name, status, pid, memory_mb, cpu_percent)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, [(
                    svc['timestamp'],
                    svc['hostname'],
                    svc['service_name'],
                    svc['status'],
                    svc.get('pid'),
                    svc.get('memory_mb'),
                    svc.get('cpu_percent')
                ) for svc in services])

            logger.debug(f"Estado de {len(services)} servicios almacenado")
            return True

        except Exception as e:
            logger.error(f"Error almacenando estado de servicios: {e}")
            return False

    def store_alerts_from_monitoring(self, monitoring_data):
        """Almacenar alertas del sistema de monitoreo existente"""
        if not monitoring_data or 'alerts' not in monitoring_data:
            return False

        alerts = monitoring_data.get('alerts', [])
        if not alerts:
            return True

        try:
            with self.db_conn.cursor() as cursor:
                for alert in alerts:
                    cursor.execute("""
                        INSERT INTO alerts_history
                        (timestamp, hostname, alert_type, severity, message)
                        VALUES (%s, %s, %s, %s, %s)
                        ON CONFLICT DO NOTHING
                    """, (
                        datetime.fromisoformat(alert.get('timestamp', datetime.now().isoformat())),
                        self.hostname,
                        alert.get('type', 'Unknown'),
                        alert.get('severity', 'info'),
                        alert.get('message', '')
                    ))

            logger.debug(f"{len(alerts)} alertas almacenadas")
            return True

        except Exception as e:
            logger.error(f"Error almacenando alertas: {e}")
            return False

    def run_collection_cycle(self):
        """Ejecutar un ciclo completo de colección de datos"""
        logger.info("Iniciando ciclo de colección de datos BI")

        # Conectar a la base de datos
        if not self.connect_db():
            return False

        success_count = 0

        # Recopilar métricas del sistema
        metrics = self.get_system_metrics()
        if metrics and self.store_system_metrics(metrics):
            success_count += 1

        # Recopilar estado de servicios
        services = self.get_service_status()
        if services and self.store_service_status(services):
            success_count += 1

        # Recopilar datos del monitoreo existente
        monitoring_data = self.collect_from_existing_monitoring()
        if monitoring_data:
            if self.store_alerts_from_monitoring(monitoring_data):
                success_count += 1

        logger.info(f"Ciclo de colección completado: {success_count}/3 componentes exitosos")
        return success_count > 0

    def run_continuous_collection(self, interval_seconds=300):
        """Ejecutar colección continua de datos"""
        logger.info(f"Iniciando colección continua (intervalo: {interval_seconds}s)")

        while True:
            try:
                self.run_collection_cycle()
            except Exception as e:
                logger.error(f"Error en ciclo de colección: {e}")

            time.sleep(interval_seconds)

def main():
    import argparse

    parser = argparse.ArgumentParser(description='Colección de Datos BI para Webmin/Virtualmin')
    parser.add_argument('--config', help='Archivo de configuración')
    parser.add_argument('--once', action='store_true', help='Ejecutar una sola vez y salir')
    parser.add_argument('--interval', type=int, default=300, help='Intervalo en segundos (default: 300)')

    args = parser.parse_args()

    collector = BIDataCollector(args.config)

    if args.once:
        success = collector.run_collection_cycle()
        sys.exit(0 if success else 1)
    else:
        collector.run_continuous_collection(args.interval)

if __name__ == '__main__':
    main()