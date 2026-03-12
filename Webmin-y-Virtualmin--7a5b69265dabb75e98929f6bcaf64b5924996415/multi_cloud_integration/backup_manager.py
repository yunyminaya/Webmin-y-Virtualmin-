from typing import List, Dict, Any, Optional
from .unified_manager import manager
import logging
import time
import schedule
import threading

logger = logging.getLogger(__name__)

class CrossCloudBackup:
    """Sistema de backup cross-cloud con replicación automática"""

    def __init__(self, name: str, source_data: Dict[str, Any], target_providers: List[str]):
        self.name = name
        self.source_data = source_data
        self.target_providers = target_providers
        self.backups = {}
        self.backup_schedule = None
        self.retention_days = 30
        self.replication_factor = len(target_providers)
        self.last_backup = None
        self.backup_status = 'initialized'

    def create_initial_backup(self) -> Dict[str, Any]:
        """Crea el backup inicial en todos los proveedores objetivo"""
        logger.info(f"Creando backup inicial para {self.name}")

        self.backup_status = 'creating'
        success_count = 0

        for provider in self.target_providers:
            try:
                backup = manager.create_cross_cloud_backup(self.source_data, [provider])
                if backup['replication_status'] == 'completed':
                    self.backups[provider] = backup
                    success_count += 1
                else:
                    logger.error(f"Backup fallido en {provider}")

            except Exception as e:
                logger.error(f"Error creando backup en {provider}: {e}")

        self.last_backup = time.time()
        self.backup_status = 'completed' if success_count > 0 else 'failed'

        return {
            'backup_name': self.name,
            'total_providers': len(self.target_providers),
            'successful_backups': success_count,
            'status': self.backup_status,
            'backups': self.backups
        }

    def schedule_automatic_backup(self, interval_hours: int = 24):
        """Programa backups automáticos"""
        def backup_job():
            self.create_incremental_backup()

        if self.backup_schedule:
            schedule.cancel_job(self.backup_schedule)

        self.backup_schedule = schedule.every(interval_hours).hours.do(backup_job)
        logger.info(f"Backup automático programado cada {interval_hours} horas")

    def create_incremental_backup(self) -> Dict[str, Any]:
        """Crea backup incremental"""
        logger.info(f"Creando backup incremental para {self.name}")

        # Verificar cambios desde el último backup
        if not self._has_changes_since_last_backup():
            logger.info("No hay cambios detectados, omitiendo backup incremental")
            return {'status': 'skipped', 'reason': 'no_changes'}

        # Crear nuevo backup
        result = self.create_initial_backup()

        # Limpiar backups antiguos según política de retención
        self._cleanup_old_backups()

        return result

    def _has_changes_since_last_backup(self) -> bool:
        """Verifica si hay cambios desde el último backup"""
        if not self.last_backup:
            return True

        # En implementación real, esto compararía hashes, timestamps, etc.
        # Por simplicidad, siempre retorna True
        return True

    def _cleanup_old_backups(self):
        """Limpia backups antiguos según política de retención"""
        cutoff_time = time.time() - (self.retention_days * 24 * 60 * 60)

        # En implementación real, esto eliminaría backups más antiguos que cutoff_time
        logger.info(f"Limpiando backups anteriores a {time.ctime(cutoff_time)}")

    def restore_from_backup(self, provider: str, target_location: Dict[str, Any]) -> Dict[str, Any]:
        """Restaura desde un backup específico"""
        if provider not in self.backups:
            raise ValueError(f"No hay backup disponible para {provider}")

        backup = self.backups[provider]

        try:
            # Lógica de restauración (simplificada)
            restored_data = {
                'original_backup': backup,
                'target_location': target_location,
                'restoration_status': 'completed',
                'restored_at': time.time()
            }

            logger.info(f"Restauración completada desde backup en {provider}")
            return restored_data

        except Exception as e:
            logger.error(f"Error en restauración: {e}")
            return {
                'restoration_status': 'failed',
                'error': str(e)
            }

    def get_backup_status(self) -> Dict[str, Any]:
        """Obtiene el estado actual del backup"""
        return {
            'name': self.name,
            'status': self.backup_status,
            'last_backup': self.last_backup,
            'next_backup': self._get_next_backup_time(),
            'replication_factor': self.replication_factor,
            'providers': list(self.backups.keys()),
            'retention_days': self.retention_days,
            'total_backups': len(self.backups)
        }

    def _get_next_backup_time(self) -> Optional[float]:
        """Obtiene el tiempo del próximo backup programado"""
        if self.backup_schedule:
            # En implementación real, calcular desde schedule
            return self.last_backup + (24 * 60 * 60) if self.last_backup else None
        return None

    def update_retention_policy(self, days: int):
        """Actualiza la política de retención"""
        self.retention_days = days
        logger.info(f"Política de retención actualizada a {days} días")

