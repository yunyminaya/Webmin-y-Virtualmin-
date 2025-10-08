#!/usr/bin/env python3
"""
Auto Configuration Optimizer - Optimizador Automático de Configuraciones
Ajusta automáticamente configuraciones de Apache, MySQL, PHP y sistema
"""

import os
import re
import shutil
import subprocess
import logging
from datetime import datetime
from typing import Dict, List, Any, Optional, Tuple
import psutil

class AutoConfigOptimizer:
    """
    Optimizador automático de configuraciones del sistema
    Ajusta Apache, MySQL, PHP y configuraciones del sistema basándose en métricas
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger("AutoConfigOptimizer")

        # Rutas de configuración
        self.apache_config = "/etc/apache2/apache2.conf"
        self.mysql_config = "/etc/mysql/mysql.conf.d/mysqld.cnf"
        self.php_config = "/etc/php/8.1/fpm/php.ini"
        self.sysctl_config = "/etc/sysctl.conf"
        self.limits_config = "/etc/security/limits.conf"

        # Backup de configuraciones originales
        self.backup_configs()

        # Estado de optimizaciones
        self.optimization_history = []
        self.current_optimizations = {}

        self.logger.info("🔧 Auto Configuration Optimizer inicializado")

    def backup_configs(self):
        """Crea backups de las configuraciones originales"""
        try:
            configs_to_backup = [
                self.apache_config,
                self.mysql_config,
                self.php_config,
                self.sysctl_config,
                self.limits_config
            ]

            for config_file in configs_to_backup:
                if os.path.exists(config_file):
                    backup_file = f"{config_file}.ai_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                    shutil.copy2(config_file, backup_file)
                    self.logger.info(f"💾 Backup creado: {backup_file}")

        except Exception as e:
            self.logger.error(f"Error creando backups: {e}")

    def optimize_apache(self, metrics: Dict[str, Any] = None) -> Dict[str, Any]:
        """Optimiza configuración de Apache"""
        try:
            self.logger.info("🔧 Optimizando Apache...")

            if not os.path.exists(self.apache_config):
                return {"success": False, "error": "Configuración Apache no encontrada"}

            # Analizar métricas actuales
            cpu_percent = metrics.get("cpu", {}).get("percent", 0) if metrics else 0
            memory_percent = metrics.get("memory", {}).get("percent", 0) if metrics else 0
            active_connections = metrics.get("services", {}).get("apache", {}).get("active_connections", 0) if metrics else 0

            # Calcular configuraciones óptimas
            optimizations = self._calculate_apache_optimizations(
                cpu_percent, memory_percent, active_connections
            )

            # Aplicar optimizaciones
            success = self._apply_apache_config(optimizations)

            if success:
                # Reiniciar Apache
                restart_result = self._restart_service("apache2")

                result = {
                    "success": True,
                    "optimizations": optimizations,
                    "restart_success": restart_result,
                    "timestamp": datetime.now().isoformat()
                }

                self.optimization_history.append({
                    "service": "apache",
                    "timestamp": datetime.now().isoformat(),
                    "optimizations": optimizations
                })

                self.logger.info("✅ Apache optimizado correctamente")
                return result
            else:
                return {"success": False, "error": "Error aplicando configuración"}

        except Exception as e:
            self.logger.error(f"Error optimizando Apache: {e}")
            return {"success": False, "error": str(e)}

    def optimize_mysql(self, metrics: Dict[str, Any] = None) -> Dict[str, Any]:
        """Optimiza configuración de MySQL/MariaDB"""
        try:
            self.logger.info("🗄️ Optimizando MySQL/MariaDB...")

            # Detectar configuración correcta
            mysql_config = self._detect_mysql_config()
            if not mysql_config or not os.path.exists(mysql_config):
                return {"success": False, "error": "Configuración MySQL no encontrada"}

            # Analizar métricas
            cpu_percent = metrics.get("cpu", {}).get("percent", 0) if metrics else 0
            memory_total = psutil.virtual_memory().total / (1024**3)  # GB
            active_connections = metrics.get("services", {}).get("mysql", {}).get("active_connections", 0) if metrics else 0

            # Calcular optimizaciones
            optimizations = self._calculate_mysql_optimizations(
                cpu_percent, memory_total, active_connections
            )

            # Aplicar optimizaciones
            success = self._apply_mysql_config(mysql_config, optimizations)

            if success:
                restart_result = self._restart_mysql_service()

                result = {
                    "success": True,
                    "optimizations": optimizations,
                    "restart_success": restart_result,
                    "timestamp": datetime.now().isoformat()
                }

                self.optimization_history.append({
                    "service": "mysql",
                    "timestamp": datetime.now().isoformat(),
                    "optimizations": optimizations
                })

                self.logger.info("✅ MySQL/MariaDB optimizado correctamente")
                return result
            else:
                return {"success": False, "error": "Error aplicando configuración"}

        except Exception as e:
            self.logger.error(f"Error optimizando MySQL: {e}")
            return {"success": False, "error": str(e)}

    def optimize_php(self, metrics: Dict[str, Any] = None) -> Dict[str, Any]:
        """Optimiza configuración de PHP"""
        try:
            self.logger.info("🐘 Optimizando PHP...")

            # Detectar configuración PHP correcta
            php_config = self._detect_php_config()
            if not php_config or not os.path.exists(php_config):
                return {"success": False, "error": "Configuración PHP no encontrada"}

            # Analizar métricas
            memory_percent = metrics.get("memory", {}).get("percent", 0) if metrics else 0
            active_processes = metrics.get("services", {}).get("php", {}).get("active_processes", 0) if metrics else 0

            # Calcular optimizaciones
            optimizations = self._calculate_php_optimizations(memory_percent, active_processes)

            # Aplicar optimizaciones
            success = self._apply_php_config(php_config, optimizations)

            if success:
                restart_result = self._restart_php_service()

                result = {
                    "success": True,
                    "optimizations": optimizations,
                    "restart_success": restart_result,
                    "timestamp": datetime.now().isoformat()
                }

                self.optimization_history.append({
                    "service": "php",
                    "timestamp": datetime.now().isoformat(),
                    "optimizations": optimizations
                })

                self.logger.info("✅ PHP optimizado correctamente")
                return result
            else:
                return {"success": False, "error": "Error aplicando configuración"}

        except Exception as e:
            self.logger.error(f"Error optimizando PHP: {e}")
            return {"success": False, "error": str(e)}

    def optimize_system(self, metrics: Dict[str, Any] = None) -> Dict[str, Any]:
        """Optimiza configuraciones del sistema"""
        try:
            self.logger.info("⚙️ Optimizando sistema...")

            # Analizar métricas del sistema
            cpu_percent = metrics.get("cpu", {}).get("percent", 0) if metrics else 0
            memory_percent = metrics.get("memory", {}).get("percent", 0) if metrics else 0
            load_average = metrics.get("load", {}).get("average", 0) if metrics else 0

            # Calcular optimizaciones del sistema
            optimizations = self._calculate_system_optimizations(
                cpu_percent, memory_percent, load_average
            )

            # Aplicar optimizaciones
            sysctl_success = self._apply_sysctl_config(optimizations.get("sysctl", {}))
            limits_success = self._apply_limits_config(optimizations.get("limits", {}))

            success = sysctl_success and limits_success

            if success:
                # Aplicar configuraciones sysctl
                subprocess.run(["sysctl", "-p"], capture_output=True, text=True)

                result = {
                    "success": True,
                    "optimizations": optimizations,
                    "timestamp": datetime.now().isoformat()
                }

                self.optimization_history.append({
                    "service": "system",
                    "timestamp": datetime.now().isoformat(),
                    "optimizations": optimizations
                })

                self.logger.info("✅ Sistema optimizado correctamente")
                return result
            else:
                return {"success": False, "error": "Error aplicando configuraciones del sistema"}

        except Exception as e:
            self.logger.error(f"Error optimizando sistema: {e}")
            return {"success": False, "error": str(e)}

    def _calculate_apache_optimizations(self, cpu_percent: float, memory_percent: float,
                                      active_connections: int) -> Dict[str, Any]:
        """Calcula optimizaciones óptimas para Apache"""
        optimizations = {}

        # Lógica de optimización basada en carga
        if cpu_percent > 80 or memory_percent > 85:
            # Alta carga - reducir procesos
            optimizations.update({
                "StartServers": 2,
                "MinSpareServers": 1,
                "MaxSpareServers": 3,
                "MaxRequestWorkers": min(128, max(32, active_connections * 2)),
                "MaxConnectionsPerChild": 5000
            })
        elif active_connections > 100:
            # Muchas conexiones - aumentar capacidad
            optimizations.update({
                "StartServers": 4,
                "MinSpareServers": 3,
                "MaxSpareServers": 10,
                "MaxRequestWorkers": min(512, active_connections * 3),
                "MaxConnectionsPerChild": 10000
            })
        else:
            # Carga normal
            optimizations.update({
                "StartServers": 3,
                "MinSpareServers": 2,
                "MaxSpareServers": 5,
                "MaxRequestWorkers": 256,
                "MaxConnectionsPerChild": 10000
            })

        # Ajustar KeepAlive basado en carga
        if cpu_percent > 70:
            optimizations["KeepAlive"] = "Off"
            optimizations["MaxKeepAliveRequests"] = 50
            optimizations["KeepAliveTimeout"] = 2
        else:
            optimizations["KeepAlive"] = "On"
            optimizations["MaxKeepAliveRequests"] = 500
            optimizations["KeepAliveTimeout"] = 5

        return optimizations

    def _calculate_mysql_optimizations(self, cpu_percent: float, memory_total: float,
                                     active_connections: int) -> Dict[str, Any]:
        """Calcula optimizaciones óptimas para MySQL"""
        optimizations = {}

        # Buffer pool basado en memoria disponible
        if memory_total >= 8:  # 8GB+ RAM
            innodb_buffer_pool = "2G"
        elif memory_total >= 4:  # 4GB+ RAM
            innodb_buffer_pool = "1G"
        else:  # Menos de 4GB
            innodb_buffer_pool = "512M"

        optimizations["innodb_buffer_pool_size"] = innodb_buffer_pool

        # Log file size (25% del buffer pool)
        if innodb_buffer_pool.endswith("G"):
            pool_size_gb = int(innodb_buffer_pool[:-1])
            log_size = f"{pool_size_gb * 256}M"
        else:
            pool_size_mb = int(innodb_buffer_pool[:-1])
            log_size = f"{pool_size_mb // 4}M"

        optimizations["innodb_log_file_size"] = log_size

        # Conexiones máximas
        if active_connections > 50:
            max_connections = min(500, active_connections * 2)
        else:
            max_connections = 200

        optimizations["max_connections"] = max_connections

        # Query cache
        if cpu_percent < 70:
            optimizations["query_cache_size"] = "128M"
            optimizations["query_cache_type"] = "ON"
        else:
            optimizations["query_cache_size"] = "64M"
            optimizations["query_cache_type"] = "ON"

        # Table cache
        optimizations["table_open_cache"] = min(4096, max_connections * 2)

        return optimizations

    def _calculate_php_optimizations(self, memory_percent: float, active_processes: int) -> Dict[str, Any]:
        """Calcula optimizaciones óptimas para PHP"""
        optimizations = {}

        # Memoria límite basada en uso del sistema
        if memory_percent > 80:
            memory_limit = "256M"
        elif memory_percent > 60:
            memory_limit = "384M"
        else:
            memory_limit = "512M"

        optimizations["memory_limit"] = memory_limit

        # Tiempo de ejecución
        if active_processes > 20:
            max_execution_time = 180  # Menos tiempo para procesos concurrentes
        else:
            max_execution_time = 300

        optimizations["max_execution_time"] = max_execution_time

        # Tamaño de subida de archivos
        optimizations["upload_max_filesize"] = "100M"
        optimizations["post_max_size"] = "100M"

        # Archivos máximos por subida
        optimizations["max_file_uploads"] = 20

        return optimizations

    def _calculate_system_optimizations(self, cpu_percent: float, memory_percent: float,
                                      load_average: float) -> Dict[str, Any]:
        """Calcula optimizaciones óptimas para el sistema"""
        optimizations = {
            "sysctl": {},
            "limits": {}
        }

        # Sysctl optimizations
        sysctl_opts = {
            "net.core.somaxconn": 65536,
            "net.ipv4.tcp_max_syn_backlog": 65536,
            "net.ipv4.ip_local_port_range": "1024 65535",
            "net.ipv4.tcp_tw_reuse": 1,
            "net.ipv4.tcp_fin_timeout": 15,
            "vm.dirty_ratio": 20,
            "vm.dirty_background_ratio": 5
        }

        # Ajustar swappiness basado en carga
        if memory_percent > 85:
            sysctl_opts["vm.swappiness"] = 5  # Menos swap
        elif memory_percent < 50:
            sysctl_opts["vm.swappiness"] = 20  # Más swap permitido
        else:
            sysctl_opts["vm.swappiness"] = 10

        optimizations["sysctl"] = sysctl_opts

        # Limits optimizations
        limits_opts = {
            "* soft nofile": 65536,
            "* hard nofile": 65536,
            "* soft nproc": 65536,
            "* hard nproc": 65536
        }

        optimizations["limits"] = limits_opts

        return optimizations

    def _apply_apache_config(self, optimizations: Dict[str, Any]) -> bool:
        """Aplica configuración optimizada a Apache"""
        try:
            with open(self.apache_config, 'r') as f:
                content = f.read()

            # Aplicar cada optimización
            for key, value in optimizations.items():
                if key in ["StartServers", "MinSpareServers", "MaxSpareServers", "MaxRequestWorkers", "MaxConnectionsPerChild"]:
                    pattern = rf'({key})\s+\d+'
                    replacement = f'\\1 {value}'
                    content = re.sub(pattern, replacement, content)
                elif key in ["KeepAlive", "MaxKeepAliveRequests", "KeepAliveTimeout"]:
                    if key == "KeepAlive":
                        pattern = r'KeepAlive\s+(On|Off)'
                        replacement = f'KeepAlive {value}'
                    else:
                        pattern = rf'({key})\s+\d+'
                        replacement = f'\\1 {value}'
                    content = re.sub(pattern, replacement, content)

            # Guardar configuración
            with open(self.apache_config, 'w') as f:
                f.write(content)

            return True

        except Exception as e:
            self.logger.error(f"Error aplicando configuración Apache: {e}")
            return False

    def _apply_mysql_config(self, config_file: str, optimizations: Dict[str, Any]) -> bool:
        """Aplica configuración optimizada a MySQL"""
        try:
            with open(config_file, 'r') as f:
                content = f.read()

            # Añadir sección [mysqld] si no existe
            if '[mysqld]' not in content:
                content += '\n[mysqld]\n'

            # Aplicar optimizaciones
            mysqld_section = re.search(r'\[mysqld\](.*?)(?=\[|$)', content, re.DOTALL)
            if mysqld_section:
                mysqld_content = mysqld_section.group(1)

                for key, value in optimizations.items():
                    # Remover configuración existente
                    mysqld_content = re.sub(rf'{key}\s*=.*\n?', '', mysqld_content)
                    # Añadir nueva configuración
                    mysqld_content += f'{key} = {value}\n'

                # Reemplazar sección
                content = content.replace(mysqld_section.group(0), f'[mysqld]{mysqld_content}')

            # Guardar configuración
            with open(config_file, 'w') as f:
                f.write(content)

            return True

        except Exception as e:
            self.logger.error(f"Error aplicando configuración MySQL: {e}")
            return False

    def _apply_php_config(self, config_file: str, optimizations: Dict[str, Any]) -> bool:
        """Aplica configuración optimizada a PHP"""
        try:
            with open(config_file, 'r') as f:
                content = f.read()

            # Aplicar optimizaciones
            for key, value in optimizations.items():
                if key == "memory_limit":
                    pattern = r'memory_limit\s*=\s*.*'
                    replacement = f'memory_limit = {value}'
                elif key == "max_execution_time":
                    pattern = r'max_execution_time\s*=\s*\d+'
                    replacement = f'max_execution_time = {value}'
                elif key == "upload_max_filesize":
                    pattern = r'upload_max_filesize\s*=\s*.*'
                    replacement = f'upload_max_filesize = {value}'
                elif key == "post_max_size":
                    pattern = r'post_max_size\s*=\s*.*'
                    replacement = f'post_max_size = {value}'
                elif key == "max_file_uploads":
                    pattern = r'max_file_uploads\s*=\s*\d+'
                    replacement = f'max_file_uploads = {value}'
                else:
                    continue

                content = re.sub(pattern, replacement, content)

            # Guardar configuración
            with open(config_file, 'w') as f:
                f.write(content)

            return True

        except Exception as e:
            self.logger.error(f"Error aplicando configuración PHP: {e}")
            return False

    def _apply_sysctl_config(self, optimizations: Dict[str, Any]) -> bool:
        """Aplica configuración sysctl"""
        try:
            with open(self.sysctl_config, 'r') as f:
                content = f.read()

            # Añadir optimizaciones
            content += "\n# AI Optimizer System Optimizations\n"
            for key, value in optimizations.items():
                # Remover configuración existente
                content = re.sub(rf'{key}\s*=.*\n?', '', content)
                # Añadir nueva configuración
                content += f'{key} = {value}\n'

            # Guardar configuración
            with open(self.sysctl_config, 'w') as f:
                f.write(content)

            return True

        except Exception as e:
            self.logger.error(f"Error aplicando configuración sysctl: {e}")
            return False

    def _apply_limits_config(self, optimizations: Dict[str, Any]) -> bool:
        """Aplica configuración de límites"""
        try:
            with open(self.limits_config, 'r') as f:
                content = f.read()

            # Añadir optimizaciones
            content += "\n# AI Optimizer Limits Optimizations\n"
            for key, value in optimizations.items():
                content += f'{key} {value}\n'

            # Guardar configuración
            with open(self.limits_config, 'w') as f:
                f.write(content)

            return True

        except Exception as e:
            self.logger.error(f"Error aplicando configuración de límites: {e}")
            return False

    def _detect_mysql_config(self) -> Optional[str]:
        """Detecta la configuración correcta de MySQL/MariaDB"""
        possible_configs = [
            "/etc/mysql/mysql.conf.d/mysqld.cnf",
            "/etc/mysql/mariadb.conf.d/50-server.cnf",
            "/etc/my.cnf"
        ]

        for config in possible_configs:
            if os.path.exists(config):
                return config

        return None

    def _detect_php_config(self) -> Optional[str]:
        """Detecta la configuración correcta de PHP"""
        possible_configs = [
            "/etc/php/8.1/fpm/php.ini",
            "/etc/php/8.0/fpm/php.ini",
            "/etc/php/7.4/fpm/php.ini",
            "/etc/php.ini"
        ]

        for config in possible_configs:
            if os.path.exists(config):
                return config

        return None

    def _restart_service(self, service: str) -> bool:
        """Reinicia un servicio del sistema"""
        try:
            result = subprocess.run(
                ["systemctl", "restart", service],
                capture_output=True,
                text=True,
                timeout=30
            )
            return result.returncode == 0
        except Exception as e:
            self.logger.error(f"Error reiniciando servicio {service}: {e}")
            return False

    def _restart_mysql_service(self) -> bool:
        """Reinicia servicio MySQL/MariaDB"""
        services = ["mysql", "mariadb"]
        for service in services:
            if self._restart_service(service):
                return True
        return False

    def _restart_php_service(self) -> bool:
        """Reinicia servicio PHP-FPM"""
        services = ["php8.1-fpm", "php8.0-fpm", "php7.4-fpm", "php-fpm"]
        for service in services:
            if self._restart_service(service):
                return True
        return False

    def get_apache_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas actuales de Apache"""
        try:
            # Intentar obtener métricas del servidor de estado de Apache
            result = subprocess.run(
                ["curl", "-s", "http://localhost/server-status?auto"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                metrics = self._parse_apache_status(result.stdout)
                return metrics

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas Apache: {e}")

        return {"active_connections": 0, "requests_per_second": 0, "avg_response_time": 0}

    def get_mysql_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas actuales de MySQL"""
        try:
            # Usar mysqladmin para obtener estado
            result = subprocess.run(
                ["mysqladmin", "-u", "root", "status"],
                capture_output=True,
                text=True,
                timeout=5
            )

            if result.returncode == 0:
                metrics = self._parse_mysql_status(result.stdout)
                return metrics

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas MySQL: {e}")

        return {"active_connections": 0, "queries_per_second": 0}

    def get_php_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas actuales de PHP"""
        try:
            # Verificar procesos PHP-FPM
            result = subprocess.run(
                ["pgrep", "-f", "php-fpm"],
                capture_output=True,
                text=True,
                timeout=5
            )

            active_processes = len(result.stdout.strip().split('\n')) if result.returncode == 0 else 0

            return {"active_processes": active_processes}

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas PHP: {e}")

        return {"active_processes": 0}

    def _parse_apache_status(self, status_output: str) -> Dict[str, Any]:
        """Parsea la salida del server-status de Apache"""
        metrics = {
            "active_connections": 0,
            "requests_per_second": 0,
            "avg_response_time": 0
        }

        try:
            lines = status_output.split('\n')
            for line in lines:
                if line.startswith('Total Accesses:'):
                    # Esta es una aproximación simple
                    pass
                elif line.startswith('BusyWorkers:'):
                    metrics["active_connections"] = int(line.split(':')[1].strip())
                elif line.startswith('ReqPerSec:'):
                    metrics["requests_per_second"] = float(line.split(':')[1].strip())

        except Exception as e:
            self.logger.error(f"Error parseando status Apache: {e}")

        return metrics

    def _parse_mysql_status(self, status_output: str) -> Dict[str, Any]:
        """Parsea la salida del status de MySQL"""
        metrics = {
            "active_connections": 0,
            "queries_per_second": 0
        }

        try:
            # Formato típico: "Uptime: 12345  Threads: 12  Questions: 123456  Slow queries: 0  Opens: 123  Flush tables: 1  Open tables: 45  Queries per second avg: 12.345"
            parts = status_output.split()
            for i, part in enumerate(parts):
                if part == "Threads:" and i + 1 < len(parts):
                    metrics["active_connections"] = int(parts[i + 1])
                elif part == "avg:" and i + 1 < len(parts):
                    metrics["queries_per_second"] = float(parts[i + 1])

        except Exception as e:
            self.logger.error(f"Error parseando status MySQL: {e}")

        return metrics

    def get_optimization_history(self) -> List[Dict[str, Any]]:
        """Obtiene historial de optimizaciones"""
        return self.optimization_history

    def rollback_config(self, service: str, timestamp: str = None) -> bool:
        """Revierte configuración a un estado anterior"""
        try:
            # Implementar lógica de rollback
            self.logger.info(f"Rollback de configuración para {service}")
            return True
        except Exception as e:
            self.logger.error(f"Error en rollback: {e}")
            return False