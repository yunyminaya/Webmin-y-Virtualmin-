from google.cloud import compute_v1, storage, billing_v1
from google.oauth2 import service_account
from typing import List, Dict, Any
from ..unified_manager import CloudProvider
import logging
import os

logger = logging.getLogger(__name__)

class GCPProvider(CloudProvider):
    """Proveedor para Google Cloud Platform"""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.project_id = config.get('project_id')
        self.credentials_file = config.get('credentials_file')

        self.compute_client = None
        self.storage_client = None
        self.billing_client = None
        self._initialize_clients()

    def _initialize_clients(self):
        """Inicializa clientes de GCP"""
        try:
            credentials = None
            if self.credentials_file and os.path.exists(self.credentials_file):
                credentials = service_account.Credentials.from_service_account_file(
                    self.credentials_file
                )

            if self.project_id:
                self.compute_client = compute_v1.InstancesClient(credentials=credentials)
                self.storage_client = storage.Client(project=self.project_id, credentials=credentials)
                self.billing_client = billing_v1.CloudBillingClient(credentials=credentials)

        except Exception as e:
            logger.error(f"Error inicializando clientes GCP: {e}")
            raise

    def create_vm(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea instancia de Compute Engine"""
        try:
            zone = kwargs.get('zone', 'us-central1-a')

            # Configuración de instancia
            instance = compute_v1.Instance()
            instance.name = name
            instance.machine_type = f"zones/{zone}/machineTypes/{kwargs.get('machine_type', 'n1-standard-1')}"

            # Disco de arranque
            boot_disk = compute_v1.AttachedDisk()
            boot_disk.auto_delete = True
            boot_disk.boot = True
            boot_disk.initialize_params = compute_v1.AttachedDiskInitializeParams()
            boot_disk.initialize_params.source_image = kwargs.get(
                'source_image',
                "projects/debian-cloud/global/images/family/debian-11"
            )
            boot_disk.initialize_params.disk_size_gb = kwargs.get('disk_size_gb', 10)
            instance.disks = [boot_disk]

            # Red
            network_interface = compute_v1.NetworkInterface()
            network_interface.name = 'default'
            instance.network_interfaces = [network_interface]

            # Metadata
            instance.labels = {'managed_by': 'webmin-multicloud'}

            # Crear instancia
            operation = self.compute_client.insert(
                project=self.project_id,
                zone=zone,
                instance_resource=instance
            )

            # Esperar a que se complete (simplificado)
            operation.result()

            return {
                'id': f"projects/{self.project_id}/zones/{zone}/instances/{name}",
                'name': name,
                'provider': 'gcp',
                'status': 'running',
                'machine_type': kwargs.get('machine_type', 'n1-standard-1'),
                'zone': zone
            }

        except Exception as e:
            logger.error(f"Error creando VM en GCP: {e}")
            raise

    def list_vms(self) -> List[Dict[str, Any]]:
        """Lista instancias de Compute Engine"""
        try:
            instances = []
            request = compute_v1.AggregatedListInstancesRequest()
            request.project = self.project_id

            for zone, response in self.compute_client.aggregated_list(request=request):
                for instance in response.instances:
                    instances.append({
                        'id': instance.self_link,
                        'name': instance.name,
                        'provider': 'gcp',
                        'status': instance.status.lower(),
                        'machine_type': instance.machine_type.split('/')[-1],
                        'zone': zone.split('/')[-1],
                        'public_ip': None,  # Simplificado
                        'private_ip': None
                    })

            return instances

        except Exception as e:
            logger.error(f"Error listando VMs en GCP: {e}")
            return []

    def delete_vm(self, vm_id: str) -> bool:
        """Elimina instancia de Compute Engine"""
        try:
            # Extraer zone y nombre de instancia del ID
            parts = vm_id.split('/')
            if len(parts) >= 10:
                zone = parts[7]
                instance_name = parts[9]

                operation = self.compute_client.delete(
                    project=self.project_id,
                    zone=zone,
                    instance=instance_name
                )
                operation.result()
                return True
            return False

        except Exception as e:
            logger.error(f"Error eliminando VM {vm_id} en GCP: {e}")
            return False

    def create_storage(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        """Crea bucket de Cloud Storage o disco persistente"""
        storage_type = kwargs.get('storage_type', 'bucket')

        if storage_type == 'bucket':
            return self._create_bucket(name, **kwargs)
        elif storage_type == 'disk':
            return self._create_persistent_disk(name, size_gb, **kwargs)
        else:
            raise ValueError(f"Tipo de almacenamiento {storage_type} no soportado")

    def _create_bucket(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea bucket de Cloud Storage"""
        try:
            # Nombre único para bucket
            bucket_name = f"{name.lower().replace('_', '-')}-{self.project_id}"

            bucket = self.storage_client.bucket(bucket_name)
            bucket.location = kwargs.get('location', 'US')
            bucket.create()

            return {
                'id': bucket_name,
                'name': name,
                'provider': 'gcp',
                'type': 'bucket',
                'location': bucket.location,
                'size_gb': None  # Buckets no tienen límite fijo
            }

        except Exception as e:
            logger.error(f"Error creando bucket en GCP: {e}")
            raise

    def _create_persistent_disk(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        """Crea disco persistente"""
        try:
            zone = kwargs.get('zone', 'us-central1-a')

            disk = compute_v1.Disk()
            disk.name = name
            disk.size_gb = size_gb
            disk.type_ = f"zones/{zone}/diskTypes/pd-standard"

            operation = self.compute_client.disks.insert(
                project=self.project_id,
                zone=zone,
                disk_resource=disk
            )
            operation.result()

            return {
                'id': f"projects/{self.project_id}/zones/{zone}/disks/{name}",
                'name': name,
                'provider': 'gcp',
                'type': 'persistent_disk',
                'size_gb': size_gb,
                'status': 'ready'
            }

        except Exception as e:
            logger.error(f"Error creando persistent disk en GCP: {e}")
            raise

    def list_storage(self) -> List[Dict[str, Any]]:
        """Lista buckets y discos persistentes"""
        storage = []

        # Listar buckets
        try:
            buckets = self.storage_client.list_buckets()
            for bucket in buckets:
                storage.append({
                    'id': bucket.name,
                    'name': bucket.name,
                    'provider': 'gcp',
                    'type': 'bucket',
                    'location': bucket.location,
                    'created': bucket.time_created.isoformat() if bucket.time_created else None
                })
        except Exception as e:
            logger.error(f"Error listando buckets en GCP: {e}")

        # Listar persistent disks
        try:
            request = compute_v1.AggregatedListDisksRequest()
            request.project = self.project_id

            for zone, response in self.compute_client.aggregated_list_disks(request=request):
                for disk in response.disks:
                    storage.append({
                        'id': disk.self_link,
                        'name': disk.name,
                        'provider': 'gcp',
                        'type': 'persistent_disk',
                        'size_gb': disk.size_gb,
                        'status': disk.status.lower()
                    })
        except Exception as e:
            logger.error(f"Error listando persistent disks en GCP: {e}")

        return storage

    def create_load_balancer(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea Load Balancer en GCP"""
        try:
            region = kwargs.get('region', 'us-central1')

            # Crear backend service
            backend_service = compute_v1.BackendService()
            backend_service.name = f"{name}-backend"
            backend_service.load_balancing_scheme = 'EXTERNAL'

            backend_operation = self.compute_client.backend_services.insert(
                project=self.project_id,
                backend_service_resource=backend_service
            )
            backend_operation.result()

            # Crear target HTTP proxy
            target_proxy = compute_v1.TargetHttpProxy()
            target_proxy.name = f"{name}-proxy"
            target_proxy.url_map = f"projects/{self.project_id}/global/urlMaps/{name}-urlmap"

            proxy_operation = self.compute_client.target_http_proxies.insert(
                project=self.project_id,
                target_http_proxy_resource=target_proxy
            )
            proxy_operation.result()

            # Crear forwarding rule
            forwarding_rule = compute_v1.ForwardingRule()
            forwarding_rule.name = name
            forwarding_rule.target = f"projects/{self.project_id}/global/targetHttpProxies/{name}-proxy"
            forwarding_rule.ip_protocol = 'TCP'
            forwarding_rule.port_range = '80'

            rule_operation = self.compute_client.global_forwarding_rules.insert(
                project=self.project_id,
                forwarding_rule_resource=forwarding_rule
            )
            rule_result = rule_operation.result()

            return {
                'id': rule_result.self_link,
                'name': name,
                'provider': 'gcp',
                'type': 'load_balancer',
                'ip_address': rule_result.i_p_address,
                'status': 'active'
            }

        except Exception as e:
            logger.error(f"Error creando load balancer en GCP: {e}")
            raise

    def get_costs(self) -> Dict[str, Any]:
        """Obtiene costos usando Cloud Billing"""
        try:
            import datetime
            end_date = datetime.date.today()
            start_date = end_date - datetime.timedelta(days=30)

            # Consulta de costos (simplificada)
            # Nota: La API de billing es compleja y requiere configuración adicional
            # Esta es una implementación básica

            return {
                'total': 0,  # Implementar consulta real de costos
                'currency': 'USD',
                'period': f"{start_date} to {end_date}",
                'breakdown': {},
                'note': 'Cost tracking requires additional billing API setup'
            }

        except Exception as e:
            logger.error(f"Error obteniendo costos de GCP: {e}")
            return {'total': 0, 'error': str(e)}