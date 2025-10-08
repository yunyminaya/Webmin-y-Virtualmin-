from typing import List, Dict, Any, Optional
from .unified_manager import manager
from .monitoring_manager import monitor
import logging
import time
import threading

logger = logging.getLogger(__name__)

class CostOptimizer:
    """Optimizador automático de costos multi-nube"""

    def __init__(self):
        self.optimization_rules = self._load_default_rules()
        self.optimization_history = []
        self.optimization_interval = 3600  # 1 hora
        self.budget_limits = {
            'aws': 1000,  # USD por mes
            'azure': 1000,
            'gcp': 1000
        }
        self._optimizer_thread = None
        self._running = False

    def _load_default_rules(self) -> List[Dict[str, Any]]:
        """Carga reglas de optimización por defecto"""
        return [
            {
                'name': 'stop_idle_vms',
                'description': 'Detener VMs idle por más de 2 horas',
                'resource_type': 'vm',
                'condition': lambda metrics: metrics.get('cpu_usage', 0) < 5 and metrics.get('network_io', 0) < 100,
                'action': 'stop_vm',
                'cooldown_hours': 2
            },
            {
                'name': 'resize_oversized_vms',
                'description': 'Redimensionar VMs con baja utilización',
                'resource_type': 'vm',
                'condition': lambda metrics: metrics.get('cpu_usage', 0) < 30 and metrics.get('memory_usage', 0) < 40,
                'action': 'resize_vm',
                'target_size': 'smaller',
                'cooldown_hours': 24
            },
            {
                'name': 'delete_unused_volumes',
                'description': 'Eliminar volúmenes no adjuntos por más de 7 días',
                'resource_type': 'storage',
                'condition': lambda resource: resource.get('status') == 'unattached' and self._days_since_creation(resource) > 7,
                'action': 'delete_volume',
                'cooldown_hours': 168  # 7 días
            },
            {
                'name': 'switch_to_reserved_instances',
                'description': 'Recomendar instancias reservadas para uso consistente',
                'resource_type': 'vm',
                'condition': lambda metrics: metrics.get('uptime_percentage', 0) > 80,
                'action': 'recommend_reserved',
                'cooldown_hours': 720  # 30 días
            },
            {
                'name': 'optimize_storage_class',
                'description': 'Mover datos antiguos a storage más barato',
                'resource_type': 'storage',
                'condition': lambda resource: self._days_since_last_access(resource) > 30,
                'action': 'change_storage_class',
                'target_class': 'cold',
                'cooldown_hours': 720
            }
        ]

    def start_optimization(self):
        """Inicia la optimización automática"""
        if self._running:
            return

        self._running = True
        self._optimizer_thread = threading.Thread(target=self._optimization_loop)
        self._optimizer_thread.daemon = True
        self._optimizer_thread.start()
        logger.info("Optimización automática de costos iniciada")

    def stop_optimization(self):
        """Detiene la optimización automática"""
        self._running = False
        if self._optimizer_thread:
            self._optimizer_thread.join()
        logger.info("Optimización automática de costos detenida")

    def _optimization_loop(self):
        """Loop principal de optimización"""
        while self._running:
            try:
                self._run_optimization_cycle()
                time.sleep(self.optimization_interval)
            except Exception as e:
                logger.error(f"Error en optimization loop: {e}")
                time.sleep(self.optimization_interval)

    def _run_optimization_cycle(self):
        """Ejecuta un ciclo completo de optimización"""
        logger.info("Ejecutando ciclo de optimización de costos")

        # Obtener métricas actuales
        current_metrics = monitor.get_current_metrics()

        # Verificar límites de presupuesto
        self._check_budget_limits(current_metrics)

        # Aplicar reglas de optimización
        optimizations_applied = []

        for provider_name in ['aws', 'azure', 'gcp']:
            provider_metrics = current_metrics.get(provider_name, {})
            optimizations = self._optimize_provider(provider_name, provider_metrics)
            optimizations_applied.extend(optimizations)

        # Registrar optimizaciones aplicadas
        if optimizations_applied:
            self.optimization_history.append({
                'timestamp': time.time(),
                'optimizations': optimizations_applied,
                'total_savings': sum(opt.get('estimated_savings', 0) for opt in optimizations_applied)
            })

        logger.info(f"Ciclo de optimización completado: {len(optimizations_applied)} optimizaciones aplicadas")

    def _optimize_provider(self, provider_name: str, metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Optimiza recursos de un proveedor específico"""
        optimizations = []

        try:
            provider_instance = manager.get_provider(provider_name)

            # Optimizar VMs
            vm_optimizations = self._optimize_vms(provider_instance, metrics.get('vm_metrics', {}))
            optimizations.extend(vm_optimizations)

            # Optimizar storage
            storage_optimizations = self._optimize_storage(provider_instance, metrics.get('storage_metrics', {}))
            optimizations.extend(storage_optimizations)

            # Optimizar red
            network_optimizations = self._optimize_network(provider_instance, metrics.get('network_metrics', {}))
            optimizations.extend(network_optimizations)

        except Exception as e:
            logger.error(f"Error optimizando {provider_name}: {e}")

        return optimizations

    def _optimize_vms(self, provider_instance, vm_metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Optimiza VMs"""
        optimizations = []

        vms = vm_metrics.get('vms', [])

        for vm in vms:
            vm_id = vm['id']

            # Aplicar reglas de optimización
            for rule in self.optimization_rules:
                if rule['resource_type'] == 'vm' and self._should_apply_rule(rule, vm):
                    optimization = self._apply_vm_optimization(provider_instance, vm, rule)
                    if optimization:
                        optimizations.append(optimization)

        return optimizations

    def _optimize_storage(self, provider_instance, storage_metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Optimiza storage"""
        optimizations = []

        # Obtener lista de storage del proveedor
        storage_list = provider_instance.list_storage()

        for storage_item in storage_list:
            # Aplicar reglas de optimización
            for rule in self.optimization_rules:
                if rule['resource_type'] == 'storage' and self._should_apply_rule(rule, storage_item):
                    optimization = self._apply_storage_optimization(provider_instance, storage_item, rule)
                    if optimization:
                        optimizations.append(optimization)

        return optimizations

    def _optimize_network(self, provider_instance, network_metrics: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Optimiza recursos de red"""
        # Optimizaciones de red (simplificado)
        return []

    def _should_apply_rule(self, rule: Dict[str, Any], resource: Dict[str, Any]) -> bool:
        """Determina si una regla debe aplicarse a un recurso"""
        try:
            # Verificar condición
            if not rule['condition'](resource):
                return False

            # Verificar cooldown
            if self._is_in_cooldown(rule, resource):
                return False

            return True

        except Exception as e:
            logger.error(f"Error evaluando regla {rule['name']}: {e}")
            return False

    def _is_in_cooldown(self, rule: Dict[str, Any], resource: Dict[str, Any]) -> bool:
        """Verifica si un recurso está en período de cooldown para una regla"""
        cooldown_hours = rule.get('cooldown_hours', 0)
        if cooldown_hours == 0:
            return False

        # Verificar en historial de optimizaciones recientes
        cutoff_time = time.time() - (cooldown_hours * 60 * 60)

        for entry in self.optimization_history[-10:]:  # Últimas 10 entradas
            if entry['timestamp'] > cutoff_time:
                for opt in entry['optimizations']:
                    if (opt.get('resource_id') == resource.get('id') and
                        opt.get('rule_name') == rule['name']):
                        return True

        return False

    def _apply_vm_optimization(self, provider_instance, vm: Dict[str, Any], rule: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Aplica optimización a una VM"""
        action = rule['action']

        try:
            if action == 'stop_vm':
                # Solo recomendar, no ejecutar automáticamente
                return {
                    'rule_name': rule['name'],
                    'resource_type': 'vm',
                    'resource_id': vm['id'],
                    'action': 'recommend_stop',
                    'estimated_savings': self._estimate_vm_stop_savings(vm),
                    'auto_applied': False
                }

            elif action == 'resize_vm':
                # Recomendar redimensionamiento
                return {
                    'rule_name': rule['name'],
                    'resource_type': 'vm',
                    'resource_id': vm['id'],
                    'action': 'recommend_resize',
                    'target_size': rule.get('target_size'),
                    'estimated_savings': self._estimate_resize_savings(vm),
                    'auto_applied': False
                }

        except Exception as e:
            logger.error(f"Error aplicando optimización VM: {e}")

        return None

    def _apply_storage_optimization(self, provider_instance, storage_item: Dict[str, Any], rule: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Aplica optimización a storage"""
        action = rule['action']

        try:
            if action == 'delete_volume' and storage_item.get('status') == 'unattached':
                # Marcar para eliminación (requiere aprobación manual)
                return {
                    'rule_name': rule['name'],
                    'resource_type': 'storage',
                    'resource_id': storage_item['id'],
                    'action': 'recommend_delete',
                    'estimated_savings': self._estimate_storage_savings(storage_item),
                    'auto_applied': False
                }

            elif action == 'change_storage_class':
                return {
                    'rule_name': rule['name'],
                    'resource_type': 'storage',
                    'resource_id': storage_item['id'],
                    'action': 'recommend_change_class',
                    'target_class': rule.get('target_class'),
                    'estimated_savings': self._estimate_storage_class_savings(storage_item),
                    'auto_applied': False
                }

        except Exception as e:
            logger.error(f"Error aplicando optimización storage: {e}")

        return None

    def _estimate_vm_stop_savings(self, vm: Dict[str, Any]) -> float:
        """Estima ahorros por detener VM"""
        # Estimación simplificada basada en tipo de instancia
        instance_type = vm.get('instance_type', 't2.micro')
        hourly_rates = {
            't2.micro': 0.0116,
            't2.small': 0.023,
            't2.medium': 0.0464,
            'Standard_B1s': 0.012,
            'Standard_B2s': 0.048,
            'f1-micro': 0.0076,
            'n1-standard-1': 0.0475
        }
        hourly_rate = hourly_rates.get(instance_type, 0.01)
        return hourly_rate * 24 * 30  # Ahorro mensual estimado

    def _estimate_resize_savings(self, vm: Dict[str, Any]) -> float:
        """Estima ahorros por redimensionar VM"""
        return self._estimate_vm_stop_savings(vm) * 0.5  # 50% de ahorro estimado

    def _estimate_storage_savings(self, storage_item: Dict[str, Any]) -> float:
        """Estima ahorros por eliminar storage"""
        size_gb = storage_item.get('size_gb', 0)
        # $0.10 por GB por mes para storage general
        return size_gb * 0.10

    def _estimate_storage_class_savings(self, storage_item: Dict[str, Any]) -> float:
        """Estima ahorros por cambiar clase de storage"""
        size_gb = storage_item.get('size_gb', 0)
        # Diferencia entre hot y cold storage
        return size_gb * 0.05  # $0.05 por GB por mes de ahorro

    def _check_budget_limits(self, metrics: Dict[str, Any]):
        """Verifica límites de presupuesto"""
        for provider_name, provider_metrics in metrics.items():
            cost_metrics = provider_metrics.get('cost_metrics', {})
            current_cost = cost_metrics.get('total_cost', 0)
            budget_limit = self.budget_limits.get(provider_name, float('inf'))

            if current_cost > budget_limit * 0.9:  # 90% del límite
                logger.warning(f"Presupuesto casi agotado para {provider_name}: ${current_cost:.2f} de ${budget_limit}")

                # Crear alerta de presupuesto
                monitor._create_alert(
                    'budget_limit_approaching',
                    f"Budget limit approaching for {provider_name}: ${current_cost:.2f} of ${budget_limit}",
                    'warning',
                    provider_metrics
                )

    def _days_since_creation(self, resource: Dict[str, Any]) -> int:
        """Calcula días desde creación"""
        # Implementación simplificada
        return 0

    def _days_since_last_access(self, resource: Dict[str, Any]) -> int:
        """Calcula días desde último acceso"""
        # Implementación simplificada
        return 0

    def get_optimization_recommendations(self) -> List[Dict[str, Any]]:
        """Obtiene recomendaciones de optimización actuales"""
        # Retornar las optimizaciones más recientes
        if self.optimization_history:
            return self.optimization_history[-1]['optimizations']
        return []

    def get_cost_savings_summary(self) -> Dict[str, Any]:
        """Obtiene resumen de ahorros de costo"""
        total_savings = sum(entry.get('total_savings', 0) for entry in self.optimization_history)

        return {
            'total_estimated_savings': total_savings,
            'optimization_cycles': len(self.optimization_history),
            'recommendations_count': len(self.get_optimization_recommendations()),
            'budget_limits': self.budget_limits
        }

# Instancia global del optimizador
cost_optimizer = CostOptimizer()