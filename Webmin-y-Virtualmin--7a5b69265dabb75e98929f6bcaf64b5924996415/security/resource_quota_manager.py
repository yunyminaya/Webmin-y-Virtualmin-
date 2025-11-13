#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
📊 SISTEMA DE GESTIÓN DE RECURSOS Y CUOTAS
===========================================
Control de recursos y límites por namespace para Webmin/Virtualmin
Prevención de agotamiento de recursos y ataques DoS
"""

import os
import json
import time
import psutil
import logging
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum
import threading
import collections
from datetime import datetime, timedelta

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/webmin/resource_quota.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class ResourceType(Enum):
    """Tipos de recursos monitoreados"""
    CPU = "cpu"
    MEMORY = "memory"
    DISK = "disk"
    NETWORK = "network"
    PROCESSES = "processes"
    FILES = "files"
    CONNECTIONS = "connections"
    BANDWIDTH = "bandwidth"
    REQUESTS = "requests"
    EMAILS = "emails"
    DOMAINS = "domains"
    DATABASES = "databases"
    BACKUPS = "backups"

class QuotaType(Enum):
    """Tipos de cuotas"""
    HARD = "hard"      # Límite absoluto, no se puede exceder
    SOFT = "soft"      # Límite con advertencia
    BURST = "burst"    # Límite temporal para picos

class QuotaAction(Enum):
    """Acciones cuando se excede una cuota"""
    BLOCK = "block"           # Bloquear la operación
    THROTTLE = "throttle"     # Limitar la velocidad
    WARN = "warn"             # Solo advertir
    LOG = "log"               # Solo registrar
    NOTIFY = "notify"         # Enviar notificación
    KILL = "kill"             # Terminar proceso

@dataclass
class ResourceQuota:
    """Definición de una cuota de recurso"""
    namespace: str
    resource_type: ResourceType
    quota_type: QuotaType
    limit_value: float
    current_usage: float = 0.0
    burst_limit: float = None
    grace_period: int = 300  # segundos
    action: QuotaAction = QuotaAction.WARN
    is_active: bool = True
    created_at: float = None
    updated_at: float = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = time.time()
        if self.updated_at is None:
            self.updated_at = time.time()

@dataclass
class ResourceUsage:
    """Registro de uso de recursos"""
    namespace: str
    resource_type: ResourceType
    current_value: float
    peak_value: float
    average_value: float
    timestamp: float
    process_id: Optional[str] = None
    user_id: Optional[str] = None
    metadata: Dict[str, Any] = None

@dataclass
class QuotaViolation:
    """Registro de violación de cuota"""
    namespace: str
    resource_type: ResourceType
    quota_type: QuotaType
    limit_value: float
    actual_value: float
    violation_percentage: float
    action_taken: QuotaAction
    timestamp: float
    resolved: bool = False
    resolved_at: float = None

class ResourceQuotaManager:
    """Gestor principal de cuotas de recursos"""
    
    def __init__(self, config_dir: str = "/etc/webmin/quotas"):
        self.config_dir = config_dir
        self.quotas_file = os.path.join(config_dir, "quotas.json")
        self.usage_file = os.path.join(config_dir, "usage.json")
        self.violations_file = os.path.join(config_dir, "violations.json")
        
        # Crear directorio de configuración
        os.makedirs(config_dir, mode=0o700, exist_ok=True)
        
        # Inicializar datos
        self.quotas: Dict[str, ResourceQuota] = {}
        self.usage_history: Dict[str, List[ResourceUsage]] = collections.defaultdict(list)
        self.violations: List[QuotaViolation] = []
        
        # Cargar datos existentes
        self._load_data()
        
        # Inicializar cuotas por defecto
        self._initialize_default_quotas()
        
        # Iniciar monitoreo en segundo plano
        self.monitoring_active = False
        self.monitoring_thread = None
    
    def _load_data(self):
        """Cargar datos desde archivos"""
        try:
            # Cargar cuotas
            if os.path.exists(self.quotas_file):
                with open(self.quotas_file, 'r') as f:
                    quotas_data = json.load(f)
                    
                    for quota_id, quota_info in quotas_data.items():
                        self.quotas[quota_id] = ResourceQuota(
                            namespace=quota_info['namespace'],
                            resource_type=ResourceType(quota_info['resource_type']),
                            quota_type=QuotaType(quota_info['quota_type']),
                            limit_value=quota_info['limit_value'],
                            current_usage=quota_info.get('current_usage', 0.0),
                            burst_limit=quota_info.get('burst_limit'),
                            grace_period=quota_info.get('grace_period', 300),
                            action=QuotaAction(quota_info.get('action', 'warn')),
                            is_active=quota_info.get('is_active', True),
                            created_at=quota_info.get('created_at'),
                            updated_at=quota_info.get('updated_at')
                        )
                
                logger.info(f"Cargadas {len(self.quotas)} cuotas")
            
            # Cargar violaciones
            if os.path.exists(self.violations_file):
                with open(self.violations_file, 'r') as f:
                    violations_data = json.load(f)
                    
                    for violation_info in violations_data:
                        self.violations.append(QuotaViolation(
                            namespace=violation_info['namespace'],
                            resource_type=ResourceType(violation_info['resource_type']),
                            quota_type=QuotaType(violation_info['quota_type']),
                            limit_value=violation_info['limit_value'],
                            actual_value=violation_info['actual_value'],
                            violation_percentage=violation_info['violation_percentage'],
                            action_taken=QuotaAction(violation_info['action_taken']),
                            timestamp=violation_info['timestamp'],
                            resolved=violation_info.get('resolved', False),
                            resolved_at=violation_info.get('resolved_at')
                        ))
                
                logger.info(f"Cargadas {len(self.violations)} violaciones")
                
        except Exception as e:
            logger.error(f"Error cargando datos: {e}")
    
    def _save_data(self):
        """Guardar datos a archivos"""
        try:
            # Guardar cuotas
            quotas_data = {}
            for quota_id, quota in self.quotas.items():
                quotas_data[quota_id] = {
                    'namespace': quota.namespace,
                    'resource_type': quota.resource_type.value,
                    'quota_type': quota.quota_type.value,
                    'limit_value': quota.limit_value,
                    'current_usage': quota.current_usage,
                    'burst_limit': quota.burst_limit,
                    'grace_period': quota.grace_period,
                    'action': quota.action.value,
                    'is_active': quota.is_active,
                    'created_at': quota.created_at,
                    'updated_at': quota.updated_at
                }
            
            with open(self.quotas_file, 'w') as f:
                json.dump(quotas_data, f, indent=2)
            
            os.chmod(self.quotas_file, 0o600)
            
            # Guardar violaciones
            violations_data = []
            for violation in self.violations:
                violations_data.append({
                    'namespace': violation.namespace,
                    'resource_type': violation.resource_type.value,
                    'quota_type': violation.quota_type.value,
                    'limit_value': violation.limit_value,
                    'actual_value': violation.actual_value,
                    'violation_percentage': violation.violation_percentage,
                    'action_taken': violation.action_taken.value,
                    'timestamp': violation.timestamp,
                    'resolved': violation.resolved,
                    'resolved_at': violation.resolved_at
                })
            
            with open(self.violations_file, 'w') as f:
                json.dump(violations_data, f, indent=2)
            
            os.chmod(self.violations_file, 0o600)
            
            logger.info("Datos guardados exitosamente")
            
        except Exception as e:
            logger.error(f"Error guardando datos: {e}")
    
    def _initialize_default_quotas(self):
        """Inicializar cuotas por defecto"""
        default_quotas = {
            # Cuotas del sistema
            'system_cpu_hard': ResourceQuota(
                namespace='system',
                resource_type=ResourceType.CPU,
                quota_type=QuotaType.HARD,
                limit_value=90.0,  # 90% de CPU
                action=QuotaAction.THROTTLE
            ),
            'system_memory_hard': ResourceQuota(
                namespace='system',
                resource_type=ResourceType.MEMORY,
                quota_type=QuotaType.HARD,
                limit_value=85.0,  # 85% de memoria
                action=QuotaAction.KILL
            ),
            'system_processes_soft': ResourceQuota(
                namespace='system',
                resource_type=ResourceType.PROCESSES,
                quota_type=QuotaType.SOFT,
                limit_value=1000,
                action=QuotaAction.WARN
            ),
            
            # Cuotas por usuario
            'user_cpu_soft': ResourceQuota(
                namespace='user',
                resource_type=ResourceType.CPU,
                quota_type=QuotaType.SOFT,
                limit_value=50.0,  # 50% de CPU por usuario
                action=QuotaAction.THROTTLE
            ),
            'user_memory_soft': ResourceQuota(
                namespace='user',
                resource_type=ResourceType.MEMORY,
                quota_type=QuotaType.SOFT,
                limit_value=2048.0,  # 2GB por usuario
                action=QuotaAction.WARN
            ),
            'user_processes_hard': ResourceQuota(
                namespace='user',
                resource_type=ResourceType.PROCESSES,
                quota_type=QuotaType.HARD,
                limit_value=100,
                action=QuotaAction.BLOCK
            ),
            
            # Cuotas de dominio
            'domain_bandwidth_hard': ResourceQuota(
                namespace='domain',
                resource_type=ResourceType.BANDWIDTH,
                quota_type=QuotaType.HARD,
                limit_value=10737418240.0,  # 10GB por mes
                action=QuotaAction.THROTTLE
            ),
            'domain_requests_soft': ResourceQuota(
                namespace='domain',
                resource_type=ResourceType.REQUESTS,
                quota_type=QuotaType.SOFT,
                limit_value=10000,  # 10k requests por hora
                action=QuotaAction.WARN
            ),
            'domain_files_hard': ResourceQuota(
                namespace='domain',
                resource_type=ResourceType.FILES,
                quota_type=QuotaType.HARD,
                limit_value=100000,  # 100k archivos
                action=QuotaAction.BLOCK
            ),
            
            # Cuotas de email
            'email_hourly_soft': ResourceQuota(
                namespace='email',
                resource_type=ResourceType.EMAILS,
                quota_type=QuotaType.SOFT,
                limit_value=100,  # 100 emails por hora
                action=QuotaAction.THROTTLE
            ),
            'email_daily_hard': ResourceQuota(
                namespace='email',
                resource_type=ResourceType.EMAILS,
                quota_type=QuotaType.HARD,
                limit_value=1000,  # 1000 emails por día
                action=QuotaAction.BLOCK
            ),
            
            # Cuotas de backup
            'backup_size_hard': ResourceQuota(
                namespace='backup',
                resource_type=ResourceType.BACKUPS,
                quota_type=QuotaType.HARD,
                limit_value=536870912000.0,  # 50GB total de backups
                action=QuotaAction.BLOCK
            ),
            'backup_daily_soft': ResourceQuota(
                namespace='backup',
                resource_type=ResourceType.BACKUPS,
                quota_type=QuotaType.SOFT,
                limit_value=5,  # 5 backups por día
                action=QuotaAction.WARN
            )
        }
        
        # Agregar cuotas por defecto si no existen
        for quota_id, quota in default_quotas.items():
            if quota_id not in self.quotas:
                self.quotas[quota_id] = quota
                logger.info(f"Cuota por defecto creada: {quota_id}")
        
        # Guardar si se agregaron nuevas cuotas
        self._save_data()
    
    def create_quota(self, namespace: str, resource_type: ResourceType, quota_type: QuotaType,
                   limit_value: float, action: QuotaAction = QuotaAction.WARN,
                   burst_limit: float = None, grace_period: int = 300) -> str:
        """Crear una nueva cuota"""
        quota_id = f"{namespace}_{resource_type.value}_{quota_type.value}"
        
        quota = ResourceQuota(
            namespace=namespace,
            resource_type=resource_type,
            quota_type=quota_type,
            limit_value=limit_value,
            burst_limit=burst_limit,
            grace_period=grace_period,
            action=action
        )
        
        self.quotas[quota_id] = quota
        self._save_data()
        
        logger.info(f"Cuota creada: {quota_id}")
        return quota_id
    
    def update_quota(self, quota_id: str, limit_value: float = None, action: QuotaAction = None,
                   is_active: bool = None) -> bool:
        """Actualizar una cuota existente"""
        if quota_id not in self.quotas:
            logger.error(f"Cuota no encontrada: {quota_id}")
            return False
        
        quota = self.quotas[quota_id]
        
        if limit_value is not None:
            quota.limit_value = limit_value
        
        if action is not None:
            quota.action = action
        
        if is_active is not None:
            quota.is_active = is_active
        
        quota.updated_at = time.time()
        self._save_data()
        
        logger.info(f"Cuota actualizada: {quota_id}")
        return True
    
    def delete_quota(self, quota_id: str) -> bool:
        """Eliminar una cuota"""
        if quota_id not in self.quotas:
            logger.error(f"Cuota no encontrada: {quota_id}")
            return False
        
        del self.quotas[quota_id]
        self._save_data()
        
        logger.info(f"Cuota eliminada: {quota_id}")
        return True
    
    def check_quota(self, namespace: str, resource_type: ResourceType, 
                  current_value: float, user_id: str = None, 
                  process_id: str = None) -> Tuple[bool, QuotaAction]:
        """Verificar si se excede una cuota"""
        relevant_quotas = []
        
        # Encontrar cuotas relevantes para este namespace y tipo de recurso
        for quota_id, quota in self.quotas.items():
            if (quota.namespace == namespace and 
                quota.resource_type == resource_type and 
                quota.is_active):
                relevant_quotas.append(quota)
        
        if not relevant_quotas:
            return True, QuotaAction.WARN  # Sin cuotas definidas
        
        # Verificar cada cuota relevante
        for quota in relevant_quotas:
            # Actualizar uso actual
            quota.current_usage = current_value
            
            # Verificar límite
            exceeds_limit = False
            violation_percentage = 0.0
            
            if quota.quota_type == QuotaType.HARD:
                exceeds_limit = current_value > quota.limit_value
                if exceeds_limit:
                    violation_percentage = ((current_value - quota.limit_value) / quota.limit_value) * 100
            
            elif quota.quota_type == QuotaType.SOFT:
                exceeds_limit = current_value > quota.limit_value
                if exceeds_limit:
                    violation_percentage = ((current_value - quota.limit_value) / quota.limit_value) * 100
            
            elif quota.quota_type == QuotaType.BURST:
                # Permitir exceder temporalmente hasta el límite burst
                burst_limit = quota.burst_limit or (quota.limit_value * 1.5)
                exceeds_limit = current_value > burst_limit
                if exceeds_limit:
                    violation_percentage = ((current_value - burst_limit) / burst_limit) * 100
            
            # Si se excede el límite, registrar violación
            if exceeds_limit:
                violation = QuotaViolation(
                    namespace=namespace,
                    resource_type=resource_type,
                    quota_type=quota.quota_type,
                    limit_value=quota.limit_value,
                    actual_value=current_value,
                    violation_percentage=violation_percentage,
                    action_taken=quota.action,
                    timestamp=time.time()
                )
                
                self.violations.append(violation)
                
                logger.warning(f"Violación de cuota: {namespace}/{resource_type.value} - {current_value}/{quota.limit_value} ({violation_percentage:.1f}%)")
                
                # Ejecutar acción correspondiente
                self._execute_quota_action(quota.action, namespace, resource_type, current_value, user_id, process_id)
                
                return False, quota.action
        
        # Actualizar cuota
        self._save_data()
        
        return True, QuotaAction.WARN
    
    def _execute_quota_action(self, action: QuotaAction, namespace: str, resource_type: ResourceType,
                         current_value: float, user_id: str = None, process_id: str = None):
        """Ejecutar acción cuando se excede cuota"""
        try:
            if action == QuotaAction.BLOCK:
                # Bloquear operación (implementación específica del recurso)
                logger.info(f"Bloqueando operación: {namespace}/{resource_type.value}")
                
            elif action == QuotaAction.THROTTLE:
                # Limitar velocidad/recursos
                logger.info(f"Limitando recurso: {namespace}/{resource_type.value}")
                
            elif action == QuotaAction.WARN:
                # Enviar advertencia
                logger.warning(f"Advertencia de cuota: {namespace}/{resource_type.value} = {current_value}")
                
            elif action == QuotaAction.LOG:
                # Solo registrar (ya se hizo)
                logger.info(f"Registrando uso: {namespace}/{resource_type.value} = {current_value}")
                
            elif action == QuotaAction.NOTIFY:
                # Enviar notificación
                logger.info(f"Notificando exceso de cuota: {namespace}/{resource_type.value}")
                
            elif action == QuotaAction.KILL:
                # Terminar proceso
                if process_id:
                    try:
                        import signal
                        os.kill(int(process_id), signal.SIGTERM)
                        logger.info(f"Proceso terminado por exceder cuota: {process_id}")
                    except Exception as e:
                        logger.error(f"Error terminando proceso {process_id}: {e}")
                
        except Exception as e:
            logger.error(f"Error ejecutando acción de cuota: {e}")
    
    def get_current_usage(self, resource_type: ResourceType) -> float:
        """Obtener uso actual del sistema para un tipo de recurso"""
        try:
            if resource_type == ResourceType.CPU:
                return psutil.cpu_percent(interval=1)
            
            elif resource_type == ResourceType.MEMORY:
                memory = psutil.virtual_memory()
                return memory.percent
            
            elif resource_type == ResourceType.DISK:
                disk = psutil.disk_usage('/')
                return disk.percent
            
            elif resource_type == ResourceType.PROCESSES:
                return len(psutil.pids())
            
            elif resource_type == ResourceType.NETWORK:
                network = psutil.net_io_counters()
                return network.bytes_sent + network.bytes_recv
            
            elif resource_type == ResourceType.CONNECTIONS:
                connections = len(psutil.net_connections())
                return connections
            
            else:
                return 0.0
                
        except Exception as e:
            logger.error(f"Error obteniendo uso de {resource_type.value}: {e}")
            return 0.0
    
    def record_usage(self, namespace: str, resource_type: ResourceType, value: float,
                   user_id: str = None, process_id: str = None, metadata: Dict = None):
        """Registrar uso de recursos"""
        usage = ResourceUsage(
            namespace=namespace,
            resource_type=resource_type,
            current_value=value,
            peak_value=value,
            average_value=value,
            timestamp=time.time(),
            process_id=process_id,
            user_id=user_id,
            metadata=metadata or {}
        )
        
        # Agregar al historial
        self.usage_history[f"{namespace}_{resource_type.value}"].append(usage)
        
        # Mantener solo últimos 1000 registros por tipo
        if len(self.usage_history[f"{namespace}_{resource_type.value}"]) > 1000:
            self.usage_history[f"{namespace}_{resource_type.value}"] = self.usage_history[f"{namespace}_{resource_type.value}"][-1000:]
        
        # Verificar cuotas
        self.check_quota(namespace, resource_type, value, user_id, process_id)
    
    def get_quota_status(self, namespace: str = None, resource_type: ResourceType = None) -> Dict:
        """Obtener estado de cuotas"""
        status = {
            'quotas': [],
            'violations': [],
            'summary': {
                'total_quotas': len(self.quotas),
                'active_quotas': len([q for q in self.quotas.values() if q.is_active]),
                'total_violations': len(self.violations),
                'unresolved_violations': len([v for v in self.violations if not v.resolved])
            }
        }
        
        # Filtrar cuotas si se especifica namespace o resource_type
        for quota_id, quota in self.quotas.items():
            if namespace and quota.namespace != namespace:
                continue
            if resource_type and quota.resource_type != resource_type:
                continue
            
            # Calcular porcentaje de uso
            usage_percentage = 0.0
            if quota.limit_value > 0:
                usage_percentage = (quota.current_usage / quota.limit_value) * 100
            
            status['quotas'].append({
                'quota_id': quota_id,
                'namespace': quota.namespace,
                'resource_type': quota.resource_type.value,
                'quota_type': quota.quota_type.value,
                'limit_value': quota.limit_value,
                'current_usage': quota.current_usage,
                'usage_percentage': usage_percentage,
                'burst_limit': quota.burst_limit,
                'action': quota.action.value,
                'is_active': quota.is_active,
                'status': 'exceeded' if usage_percentage > 100 else 'warning' if usage_percentage > 80 else 'normal'
            })
        
        # Agregar violaciones recientes
        recent_violations = [v for v in self.violations if not v.resolved and (time.time() - v.timestamp) < 3600]
        status['violations'] = [
            {
                'namespace': v.namespace,
                'resource_type': v.resource_type.value,
                'quota_type': v.quota_type.value,
                'violation_percentage': v.violation_percentage,
                'action_taken': v.action_taken.value,
                'timestamp': v.timestamp,
                'time_ago': time.time() - v.timestamp
            }
            for v in recent_violations
        ]
        
        return status
    
    def start_monitoring(self, interval: int = 30):
        """Iniciar monitoreo automático"""
        if self.monitoring_active:
            logger.warning("Monitoreo ya está activo")
            return
        
        self.monitoring_active = True
        self.monitoring_thread = threading.Thread(target=self._monitoring_loop, args=(interval,))
        self.monitoring_thread.daemon = True
        self.monitoring_thread.start()
        
        logger.info(f"Monitoreo iniciado con intervalo de {interval} segundos")
    
    def stop_monitoring(self):
        """Detener monitoreo automático"""
        self.monitoring_active = False
        if self.monitoring_thread:
            self.monitoring_thread.join(timeout=5)
        
        logger.info("Monitoreo detenido")
    
    def _monitoring_loop(self, interval: int):
        """Bucle de monitoreo"""
        while self.monitoring_active:
            try:
                # Monitorear recursos del sistema
                system_cpu = self.get_current_usage(ResourceType.CPU)
                system_memory = self.get_current_usage(ResourceType.MEMORY)
                system_processes = self.get_current_usage(ResourceType.PROCESSES)
                
                # Registrar uso del sistema
                self.record_usage('system', ResourceType.CPU, system_cpu)
                self.record_usage('system', ResourceType.MEMORY, system_memory)
                self.record_usage('system', ResourceType.PROCESSES, system_processes)
                
                # Limpiar violaciones resueltas antiguas
                self._cleanup_old_violations()
                
                time.sleep(interval)
                
            except Exception as e:
                logger.error(f"Error en bucle de monitoreo: {e}")
                time.sleep(interval)
    
    def _cleanup_old_violations(self):
        """Limpiar violaciones antiguas"""
        current_time = time.time()
        cutoff_time = current_time - (7 * 24 * 3600)  # 7 días
        
        # Marcar como resueltas las violaciones antiguas
        for violation in self.violations:
            if not violation.resolved and violation.timestamp < cutoff_time:
                violation.resolved = True
                violation.resolved_at = current_time
        
        # Eliminar violaciones resueltas muy antiguas (30 días)
        self.violations = [v for v in self.violations if not v.resolved or v.resolved_at > (current_time - (30 * 24 * 3600))]
        
        self._save_data()
    
    def generate_quota_report(self, namespace: str = None, days: int = 7) -> Dict:
        """Generar reporte de cuotas"""
        cutoff_time = time.time() - (days * 24 * 3600)
        
        report = {
            'period': {
                'days': days,
                'start_time': cutoff_time,
                'end_time': time.time()
            },
            'summary': {},
            'quotas': [],
            'violations': [],
            'trends': {}
        }
        
        # Filtrar cuotas por namespace si se especifica
        quotas_to_report = self.quotas.values()
        if namespace:
            quotas_to_report = [q for q in quotas_to_report if q.namespace == namespace]
        
        # Agregar información de cuotas
        for quota in quotas_to_report:
            quota_info = {
                'namespace': quota.namespace,
                'resource_type': quota.resource_type.value,
                'quota_type': quota.quota_type.value,
                'limit_value': quota.limit_value,
                'current_usage': quota.current_usage,
                'usage_percentage': (quota.current_usage / quota.limit_value * 100) if quota.limit_value > 0 else 0,
                'burst_limit': quota.burst_limit,
                'action': quota.action.value,
                'is_active': quota.is_active
            }
            report['quotas'].append(quota_info)
        
        # Agregar violaciones del período
        period_violations = [v for v in self.violations if v.timestamp >= cutoff_time]
        if namespace:
            period_violations = [v for v in period_violations if v.namespace == namespace]
        
        report['violations'] = [
            {
                'namespace': v.namespace,
                'resource_type': v.resource_type.value,
                'quota_type': v.quota_type.value,
                'violation_percentage': v.violation_percentage,
                'action_taken': v.action_taken.value,
                'timestamp': v.timestamp,
                'resolved': v.resolved
            }
            for v in period_violations
        ]
        
        # Calcular tendencias
        resource_types = set(q.resource_type for q in quotas_to_report)
        for resource_type in resource_types:
            usage_key = f"{namespace}_{resource_type.value}" if namespace else f"system_{resource_type.value}"
            if usage_key in self.usage_history:
                usage_data = [u for u in self.usage_history[usage_key] if u.timestamp >= cutoff_time]
                
                if usage_data:
                    values = [u.current_value for u in usage_data]
                    report['trends'][resource_type.value] = {
                        'min': min(values),
                        'max': max(values),
                        'avg': sum(values) / len(values),
                        'samples': len(values)
                    }
        
        # Resumen
        report['summary'] = {
            'total_quotas': len(quotas_to_report),
            'active_quotas': len([q for q in quotas_to_report if q.is_active]),
            'total_violations': len(period_violations),
            'resolved_violations': len([v for v in period_violations if v.resolved]),
            'most_violated_resource': self._get_most_violated_resource(period_violations)
        }
        
        return report
    
    def _get_most_violated_resource(self, violations: List[QuotaViolation]) -> str:
        """Obtener el recurso más violado"""
        if not violations:
            return "none"
        
        resource_counts = {}
        for violation in violations:
            resource_type = violation.resource_type.value
            resource_counts[resource_type] = resource_counts.get(resource_type, 0) + 1
        
        return max(resource_counts, key=resource_counts.get) if resource_counts else "none"

def main():
    """Función principal para línea de comandos"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Sistema de gestión de cuotas de recursos')
    parser.add_argument('command', choices=[
        'create-quota', 'update-quota', 'delete-quota', 'list-quotas',
        'check-quota', 'start-monitoring', 'stop-monitoring', 'status', 'report'
    ])
    parser.add_argument('--namespace', help='Namespace de la cuota')
    parser.add_argument('--resource', choices=[t.value for t in ResourceType], help='Tipo de recurso')
    parser.add_argument('--type', choices=[t.value for t in QuotaType], help='Tipo de cuota')
    parser.add_argument('--limit', type=float, help='Límite de la cuota')
    parser.add_argument('--action', choices=[a.value for a in QuotaAction], help='Acción a ejecutar')
    parser.add_argument('--value', type=float, help='Valor actual para verificar')
    parser.add_argument('--quota-id', help='ID de la cuota')
    parser.add_argument('--interval', type=int, default=30, help='Intervalo de monitoreo en segundos')
    parser.add_argument('--days', type=int, default=7, help='Días para el reporte')
    
    args = parser.parse_args()
    
    # Inicializar gestor de cuotas
    manager = ResourceQuotaManager()
    
    try:
        if args.command == 'create-quota':
            if not all([args.namespace, args.resource, args.type, args.limit]):
                print("Error: se requieren --namespace, --resource, --type y --limit")
                return 1
            
            namespace = args.namespace
            resource_type = ResourceType(args.resource)
            quota_type = QuotaType(args.type)
            action = QuotaAction(args.action) if args.action else QuotaAction.WARN
            
            quota_id = manager.create_quota(namespace, resource_type, quota_type, args.limit, action)
            print(f"Cuota creada: {quota_id}")
            return 0
        
        elif args.command == 'list-quotas':
            status = manager.get_quota_status(args.namespace)
            print("Estado de cuotas:")
            for quota in status['quotas']:
                print(f"  {quota['quota_id']}:")
                print(f"    Namespace: {quota['namespace']}")
                print(f"    Recurso: {quota['resource_type']}")
                print(f"    Tipo: {quota['quota_type']}")
                print(f"    Límite: {quota['limit_value']}")
                print(f"    Uso actual: {quota['current_usage']}")
                print(f"    Porcentaje: {quota['usage_percentage']:.1f}%")
                print(f"    Estado: {quota['status']}")
            return 0
        
        elif args.command == 'status':
            status = manager.get_quota_status(args.namespace)
            print("Resumen del sistema:")
            print(f"  Total de cuotas: {status['summary']['total_quotas']}")
            print(f"  Cuotas activas: {status['summary']['active_quotas']}")
            print(f"  Total de violaciones: {status['summary']['total_violations']}")
            print(f"  Violaciones sin resolver: {status['summary']['unresolved_violations']}")
            return 0
        
        elif args.command == 'start-monitoring':
            manager.start_monitoring(args.interval)
            print("Monitoreo iniciado")
            return 0
        
        elif args.command == 'report':
            report = manager.generate_quota_report(args.namespace, args.days)
            print(f"Reporte de cuotas ({args.days} días):")
            print(json.dumps(report, indent=2))
            return 0
        
        else:
            print(f"Comando {args.command} no implementado")
            return 1
    
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())