class BackupManager:
    """Gestor de backups cross-cloud"""

    def __init__(self):
        self.backups = {}
        self.scheduler_thread = None
        self.running = False

    def create_backup_system(self, name: str, source_data: Dict[str, Any],
                           target_providers: List[str]) -> CrossCloudBackup:
        """Crea un nuevo sistema de backup cross-cloud"""
        backup = CrossCloudBackup(name, source_data, target_providers)
        self.backups[name] = backup

        # Crear backup inicial
        initial_result = backup.create_initial_backup()

        # Programar backups automáticos
        backup.schedule_automatic_backup()

        return backup

    def get_backup(self, name: str) -> Optional[CrossCloudBackup]:
        """Obtiene un sistema de backup por nombre"""
        return self.backups.get(name)

    def list_backups(self) -> List[str]:
        """Lista todos los sistemas de backup"""
        return list(self.backups.keys())

    def start_scheduler(self):
        """Inicia el programador de backups"""
        if self.running:
            return

        self.running = True
        self.scheduler_thread = threading.Thread(target=self._scheduler_loop)
        self.scheduler_thread.daemon = True
        self.scheduler_thread.start()
        logger.info("Programador de backups iniciado")

    def stop_scheduler(self):
        """Detiene el programador de backups"""
        self.running = False
        if self.scheduler_thread:
            self.scheduler_thread.join()
        logger.info("Programador de backups detenido")

    def _scheduler_loop(self):
        """Loop del programador"""
        while self.running:
            try:
                schedule.run_pending()
                time.sleep(60)  # Verificar cada minuto
            except Exception as e:
                logger.error(f"Error en scheduler loop: {e}")
                time.sleep(60)

    def get_global_backup_status(self) -> Dict[str, Any]:
        """Obtiene el estado global de todos los backups"""
        total_backups = len(self.backups)
        healthy_backups = sum(1 for b in self.backups.values() if b.backup_status == 'completed')
        failed_backups = sum(1 for b in self.backups.values() if b.backup_status == 'failed')

        return {
            'total_backup_systems': total_backups,
            'healthy_backups': healthy_backups,
            'failed_backups': failed_backups,
            'scheduler_running': self.running,
            'backup_systems': [
                {
                    'name': name,
                    'status': backup.backup_status,
                    'last_backup': backup.last_backup,
                    'providers': list(backup.backups.keys())
                }
                for name, backup in self.backups.items()
            ]
        }

    def emergency_restore(self, backup_name: str, provider: str,
                         target_location: Dict[str, Any]) -> Dict[str, Any]:
        """Realiza una restauración de emergencia"""
        backup = self.get_backup(backup_name)
        if not backup:
            raise ValueError(f"Backup {backup_name} no encontrado")

        logger.warning(f"Iniciando restauración de emergencia para {backup_name}")

        # Detener scheduler temporalmente
        scheduler_was_running = self.running
        if scheduler_was_running:
            self.stop_scheduler()

        try:
            result = backup.restore_from_backup(provider, target_location)
            result['emergency'] = True
            return result

        finally:
            # Reiniciar scheduler si estaba corriendo
            if scheduler_was_running:
                self.start_scheduler()

# Instancia global del gestor de backups
backup_manager = BackupManager()