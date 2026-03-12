from typing import List, Dict, Any, Optional
from .unified_manager import manager
import logging
import time
import threading

logger = logging.getLogger(__name__)

class GlobalLoadBalancer:
    """Balanceador de carga global con failover automático"""

    def __init__(self, name: str, backends: List[Dict[str, Any]]):
        self.name = name
        self.backends = backends  # Lista de backends con provider, region, etc.
        self.health_checks = {}
        self.active_backends = set()
        self.failover_enabled = True
        self.health_check_interval = 30  # segundos
        self.failover_threshold = 3  # fallos consecutivos para failover
        self._health_check_thread = None
        self._running = False

    def start(self):
        """Inicia el balanceador de carga global"""
        logger.info(f"Iniciando Global Load Balancer: {self.name}")

        # Crear load balancers en cada proveedor
        for backend in self.backends:
            try:
                provider = backend['provider']
                lb_config = {
                    'name': f"{self.name}-{provider}",
                    'region': backend.get('region', 'us-east-1'),
                    'backends': backend.get('instances', [])
                }

                lb = manager.create_global_load_balancer(self.name, [backend])
                backend['load_balancer'] = lb
                self.active_backends.add(backend['id'])

                logger.info(f"Load balancer creado en {provider}: {lb}")

            except Exception as e:
                logger.error(f"Error creando load balancer en {provider}: {e}")

        # Iniciar health checks
        self._start_health_checks()

    def stop(self):
        """Detiene el balanceador de carga global"""
        logger.info(f"Deteniendo Global Load Balancer: {self.name}")
        self._running = False
        if self._health_check_thread:
            self._health_check_thread.join()

    def _start_health_checks(self):
        """Inicia el hilo de health checks"""
        self._running = True
        self._health_check_thread = threading.Thread(target=self._health_check_loop)
        self._health_check_thread.daemon = True
        self._health_check_thread.start()

    def _health_check_loop(self):
        """Loop de health checks"""
        while self._running:
            try:
                self._perform_health_checks()
                time.sleep(self.health_check_interval)
            except Exception as e:
                logger.error(f"Error en health check loop: {e}")
                time.sleep(self.health_check_interval)

    def _perform_health_checks(self):
        """Realiza health checks en todos los backends"""
        for backend in self.backends:
            backend_id = backend['id']
            provider = backend['provider']

            try:
                # Health check simplificado - verificar que las instancias estén corriendo
                provider_instance = manager.get_provider(provider)
                instances = backend.get('instances', [])

                healthy_instances = 0
                for instance_id in instances:
                    if self._check_instance_health(provider, instance_id):
                        healthy_instances += 1

                # Actualizar estado del backend
                is_healthy = healthy_instances > 0
                previous_state = self.health_checks.get(backend_id, {}).get('healthy', True)

                self.health_checks[backend_id] = {
                    'healthy': is_healthy,
                    'healthy_instances': healthy_instances,
                    'total_instances': len(instances),
                    'last_check': time.time(),
                    'consecutive_failures': 0 if is_healthy else self.health_checks.get(backend_id, {}).get('consecutive_failures', 0) + 1
                }

                # Trigger failover si es necesario
                if not is_healthy and previous_state and self.failover_enabled:
                    consecutive_failures = self.health_checks[backend_id]['consecutive_failures']
                    if consecutive_failures >= self.failover_threshold:
                        self._trigger_failover(backend)

            except Exception as e:
                logger.error(f"Error en health check para backend {backend_id}: {e}")

    def _check_instance_health(self, provider: str, instance_id: str) -> bool:
        """Verifica la salud de una instancia específica"""
        try:
            provider_instance = manager.get_provider(provider)
            vms = provider_instance.list_vms()

            vm = next((v for v in vms if v['id'] == instance_id), None)
            if vm and vm['status'] in ['running', 'active']:
                return True

            return False

        except Exception as e:
            logger.error(f"Error verificando salud de instancia {instance_id}: {e}")
            return False

    def _trigger_failover(self, failed_backend: Dict[str, Any]):
        """Activa failover para un backend fallido"""
        logger.warning(f"Triggering failover for backend {failed_backend['id']}")

        # Remover del conjunto de backends activos
        self.active_backends.discard(failed_backend['id'])

        # Buscar backend alternativo en otra región/proveedor
        alternative_backend = self._find_alternative_backend(failed_backend)

        if alternative_backend:
            logger.info(f"Failover: Switching to alternative backend {alternative_backend['id']}")

            # Redistribuir carga al backend alternativo
            self._redistribute_load(alternative_backend)

            # Intentar recuperar el backend fallido
            self._schedule_recovery_check(failed_backend)
        else:
            logger.error("No alternative backend available for failover")

    def _find_alternative_backend(self, failed_backend: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Encuentra un backend alternativo para failover"""
        failed_provider = failed_backend['provider']
        failed_region = failed_backend.get('region')

        for backend in self.backends:
            if (backend['id'] != failed_backend['id'] and
                backend['id'] in self.active_backends and
                (backend['provider'] != failed_provider or backend.get('region') != failed_region)):
                return backend

        return None

    def _redistribute_load(self, target_backend: Dict[str, Any]):
        """Redistribuye la carga al backend alternativo"""
        logger.info(f"Redistributing load to backend {target_backend['id']}")

        # En implementación real, esto actualizaría las reglas de routing
        # del load balancer global para dirigir tráfico al backend alternativo

        # Actualizar métricas
        target_backend['load_percentage'] = min(100, target_backend.get('load_percentage', 0) + 50)

    def _schedule_recovery_check(self, backend: Dict[str, Any]):
        """Programa una verificación de recuperación para el backend fallido"""
        def recovery_check():
            time.sleep(60)  # Esperar 1 minuto antes de verificar recuperación

            backend_id = backend['id']
            health_info = self.health_checks.get(backend_id, {})

            if health_info.get('healthy', False):
                logger.info(f"Backend {backend_id} recovered, adding back to active backends")
                self.active_backends.add(backend_id)

                # Re-balancear carga
                self._rebalance_load()

        recovery_thread = threading.Thread(target=recovery_check)
        recovery_thread.daemon = True
        recovery_thread.start()

    def _rebalance_load(self):
        """Re-balancea la carga entre backends activos"""
        active_count = len(self.active_backends)
        if active_count > 0:
            load_per_backend = 100 / active_count

            for backend in self.backends:
                if backend['id'] in self.active_backends:
                    backend['load_percentage'] = load_per_backend

            logger.info(f"Load rebalanced: {load_per_backend}% per backend")

    def get_status(self) -> Dict[str, Any]:
        """Obtiene el estado actual del load balancer global"""
        return {
            'name': self.name,
            'active_backends': list(self.active_backends),
            'total_backends': len(self.backends),
            'health_checks': self.health_checks,
            'failover_enabled': self.failover_enabled,
            'backends': [
                {
                    'id': b['id'],
                    'provider': b['provider'],
                    'region': b.get('region'),
                    'healthy': self.health_checks.get(b['id'], {}).get('healthy', False),
                    'load_percentage': b.get('load_percentage', 0)
                }
                for b in self.backends
            ]
        }

    def update_backend_config(self, backend_id: str, config: Dict[str, Any]):
        """Actualiza la configuración de un backend"""
        for backend in self.backends:
            if backend['id'] == backend_id:
                backend.update(config)
                logger.info(f"Updated configuration for backend {backend_id}")
                break

class LoadBalancerManager:
    """Gestor de balanceadores de carga globales"""

    def __init__(self):
        self.load_balancers = {}

    def create_global_load_balancer(self, name: str, backends: List[Dict[str, Any]]) -> GlobalLoadBalancer:
        """Crea un nuevo balanceador de carga global"""
        glb = GlobalLoadBalancer(name, backends)
        self.load_balancers[name] = glb
        glb.start()
        return glb

    def get_load_balancer(self, name: str) -> Optional[GlobalLoadBalancer]:
        """Obtiene un balanceador de carga por nombre"""
        return self.load_balancers.get(name)

    def list_load_balancers(self) -> List[str]:
        """Lista todos los balanceadores de carga"""
        return list(self.load_balancers.keys())

    def remove_load_balancer(self, name: str):
        """Elimina un balanceador de carga"""
        if name in self.load_balancers:
            self.load_balancers[name].stop()
            del self.load_balancers[name]

# Instancia global del gestor
load_balancer_manager = LoadBalancerManager()