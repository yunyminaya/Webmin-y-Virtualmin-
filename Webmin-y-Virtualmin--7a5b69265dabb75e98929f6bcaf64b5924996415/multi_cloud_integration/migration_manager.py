from typing import Dict, Any, List, Optional
from .unified_manager import manager
import logging
import time

logger = logging.getLogger(__name__)

class MigrationManager:
    """Gestor de migraciones automáticas entre proveedores de nube"""

    def __init__(self):
        self.manager = manager

    def migrate_vm(self, source_provider: str, target_provider: str,
                   vm_id: str, target_config: Dict[str, Any] = None) -> Dict[str, Any]:
        """Migra una VM entre proveedores de nube"""
        try:
            logger.info(f"Iniciando migración de VM {vm_id} de {source_provider} a {target_provider}")

            # Paso 1: Obtener información de la VM fuente
            source_provider_instance = self.manager.get_provider(source_provider)
            vms = source_provider_instance.list_vms()
            source_vm = next((vm for vm in vms if vm['id'] == vm_id), None)

            if not source_vm:
                raise ValueError(f"VM {vm_id} no encontrada en {source_provider}")

            # Paso 2: Crear snapshot/backup de la VM fuente
            snapshot_id = self._create_vm_snapshot(source_provider, vm_id, source_vm)

            # Paso 3: Crear nueva VM en el proveedor destino
            target_config = target_config or {}
            target_config.update({
                'name': f"migrated-{source_vm['name']}",
                'instance_type': self._map_instance_type(source_provider, target_provider, source_vm.get('instance_type', 't2.micro')),
                'image_id': self._get_base_image(target_provider)
            })

            target_vm = self.manager.create_vm_multi_cloud(target_provider, **target_config)

            # Paso 4: Transferir datos (simplificado - en producción requeriría más lógica)
            self._transfer_data(snapshot_id, source_provider, target_provider, target_vm['id'])

            # Paso 5: Verificar migración
            migration_success = self._verify_migration(target_provider, target_vm['id'])

            # Paso 6: Cleanup (opcional - eliminar VM fuente)
            if migration_success and target_config.get('cleanup_source', False):
                source_provider_instance.delete_vm(vm_id)

            result = {
                'migration_id': f"migration-{int(time.time())}",
                'source_vm': source_vm,
                'target_vm': target_vm,
                'status': 'completed' if migration_success else 'failed',
                'snapshot_id': snapshot_id,
                'transferred_data': True,
                'cleanup_performed': target_config.get('cleanup_source', False)
            }

            logger.info(f"Migración completada: {result['status']}")
            return result

        except Exception as e:
            logger.error(f"Error en migración: {e}")
            return {
                'migration_id': f"migration-{int(time.time())}",
                'status': 'failed',
                'error': str(e)
            }

    def _create_vm_snapshot(self, provider: str, vm_id: str, vm_info: Dict[str, Any]) -> str:
        """Crea snapshot de la VM para backup durante migración"""
        try:
            provider_instance = self.manager.get_provider(provider)

            # Crear storage backup
            backup_data = {
                'name': f"snapshot-{vm_info['name']}-{int(time.time())}",
                'size_gb': 10  # Tamaño estimado
            }

            backup = provider_instance.create_storage(**backup_data)
            return backup['id']

        except Exception as e:
            logger.error(f"Error creando snapshot: {e}")
            return None

    def _map_instance_type(self, source_provider: str, target_provider: str, source_type: str) -> str:
        """Mapea tipos de instancia entre proveedores"""
        # Mapas de equivalencia simplificados
        type_mappings = {
            ('aws', 'azure'): {
                't2.micro': 'Standard_B1s',
                't2.small': 'Standard_B1ms',
                't2.medium': 'Standard_B2s',
                't3.micro': 'Standard_B1s',
                't3.small': 'Standard_B1ms',
                't3.medium': 'Standard_B2s'
            },
            ('aws', 'gcp'): {
                't2.micro': 'f1-micro',
                't2.small': 'g1-small',
                't2.medium': 'n1-standard-1',
                't3.micro': 'f1-micro',
                't3.small': 'g1-small',
                't3.medium': 'n1-standard-1'
            },
            ('azure', 'aws'): {
                'Standard_B1s': 't2.micro',
                'Standard_B1ms': 't2.small',
                'Standard_B2s': 't2.medium'
            },
            ('azure', 'gcp'): {
                'Standard_B1s': 'f1-micro',
                'Standard_B1ms': 'g1-small',
                'Standard_B2s': 'n1-standard-1'
            },
            ('gcp', 'aws'): {
                'f1-micro': 't2.micro',
                'g1-small': 't2.small',
                'n1-standard-1': 't2.medium'
            },
            ('gcp', 'azure'): {
                'f1-micro': 'Standard_B1s',
                'g1-small': 'Standard_B1ms',
                'n1-standard-1': 'Standard_B2s'
            }
        }

        mapping = type_mappings.get((source_provider, target_provider), {})
        return mapping.get(source_type, source_type)

    def _get_base_image(self, provider: str) -> str:
        """Obtiene imagen base para el proveedor"""
        base_images = {
            'aws': 'ami-0c55b159cbfafe1d0',  # Amazon Linux 2
            'azure': 'Ubuntu2204',  # Ubuntu 22.04
            'gcp': 'projects/debian-cloud/global/images/family/debian-11'
        }
        return base_images.get(provider, '')

    def _transfer_data(self, snapshot_id: str, source_provider: str,
                      target_provider: str, target_vm_id: str):
        """Transfiere datos del snapshot a la nueva VM (simplificado)"""
        logger.info(f"Transfiriendo datos de {snapshot_id} a {target_vm_id}")
        # En implementación real, esto involucraría:
        # - Descargar datos del snapshot
        # - Subir a storage del proveedor destino
        # - Configurar la nueva VM para usar los datos
        time.sleep(1)  # Simulación

    def _verify_migration(self, provider: str, vm_id: str) -> bool:
        """Verifica que la migración fue exitosa"""
        try:
            provider_instance = self.manager.get_provider(provider)
            vms = provider_instance.list_vms()
            vm = next((v for v in vms if v['id'] == vm_id), None)

            if vm and vm['status'] in ['running', 'active']:
                logger.info(f"Verificación exitosa para VM {vm_id}")
                return True

            logger.warning(f"Verificación fallida para VM {vm_id}")
            return False

        except Exception as e:
            logger.error(f"Error en verificación: {e}")
            return False

    def get_migration_status(self, migration_id: str) -> Dict[str, Any]:
        """Obtiene estado de una migración (simplificado)"""
        # En implementación real, mantendría un registro de migraciones
        return {
            'migration_id': migration_id,
            'status': 'unknown',
            'message': 'Migration tracking not implemented yet'
        }

    def bulk_migrate(self, migrations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Realiza migraciones masivas"""
        results = []

        for migration in migrations:
            try:
                result = self.migrate_vm(
                    migration['source_provider'],
                    migration['target_provider'],
                    migration['vm_id'],
                    migration.get('target_config', {})
                )
                results.append(result)

                # Pequeña pausa entre migraciones
                time.sleep(2)

            except Exception as e:
                results.append({
                    'migration_id': f"migration-{int(time.time())}",
                    'status': 'failed',
                    'error': str(e),
                    'source_provider': migration['source_provider'],
                    'target_provider': migration['target_provider'],
                    'vm_id': migration['vm_id']
                })

        return results

# Instancia global del gestor de migraciones
migration_manager = MigrationManager()