try:
    from azure.identity import DefaultAzureCredential
    from azure.mgmt.compute import ComputeManagementClient
    from azure.mgmt.storage import StorageManagementClient
    from azure.mgmt.network import NetworkManagementClient
    from azure.mgmt.costmanagement import CostManagementClient
    from azure.mgmt.resource import ResourceManagementClient
except ImportError:
    DefaultAzureCredential = None
    ComputeManagementClient = None
    StorageManagementClient = None
    NetworkManagementClient = None
    CostManagementClient = None
    ResourceManagementClient = None

from typing import List, Dict, Any
from ..unified_manager import CloudProvider
import logging

logger = logging.getLogger(__name__)

class AzureProvider(CloudProvider):
    """Proveedor para Microsoft Azure"""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.subscription_id = config.get('subscription_id')
        self.credential = None
        self.compute_client = None
        self.storage_client = None
        self.network_client = None
        self.cost_client = None
        self._initialize_clients()

    def _initialize_clients(self):
        """Inicializa clientes de Azure"""
        if DefaultAzureCredential is None:
            logger.warning("Azure SDK no está disponible. Las operaciones de Azure estarán deshabilitadas.")
            return

        try:
            self.credential = DefaultAzureCredential()

            if self.subscription_id:
                self.compute_client = ComputeManagementClient(self.credential, self.subscription_id)
                self.storage_client = StorageManagementClient(self.credential, self.subscription_id)
                self.network_client = NetworkManagementClient(self.credential, self.subscription_id)
                self.cost_client = CostManagementClient(self.credential, self.subscription_id)

        except Exception as e:
            logger.error(f"Error inicializando clientes Azure: {e}")
            raise

    def create_vm(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea máquina virtual en Azure"""
        if ComputeManagementClient is None or ResourceManagementClient is None:
            logger.error("Azure SDK no disponible para crear VM")
            return {'error': 'Azure SDK no disponible', 'provider': 'azure'}

        try:
            resource_group = kwargs.get('resource_group', 'webmin-multicloud-rg')
            location = kwargs.get('location', 'East US')

            # Crear grupo de recursos si no existe
            resource_client = ResourceManagementClient(self.credential, self.subscription_id)
            resource_client.resource_groups.create_or_update(
                resource_group,
                {'location': location}
            )

            # Parámetros de VM
            vm_parameters = {
                'location': location,
                'hardware_profile': {
                    'vm_size': kwargs.get('vm_size', 'Standard_DS1_v2')
                },
                'storage_profile': {
                    'image_reference': {
                        'publisher': 'Canonical',
                        'offer': 'Ubuntu2204',
                        'sku': '22_04-lts-gen2',
                        'version': 'latest'
                    },
                    'os_disk': {
                        'create_option': 'FromImage',
                        'name': f'{name}-osdisk'
                    }
                },
                'os_profile': {
                    'computer_name': name,
                    'admin_username': kwargs.get('admin_username', 'azureuser'),
                    'admin_password': kwargs.get('admin_password', 'P@ssw0rd123!')
                },
                'network_profile': {
                    'network_interfaces': []
                },
                'tags': {
                    'ManagedBy': 'Webmin-MultiCloud'
                }
            }

            # Crear VM
            async_vm_creation = self.compute_client.virtual_machines.begin_create_or_update(
                resource_group, name, vm_parameters
            )
            vm_result = async_vm_creation.result()

            return {
                'id': vm_result.id,
                'name': name,
                'provider': 'azure',
                'status': 'creating',
                'vm_size': vm_result.hardware_profile.vm_size,
                'location': vm_result.location,
                'resource_group': resource_group
            }

        except Exception as e:
            logger.error(f"Error creando VM en Azure: {e}")
            raise

    def list_vms(self) -> List[Dict[str, Any]]:
        """Lista máquinas virtuales en Azure"""
        if ComputeManagementClient is None:
            logger.error("Azure SDK no disponible para listar VMs")
            return []

        try:
            vms = []
            for vm in self.compute_client.virtual_machines.list_all():
                vms.append({
                    'id': vm.id,
                    'name': vm.name,
                    'provider': 'azure',
                    'status': 'running',  # Simplificado
                    'vm_size': vm.hardware_profile.vm_size if vm.hardware_profile else 'Unknown',
                    'location': vm.location,
                    'resource_group': vm.id.split('/')[4] if '/' in vm.id else 'Unknown'
                })
            return vms

        except Exception as e:
            logger.error(f"Error listando VMs en Azure: {e}")
            return []

    def delete_vm(self, vm_id: str) -> bool:
        """Elimina máquina virtual en Azure"""
        if ComputeManagementClient is None:
            logger.error("Azure SDK no disponible para eliminar VM")
            return False

        try:
            # Extraer resource group y nombre de VM del ID
            parts = vm_id.split('/')
            if len(parts) >= 9:
                resource_group = parts[4]
                vm_name = parts[8]
                async_delete = self.compute_client.virtual_machines.begin_delete(resource_group, vm_name)
                async_delete.wait()
                return True
            return False

        except Exception as e:
            logger.error(f"Error eliminando VM {vm_id} en Azure: {e}")
            return False

    def create_storage(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        """Crea cuenta de almacenamiento o disco en Azure"""
        if StorageManagementClient is None or ComputeManagementClient is None:
            logger.error("Azure SDK no disponible para crear almacenamiento")
            return {'error': 'Azure SDK no disponible', 'provider': 'azure'}

        storage_type = kwargs.get('storage_type', 'storage_account')

        if storage_type == 'storage_account':
            return self._create_storage_account(name, **kwargs)
        elif storage_type == 'disk':
            return self._create_managed_disk(name, size_gb, **kwargs)
        else:
            raise ValueError(f"Tipo de almacenamiento {storage_type} no soportado")

    def _create_storage_account(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea cuenta de almacenamiento"""
        try:
            resource_group = kwargs.get('resource_group', 'webmin-multicloud-rg')
            location = kwargs.get('location', 'East US')

            # Nombre único para storage account
            storage_name = f"{name.lower().replace('_', '')}storage"

            storage_params = {
                'location': location,
                'sku': {'name': 'Standard_LRS'},
                'kind': 'StorageV2',
                'tags': {'ManagedBy': 'Webmin-MultiCloud'}
            }

            async_create = self.storage_client.storage_accounts.begin_create(
                resource_group, storage_name, storage_params
            )
            storage_result = async_create.result()

            return {
                'id': storage_result.id,
                'name': name,
                'provider': 'azure',
                'type': 'storage_account',
                'location': storage_result.location,
                'size_gb': None  # Storage accounts no tienen límite fijo
            }

        except Exception as e:
            logger.error(f"Error creando storage account en Azure: {e}")
            raise

    def _create_managed_disk(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        """Crea disco administrado"""
        try:
            resource_group = kwargs.get('resource_group', 'webmin-multicloud-rg')
            location = kwargs.get('location', 'East US')

            disk_params = {
                'location': location,
                'disk_size_gb': size_gb,
                'creation_data': {
                    'create_option': 'Empty'
                },
                'tags': {'ManagedBy': 'Webmin-MultiCloud'}
            }

            async_create = self.compute_client.disks.begin_create_or_update(
                resource_group, name, disk_params
            )
            disk_result = async_create.result()

            return {
                'id': disk_result.id,
                'name': name,
                'provider': 'azure',
                'type': 'managed_disk',
                'size_gb': disk_result.disk_size_gb,
                'status': 'attached' if disk_result.disk_state == 'Attached' else 'unattached'
            }

        except Exception as e:
            logger.error(f"Error creando managed disk en Azure: {e}")
            raise

    def list_storage(self) -> List[Dict[str, Any]]:
        """Lista cuentas de almacenamiento y discos"""
        if StorageManagementClient is None or ComputeManagementClient is None:
            logger.error("Azure SDK no disponible para listar almacenamiento")
            return []

        storage = []

        # Listar storage accounts
        try:
            for account in self.storage_client.storage_accounts.list():
                storage.append({
                    'id': account.id,
                    'name': account.name,
                    'provider': 'azure',
                    'type': 'storage_account',
                    'location': account.location,
                    'kind': account.kind
                })
        except Exception as e:
            logger.error(f"Error listando storage accounts en Azure: {e}")

        # Listar managed disks
        try:
            for disk in self.compute_client.disks.list():
                storage.append({
                    'id': disk.id,
                    'name': disk.name,
                    'provider': 'azure',
                    'type': 'managed_disk',
                    'size_gb': disk.disk_size_gb,
                    'status': disk.disk_state
                })
        except Exception as e:
            logger.error(f"Error listando managed disks en Azure: {e}")

        return storage

    def create_load_balancer(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea Load Balancer en Azure"""
        if NetworkManagementClient is None:
            logger.error("Azure SDK no disponible para crear load balancer")
            return {'error': 'Azure SDK no disponible', 'provider': 'azure'}

        try:
            resource_group = kwargs.get('resource_group', 'webmin-multicloud-rg')
            location = kwargs.get('location', 'East US')

            lb_params = {
                'location': location,
                'frontend_ip_configurations': [{
                    'name': f'{name}-frontend',
                    'public_ip_address': {
                        'id': kwargs.get('public_ip_id')
                    }
                }],
                'backend_address_pools': [{
                    'name': f'{name}-backend'
                }],
                'load_balancing_rules': [{
                    'name': f'{name}-rule',
                    'protocol': 'Tcp',
                    'frontend_port': 80,
                    'backend_port': 80,
                    'frontend_ip_configuration': {
                        'id': f'/subscriptions/{self.subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.Network/loadBalancers/{name}/frontendIPConfigurations/{name}-frontend'
                    },
                    'backend_address_pool': {
                        'id': f'/subscriptions/{self.subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.Network/loadBalancers/{name}/backendAddressPools/{name}-backend'
                    }
                }],
                'tags': {'ManagedBy': 'Webmin-MultiCloud'}
            }

            async_create = self.network_client.load_balancers.begin_create_or_update(
                resource_group, name, lb_params
            )
            lb_result = async_create.result()

            return {
                'id': lb_result.id,
                'name': name,
                'provider': 'azure',
                'type': 'load_balancer',
                'location': lb_result.location,
                'status': 'active'
            }

        except Exception as e:
            logger.error(f"Error creando load balancer en Azure: {e}")
            raise

    def get_costs(self) -> Dict[str, Any]:
        """Obtiene costos usando Cost Management"""
        if CostManagementClient is None:
            logger.error("Azure SDK no disponible para obtener costos")
            return {'total': 0, 'error': 'Azure SDK no disponible'}

        try:
            import datetime
            end_date = datetime.date.today()
            start_date = end_date - datetime.timedelta(days=30)

            # Consulta de costos
            scope = f'/subscriptions/{self.subscription_id}'
            cost_params = {
                'type': 'ActualCost',
                'timeframe': 'Custom',
                'time_period': {
                    'from_property': start_date.isoformat(),
                    'to': end_date.isoformat()
                },
                'dataset': {
                    'granularity': 'Monthly',
                    'aggregation': {
                        'totalCost': {
                            'name': 'Cost',
                            'function': 'Sum'
                        }
                    }
                }
            }

            cost_result = self.cost_client.query.usage(scope, cost_params)

            total_cost = 0
            if cost_result.rows:
                total_cost = float(cost_result.rows[0][0]) if cost_result.rows[0][0] else 0

            return {
                'total': total_cost,
                'currency': 'USD',
                'period': f"{start_date} to {end_date}",
                'breakdown': {}
            }

        except Exception as e:
            logger.error(f"Error obteniendo costos de Azure: {e}")
            return {'total': 0, 'error': str(e)}