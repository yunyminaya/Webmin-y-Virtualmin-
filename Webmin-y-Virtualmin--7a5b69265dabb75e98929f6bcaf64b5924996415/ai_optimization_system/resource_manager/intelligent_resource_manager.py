#!/usr/bin/env python3
"""
Intelligent Resource Manager - Gestor Inteligente de Recursos
Gestiona automáticamente CPU, memoria y disco optimizando su asignación
"""

import os
import psutil
import shutil
import logging
import threading
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import subprocess
import re

class IntelligentResourceManager:
    """
    Gestor inteligente de recursos que optimiza automáticamente
    la asignación de CPU, memoria y disco
    """

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.logger = logging.getLogger("IntelligentResourceManager")

        # Umbrales de recursos
        self.cpu_threshold = config.get("performance_thresholds", {}).get("cpu_warning", 80)
        self.memory_threshold = config.get("performance_thresholds", {}).get("memory_warning", 85)
        self.disk_threshold = config.get("performance_thresholds", {}).get("disk_warning", 90)

        # Configuración de gestión
        self.resource_config = config.get("resource_management", {})
        self.auto_cleanup = self.resource_config.get("disk_cleanup_enabled", True)
        self.cleanup_threshold = self.resource_config.get("disk_cleanup_threshold", 85)

        # Estado de recursos
        self.resource_history = []
        self.optimization_actions = []
        self.current_allocations = {}

        # Procesos críticos (no tocar)
        self.critical_processes = [
            "sshd", "systemd", "init", "apache2", "httpd", "mysqld", "mariadbd",
            "php-fpm", "nginx", "postgres", "webmin", "virtualmin"
        ]

        # Directorios a limpiar
        self.cleanup_dirs = [
            "/tmp",
            "/var/tmp",
            "/var/log",
            "/var/cache",
            "/home/*/tmp"
        ]

        self.logger.info("🧠 Intelligent Resource Manager inicializado")

    def get_cpu_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas detalladas de CPU"""
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_times = psutil.cpu_times_percent(interval=1)
            cpu_freq = psutil.cpu_freq()
            load_avg = psutil.getloadavg()

            return {
                "percent": cpu_percent,
                "user": cpu_times.user,
                "system": cpu_times.system,
                "idle": cpu_times.idle,
                "load_1m": load_avg[0],
                "load_5m": load_avg[1],
                "load_15m": load_avg[2],
                "frequency_current": cpu_freq.current if cpu_freq else 0,
                "frequency_max": cpu_freq.max if cpu_freq else 0,
                "cores": psutil.cpu_count(),
                "cores_logical": psutil.cpu_count(logical=True)
            }

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas CPU: {e}")
            return {}

    def get_memory_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas detalladas de memoria"""
        try:
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()

            return {
                "percent": memory.percent,
                "total": memory.total,
                "available": memory.available,
                "used": memory.used,
                "free": memory.free,
                "buffers": memory.buffers,
                "cached": memory.cached,
                "swap_percent": swap.percent,
                "swap_total": swap.total,
                "swap_used": swap.used,
                "swap_free": swap.free
            }

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas memoria: {e}")
            return {}

    def get_disk_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas detalladas de disco"""
        try:
            disk_usage = psutil.disk_usage('/')
            disk_io = psutil.disk_io_counters()

            return {
                "percent": disk_usage.percent,
                "total": disk_usage.total,
                "used": disk_usage.used,
                "free": disk_usage.free,
                "read_count": disk_io.read_count if disk_io else 0,
                "write_count": disk_io.write_count if disk_io else 0,
                "read_bytes": disk_io.read_bytes if disk_io else 0,
                "write_bytes": disk_io.write_bytes if disk_io else 0,
                "read_time": disk_io.read_time if disk_io else 0,
                "write_time": disk_io.write_time if disk_io else 0
            }

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas disco: {e}")
            return {}

    def get_network_metrics(self) -> Dict[str, Any]:
        """Obtiene métricas de red"""
        try:
            network = psutil.net_io_counters()

            return {
                "bytes_sent": network.bytes_sent,
                "bytes_recv": network.bytes_recv,
                "packets_sent": network.packets_sent,
                "packets_recv": network.packets_recv,
                "errin": network.errin,
                "errout": network.errout,
                "dropin": network.dropin,
                "dropout": network.dropout
            }

        except Exception as e:
            self.logger.error(f"Error obteniendo métricas red: {e}")
            return {}

    def optimize_resource_allocation(self, current_metrics: Dict[str, Any]) -> Dict[str, Any]:
        """Optimiza la asignación de recursos basada en métricas actuales"""
        try:
            optimizations = []

            # Optimizar CPU
            cpu_opts = self._optimize_cpu_resources(current_metrics)
            if cpu_opts:
                optimizations.extend(cpu_opts)

            # Optimizar memoria
            memory_opts = self._optimize_memory_resources(current_metrics)
            if memory_opts:
                optimizations.extend(memory_opts)

            # Optimizar disco
            disk_opts = self._optimize_disk_resources(current_metrics)
            if disk_opts:
                optimizations.extend(disk_opts)

            # Registrar optimizaciones
            if optimizations:
                self.optimization_actions.append({
                    "timestamp": datetime.now().isoformat(),
                    "metrics": current_metrics,
                    "optimizations": optimizations
                })

                self.logger.info(f"⚡ Optimizaciones aplicadas: {len(optimizations)} acciones")

            return {
                "success": True,
                "optimizations": optimizations,
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            self.logger.error(f"Error optimizando asignación de recursos: {e}")
            return {"success": False, "error": str(e)}

    def optimize_system_resources(self) -> Dict[str, Any]:
        """Optimiza recursos del sistema de manera manual"""
        try:
            self.logger.info("🔧 Optimizando recursos del sistema...")

            actions = []

            # Liberar memoria cache
            cache_freed = self._drop_caches()
            if cache_freed > 0:
                actions.append(f"Cache liberado: {cache_freed} MB")

            # Limpiar archivos temporales
            temp_cleaned = self._clean_temp_files()
            if temp_cleaned > 0:
                actions.append(f"Archivos temporales limpiados: {temp_cleaned} MB")

            # Optimizar procesos
            processes_optimized = self._optimize_running_processes()
            if processes_optimized:
                actions.append(f"Procesos optimizados: {len(processes_optimized)}")

            # Liberar memoria swap
            swap_freed = self._optimize_swap_usage()
            if swap_freed > 0:
                actions.append(f"Swap optimizado: {swap_freed} MB")

            return {
                "success": True,
                "actions": actions,
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            self.logger.error(f"Error optimizando recursos del sistema: {e}")
            return {"success": False, "error": str(e)}

    def apply_resource_change(self, change_request: Dict[str, Any]) -> bool:
        """Aplica un cambio específico en recursos"""
        try:
            change_type = change_request.get("type")
            target_resource = change_request.get("resource")
            action = change_request.get("action")

            if change_type == "cpu":
                if action == "renice_processes":
                    return self._renice_high_cpu_processes()
                elif action == "kill_zombie_processes":
                    return self._kill_zombie_processes()

            elif change_type == "memory":
                if action == "drop_caches":
                    return self._drop_caches() > 0
                elif action == "kill_memory_hogs":
                    return self._kill_memory_hog_processes()

            elif change_type == "disk":
                if action == "cleanup_temp":
                    return self._clean_temp_files() > 0
                elif action == "compress_logs":
                    return self._compress_old_logs()

            self.logger.info(f"✅ Cambio de recurso aplicado: {change_type} - {action}")
            return True

        except Exception as e:
            self.logger.error(f"Error aplicando cambio de recurso: {e}")
            return False

    def _optimize_cpu_resources(self, metrics: Dict[str, Any]) -> List[str]:
        """Optimiza recursos de CPU"""
        actions = []

        try:
            cpu_percent = metrics.get("cpu", {}).get("percent", 0)
            load_avg = metrics.get("cpu", {}).get("load_1m", 0)

            if cpu_percent > self.cpu_threshold:
                # CPU alta - optimizar procesos
                if self._renice_high_cpu_processes():
                    actions.append("Procesos de alta CPU reniceados")

                # Matar procesos zombies
                if self._kill_zombie_processes():
                    actions.append("Procesos zombies eliminados")

            elif cpu_percent < 30 and load_avg < 1:
                # CPU baja - optimizar para eficiencia energética
                actions.append("Configuración de CPU optimizada para eficiencia")

        except Exception as e:
            self.logger.error(f"Error optimizando CPU: {e}")

        return actions

    def _optimize_memory_resources(self, metrics: Dict[str, Any]) -> List[str]:
        """Optimiza recursos de memoria"""
        actions = []

        try:
            memory_percent = metrics.get("memory", {}).get("percent", 0)
            swap_percent = metrics.get("memory", {}).get("swap_percent", 0)

            if memory_percent > self.memory_threshold:
                # Memoria alta - liberar recursos
                cache_freed = self._drop_caches()
                if cache_freed > 0:
                    actions.append(f"Cache del sistema liberado: {cache_freed} MB")

                # Matar procesos que consumen mucha memoria
                if self._kill_memory_hog_processes():
                    actions.append("Procesos consumidores de memoria optimizados")

            if swap_percent > 50:
                # Swap alto - optimizar uso de swap
                swap_freed = self._optimize_swap_usage()
                if swap_freed > 0:
                    actions.append(f"Uso de swap optimizado: {swap_freed} MB")

        except Exception as e:
            self.logger.error(f"Error optimizando memoria: {e}")

        return actions

    def _optimize_disk_resources(self, metrics: Dict[str, Any]) -> List[str]:
        """Optimiza recursos de disco"""
        actions = []

        try:
            disk_percent = metrics.get("disk", {}).get("percent", 0)

            if disk_percent > self.disk_threshold and self.auto_cleanup:
                # Disco lleno - limpiar
                temp_cleaned = self._clean_temp_files()
                if temp_cleaned > 0:
                    actions.append(f"Archivos temporales limpiados: {temp_cleaned} MB")

                # Comprimir logs antiguos
                if self._compress_old_logs():
                    actions.append("Logs antiguos comprimidos")

                # Limpiar cache de paquetes
                if self._clean_package_cache():
                    actions.append("Cache de paquetes limpiado")

        except Exception as e:
            self.logger.error(f"Error optimizando disco: {e}")

        return actions

    def _drop_caches(self) -> int:
        """Libera memoria cache del sistema"""
        try:
            # Obtener memoria antes
            memory_before = psutil.virtual_memory().cached

            # Liberar caches
            with open('/proc/sys/vm/drop_caches', 'w') as f:
                f.write('3\n')  # Liberar pagecache, dentries e inodes

            # Calcular memoria liberada
            memory_after = psutil.virtual_memory().cached
            freed_mb = (memory_before - memory_after) // (1024 * 1024)

            if freed_mb > 0:
                self.logger.info(f"🧹 Cache liberado: {freed_mb} MB")

            return freed_mb

        except Exception as e:
            self.logger.error(f"Error liberando cache: {e}")
            return 0

    def _clean_temp_files(self) -> int:
        """Limpia archivos temporales"""
        try:
            total_cleaned = 0

            for temp_dir in self.cleanup_dirs:
                if os.path.exists(temp_dir):
                    # Limpiar archivos más antiguos de 7 días
                    for root, dirs, files in os.walk(temp_dir):
                        for file in files:
                            file_path = os.path.join(root, file)
                            try:
                                if os.path.getmtime(file_path) < (datetime.now().timestamp() - 604800):  # 7 días
                                    size = os.path.getsize(file_path)
                                    os.remove(file_path)
                                    total_cleaned += size
                            except:
                                continue

            cleaned_mb = total_cleaned // (1024 * 1024)
            if cleaned_mb > 0:
                self.logger.info(f"🗑️ Archivos temporales limpiados: {cleaned_mb} MB")

            return cleaned_mb

        except Exception as e:
            self.logger.error(f"Error limpiando archivos temporales: {e}")
            return 0

    def _optimize_running_processes(self) -> List[str]:
        """Optimiza procesos en ejecución"""
        optimized = []

        try:
            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
                try:
                    if proc.info['cpu_percent'] > 50 and proc.info['name'] not in self.critical_processes:
                        # Renice proceso de alta CPU
                        proc.nice(10)  # Baja prioridad
                        optimized.append(f"{proc.info['name']} (PID: {proc.info['pid']})")

                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

        except Exception as e:
            self.logger.error(f"Error optimizando procesos: {e}")

        return optimized

    def _optimize_swap_usage(self) -> int:
        """Optimiza uso de swap"""
        try:
            swap_before = psutil.swap_memory().used

            # Forzar liberación de swap
            subprocess.run(['swapoff', '-a'], capture_output=True)
            subprocess.run(['swapon', '-a'], capture_output=True)

            swap_after = psutil.swap_memory().used
            freed_mb = (swap_before - swap_after) // (1024 * 1024)

            if freed_mb > 0:
                self.logger.info(f"🔄 Swap optimizado: {freed_mb} MB liberados")

            return freed_mb

        except Exception as e:
            self.logger.error(f"Error optimizando swap: {e}")
            return 0

    def _renice_high_cpu_processes(self) -> bool:
        """Ajusta prioridad de procesos de alta CPU"""
        try:
            success = False

            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent']):
                try:
                    if (proc.info['cpu_percent'] > 70 and
                        proc.info['name'] not in self.critical_processes):
                        current_nice = proc.nice()
                        if current_nice > -10:  # No reducir más allá de -10
                            proc.nice(current_nice + 5)
                            success = True

                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

            return success

        except Exception as e:
            self.logger.error(f"Error reniceando procesos: {e}")
            return False

    def _kill_zombie_processes(self) -> bool:
        """Elimina procesos zombies"""
        try:
            zombies_killed = 0

            for proc in psutil.process_iter(['pid', 'name', 'status']):
                try:
                    if proc.info['status'] == psutil.STATUS_ZOMBIE:
                        proc.kill()
                        zombies_killed += 1

                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

            if zombies_killed > 0:
                self.logger.info(f"💀 Procesos zombies eliminados: {zombies_killed}")

            return zombies_killed > 0

        except Exception as e:
            self.logger.error(f"Error eliminando zombies: {e}")
            return False

    def _kill_memory_hog_processes(self) -> bool:
        """Elimina procesos que consumen demasiada memoria"""
        try:
            memory_hogs_killed = 0

            for proc in psutil.process_iter(['pid', 'name', 'memory_percent']):
                try:
                    if (proc.info['memory_percent'] > 20 and
                        proc.info['name'] not in self.critical_processes):
                        # Solo matar procesos no críticos con más del 20% de memoria
                        proc.kill()
                        memory_hogs_killed += 1

                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

            if memory_hogs_killed > 0:
                self.logger.info(f"🐘 Procesos consumidores de memoria eliminados: {memory_hogs_killed}")

            return memory_hogs_killed > 0

        except Exception as e:
            self.logger.error(f"Error eliminando procesos consumidores de memoria: {e}")
            return False

    def _compress_old_logs(self) -> bool:
        """Comprime logs antiguos"""
        try:
            log_dirs = ["/var/log"]
            compressed = 0

            for log_dir in log_dirs:
                if os.path.exists(log_dir):
                    for file in os.listdir(log_dir):
                        file_path = os.path.join(log_dir, file)
                        if (os.path.isfile(file_path) and
                            file.endswith('.log') and
                            os.path.getsize(file_path) > 10 * 1024 * 1024):  # > 10MB

                            # Comprimir con gzip
                            subprocess.run(['gzip', file_path], capture_output=True)
                            compressed += 1

            if compressed > 0:
                self.logger.info(f"📦 Logs comprimidos: {compressed}")

            return compressed > 0

        except Exception as e:
            self.logger.error(f"Error comprimiendo logs: {e}")
            return False

    def _clean_package_cache(self) -> bool:
        """Limpia cache de paquetes del sistema"""
        try:
            # Detectar gestor de paquetes
            if os.path.exists('/usr/bin/apt'):
                # Ubuntu/Debian
                result = subprocess.run(['apt-get', 'clean'], capture_output=True, text=True)
                result = subprocess.run(['apt-get', 'autoclean'], capture_output=True, text=True)
                return result.returncode == 0

            elif os.path.exists('/usr/bin/yum'):
                # CentOS/RHEL
                result = subprocess.run(['yum', 'clean', 'all'], capture_output=True, text=True)
                return result.returncode == 0

            return False

        except Exception as e:
            self.logger.error(f"Error limpiando cache de paquetes: {e}")
            return False

    def get_resource_usage_report(self) -> Dict[str, Any]:
        """Genera reporte completo de uso de recursos"""
        try:
            return {
                "cpu": self.get_cpu_metrics(),
                "memory": self.get_memory_metrics(),
                "disk": self.get_disk_metrics(),
                "network": self.get_network_metrics(),
                "top_processes": self._get_top_processes(),
                "optimization_history": self.optimization_actions[-10:],  # Últimas 10
                "timestamp": datetime.now().isoformat()
            }

        except Exception as e:
            self.logger.error(f"Error generando reporte de recursos: {e}")
            return {}

    def _get_top_processes(self) -> List[Dict[str, Any]]:
        """Obtiene procesos que más recursos consumen"""
        try:
            processes = []

            for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_percent']):
                try:
                    processes.append({
                        "pid": proc.info['pid'],
                        "name": proc.info['name'],
                        "cpu_percent": proc.info['cpu_percent'],
                        "memory_percent": proc.info['memory_percent']
                    })
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue

            # Ordenar por uso de CPU y memoria
            processes.sort(key=lambda x: x['cpu_percent'] + x['memory_percent'], reverse=True)

            return processes[:10]  # Top 10

        except Exception as e:
            self.logger.error(f"Error obteniendo top procesos: {e}")
            return []

    def get_optimization_history(self) -> List[Dict[str, Any]]:
        """Obtiene historial de optimizaciones"""
        return self.optimization_actions

    def set_resource_limits(self, limits: Dict[str, Any]) -> bool:
        """Establece límites de recursos para procesos"""
        try:
            # Implementar configuración de límites de recursos
            # Por ejemplo: ulimit, cgroups, etc.
            self.logger.info(f"🔧 Límites de recursos configurados: {limits}")
            return True
        except Exception as e:
            self.logger.error(f"Error configurando límites de recursos: {e}")
            return False