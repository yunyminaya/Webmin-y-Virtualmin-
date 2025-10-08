from typing import List, Dict, Any, Optional
from abc import ABC, abstractmethod
import logging
from .config import config
from .providers.aws_provider import AWSProvider
from .providers.azure_provider import AzureProvider
from .providers.gcp_provider import GCPProvider

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class CloudProvider(ABC):
    """Interfaz abstracta para proveedores de nube"""

    @abstractmethod
    def create_vm(self, name: str, **kwargs) -> Dict[str, Any]:
        pass

    @abstractmethod
    def list_vms(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def delete_vm(self, vm_id: str) -> bool:
        pass

    @abstractmethod
    def create_storage(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        pass

    @abstractmethod
    def list_storage(self) -> List[Dict[str, Any]]:
        pass

    @abstractmethod
    def create_load_balancer(self, name: str, **kwargs) -> Dict[str, Any]:
        pass

    @abstractmethod
    def get_costs(self) -> Dict[str, Any]:
        pass

class MultiCloudManager:
    """Gestor unificado para múltiples proveedores de nube"""

    def __init__(self):
        self.providers = {
            'aws': AWSProvider(config.get_provider_config('aws')),
            'azure': AzureProvider(config.get_provider_config('azure')),
            'gcp': GCPProvider(config.get_provider_config('gcp'))
        }
        self.general_config = config.get_general_config()

    def get_provider(self, provider_name: str) -> CloudProvider:
        """Obtiene instancia de proveedor específico"""
        if provider_name not in self.providers:
            raise ValueError(f"Proveedor {provider_name} no soportado")
        return self.providers[provider_name]

    def create_vm_multi_cloud(self, provider: str, name: str, **kwargs) -> Dict[str, Any]:
        """Crea VM en proveedor específico"""
        provider_instance = self.get_provider(provider)
        return provider_instance.create_vm(name, **kwargs)

    def list_vms_all_providers(self) -> Dict[str, List[Dict[str, Any]]]:
        """Lista VMs en todos los proveedores"""
        result = {}
        for name, provider in self.providers.items():
            try:
                result[name] = provider.list_vms()
            except Exception as e:
                logger.error(f"Error listando VMs en {name}: {e}")
                result[name] = []
        return result

    def migrate_vm(self, source_provider: str, target_provider: str, vm_id: str, **kwargs) -> Dict[str, Any]:
        """Migra VM entre proveedores"""
        # Implementación básica - en producción necesitaría más lógica
        logger.info(f"Migrando VM {vm_id} de {source_provider} a {target_provider}")
        # Obtener datos de VM fuente
        source = self.get_provider(source_provider)
        vm_data = source.list_vms()
        vm_info = next((vm for vm in vm_data if vm['id'] == vm_id), None)

        if not vm_info:
            raise ValueError(f"VM {vm_id} no encontrada en {source_provider}")

        # Crear VM en destino
        target = self.get_provider(target_provider)
        new_vm = target.create_vm(f"migrated-{vm_info['name']}", **kwargs)

        return {
            'source_vm': vm_info,
            'target_vm': new_vm,
            'migration_status': 'completed'
        }

    def create_cross_cloud_backup(self, data: Dict[str, Any], providers: List[str] = None) -> Dict[str, Any]:
        """Crea backup replicado en múltiples proveedores"""
        if providers is None:
            providers = list(self.providers.keys())

        backups = {}
        for provider_name in providers:
            try:
                provider = self.get_provider(provider_name)
                backup = provider.create_storage(f"backup-{data['name']}", data['size_gb'])
                backups[provider_name] = backup
            except Exception as e:
                logger.error(f"Error creando backup en {provider_name}: {e}")

        return {
            'original_data': data,
            'backups': backups,
            'replication_status': 'completed' if backups else 'failed'
        }

    def get_unified_costs(self) -> Dict[str, Any]:
        """Obtiene costos unificados de todos los proveedores"""
        costs = {}
        total_cost = 0

        for name, provider in self.providers.items():
            try:
                provider_costs = provider.get_costs()
                costs[name] = provider_costs
                total_cost += provider_costs.get('total', 0)
            except Exception as e:
                logger.error(f"Error obteniendo costos de {name}: {e}")
                costs[name] = {'error': str(e)}

        return {
            'provider_costs': costs,
            'total_cost': total_cost,
            'optimization_suggestions': self._generate_cost_optimization_suggestions(costs)
        }

    def _generate_cost_optimization_suggestions(self, costs: Dict[str, Any]) -> List[str]:
        """Genera sugerencias de optimización de costos"""
        suggestions = []

        # Lógica básica de optimización
        threshold = self.general_config.get('cost_optimization_threshold', 0.8)

        for provider, cost_data in costs.items():
            if 'total' in cost_data:
                # Sugerencias basadas en umbrales
                if cost_data['total'] > threshold * 1000:  # Ejemplo arbitrario
                    suggestions.append(f"Considerar migrar cargas de trabajo de {provider} para reducir costos")

        return suggestions

    def create_global_load_balancer(self, name: str, backends: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Crea balanceador de carga global con backends en múltiples proveedores"""
        load_balancers = {}

        for backend in backends:
            provider_name = backend['provider']
            provider = self.get_provider(provider_name)
            lb = provider.create_load_balancer(f"{name}-{provider_name}", **backend)
            load_balancers[provider_name] = lb

        return {
            'name': name,
            'load_balancers': load_balancers,
            'global_config': {
                'health_checks': True,
                'failover_enabled': True,
                'geo_routing': True
            }
        }

# Instancia global del gestor
manager = MultiCloudManager()