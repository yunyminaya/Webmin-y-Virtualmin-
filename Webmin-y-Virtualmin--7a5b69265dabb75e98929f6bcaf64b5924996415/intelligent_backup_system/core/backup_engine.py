#!/usr/bin/env python3
"""
Motor Principal del Sistema de Backup Inteligente
Coordina todas las funcionalidades: deduplicación, compresión, encriptación,
replicación, verificación e integración con monitoreo
"""

import os
import logging
import json
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# Importar módulos del sistema
from ..deduplication.deduplicator import BlockDeduplicator, DeduplicationStats
from ..compression.compressor import AdaptiveCompressor, CompressionResult
from ..encryption.encryptor import AES256Encryptor, EncryptionResult
from ..storage.storage_manager import StorageManager, ReplicationResult
from ..verification.verifier import IntegrityVerifier, VerificationResult
from ..core.incremental_backup import IncrementalBackupEngine, IncrementalBackupResult
from ..restoration.restorer import GranularRestorer, RestoreResult

@dataclass
class BackupJob:
    """Configuración de un trabajo de backup"""
    job_id: str
    name: str
    source_paths: List[str]
    destination: str
    schedule: str = "manual"
    compression: bool = True
    encryption: bool = True
    deduplication: bool = True
    replication_destinations: List[str] = None
    retention_days: int = 30
    incremental: bool = True
    verify_integrity: bool = True

    def __post_init__(self):
        if self.replication_destinations is None:
            self.replication_destinations = []

@dataclass
class BackupResult:
    """Resultado completo de un backup"""
    job_id: str
    success: bool
    start_time: datetime
    end_time: datetime
    total_files: int
    total_size: int
    compressed_size: int
    deduplication_stats: Optional[DeduplicationStats] = None
    replication_results: List[ReplicationResult] = None
    verification_result: Optional[VerificationResult] = None
    error_message: str = ""

    def __post_init__(self):
        if self.replication_results is None:
            self.replication_results = []

    @property
    def processing_time(self) -> float:
        """Tiempo total de procesamiento"""
        return (self.end_time - self.start_time).total_seconds()

    @property
    def compression_ratio(self) -> float:
        """Ratio de compresión"""
        return self.compressed_size / self.total_size if self.total_size > 0 else 1.0

class IntelligentBackupEngine:
    """
    Motor principal que coordina todas las funcionalidades del sistema
    de backup inteligente para Webmin/Virtualmin
    """

    def __init__(self, config_dir: str = None):
        """
        Inicializar el motor de backup inteligente

        Args:
            config_dir: Directorio de configuración
        """
        self.config_dir = Path(config_dir or os.path.join(os.getcwd(), 'config'))
        self.config_dir.mkdir(parents=True, exist_ok=True)

        # Configurar logging
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.INFO)

        # Inicializar componentes
        self.deduplicator = BlockDeduplicator()
        self.compressor = AdaptiveCompressor()
        self.encryptor = AES256Encryptor()
        self.storage_manager = StorageManager()
        self.verifier = IntegrityVerifier()
        self.incremental_engine = IncrementalBackupEngine()
        self.restorer = GranularRestorer(str(self.config_dir.parent / 'backups'))

        # Cargar configuración
        self.jobs: Dict[str, BackupJob] = {}
        self._load_config()

    def _load_config(self):
        """Cargar configuración de trabajos"""
        config_file = self.config_dir / 'backup_jobs.json'
        if config_file.exists():
            try:
                with open(config_file, 'r') as f:
                    jobs_data = json.load(f)
                    for job_data in jobs_data:
                        job = BackupJob(**job_data)
                        self.jobs[job.job_id] = job
                self.logger.info(f"Configuración cargada: {len(self.jobs)} trabajos")
            except Exception as e:
                self.logger.error(f"Error cargando configuración: {e}")

    def _save_config(self):
        """Guardar configuración de trabajos"""
        config_file = self.config_dir / 'backup_jobs.json'
        try:
            jobs_data = [job.__dict__ for job in self.jobs.values()]
            with open(config_file, 'w') as f:
                json.dump(jobs_data, f, indent=2, default=str)
        except Exception as e:
            self.logger.error(f"Error guardando configuración: {e}")

    def create_backup_job(self, job: BackupJob):
        """
        Crear un nuevo trabajo de backup

        Args:
            job: Configuración del trabajo
        """
        self.jobs[job.job_id] = job
        self._save_config()
        self.logger.info(f"Trabajo de backup creado: {job.name} ({job.job_id})")

    def run_backup_job(self, job_id: str) -> BackupResult:
        """
        Ejecutar un trabajo de backup

        Args:
            job_id: ID del trabajo a ejecutar

        Returns:
            Resultado del backup
        """
        if job_id not in self.jobs:
            return BackupResult(
                job_id=job_id,
                success=False,
                start_time=datetime.now(),
                end_time=datetime.now(),
                total_files=0,
                total_size=0,
                compressed_size=0,
                error_message="Trabajo no encontrado"
            )

        job = self.jobs[job_id]
        start_time = datetime.now()

        self.logger.info(f"Iniciando backup: {job.name} ({job_id})")

        try:
            # Paso 1: Análisis incremental (si está habilitado)
            incremental_result = None
            if job.incremental:
                # Crear snapshot base si no existe
                snapshot_name = f"{job_id}_base"
                if not self.incremental_engine.get_snapshot_info(snapshot_name):
                    self.incremental_engine.create_snapshot(snapshot_name, job.source_paths[0])

                # Analizar cambios
                incremental_result = self.incremental_engine.analyze_changes(
                    snapshot_name, job.source_paths[0]
                )

                if incremental_result.changed_files == 0:
                    self.logger.info("No hay cambios detectados, omitiendo backup")
                    return BackupResult(
                        job_id=job_id,
                        success=True,
                        start_time=start_time,
                        end_time=datetime.now(),
                        total_files=incremental_result.total_files,
                        total_size=0,
                        compressed_size=0
                    )

            # Paso 2: Recopilar archivos a respaldar
            files_to_backup = self._get_files_to_backup(job, incremental_result)

            if not files_to_backup:
                return BackupResult(
                    job_id=job_id,
                    success=False,
                    start_time=start_time,
                    end_time=datetime.now(),
                    total_files=0,
                    total_size=0,
                    compressed_size=0,
                    error_message="No hay archivos para respaldar"
                )

            # Paso 3: Deduplicación (si está habilitada)
            dedup_stats = None
            if job.deduplication:
                self.logger.info("Aplicando deduplicación...")
                dedup_stats = self.deduplicator.deduplicate_directory(
                    job.source_paths[0], recursive=True
                )

            # Paso 4: Crear backup comprimido
            backup_id = f"{job_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            backup_path = self._create_backup_archive(job, files_to_backup, backup_id)

            if not backup_path:
                raise Exception("Error creando archivo de backup")

            # Paso 5: Encriptación (si está habilitada)
            if job.encryption:
                self.logger.info("Encriptando backup...")
                encrypted_path = backup_path.with_suffix('.enc')
                enc_result = self.encryptor.encrypt_file(str(backup_path), str(encrypted_path))
                if not enc_result.success:
                    raise Exception(f"Error en encriptación: {enc_result.error_message}")
                backup_path = encrypted_path

            # Paso 6: Replicación a destinos
            replication_results = []
            if job.replication_destinations:
                self.logger.info("Replicando a destinos...")
                replication_results = self.storage_manager.replicate_file(
                    str(backup_path),
                    destinations=job.replication_destinations
                )

            # Paso 7: Verificación de integridad (si está habilitada)
            verification_result = None
            if job.verify_integrity:
                self.logger.info("Verificando integridad...")
                # Crear manifiesto
                manifest = self.verifier.create_backup_manifest(
                    backup_id, str(backup_path.parent),
                    compression_type="adaptive" if job.compression else "none",
                    encryption_type="aes256" if job.encryption else "none"
                )
                # Verificar
                verification_result = self.verifier.verify_backup_integrity(backup_id, str(backup_path.parent))

            # Paso 8: Actualizar snapshot incremental
            if job.incremental and incremental_result:
                new_snapshot = f"{job_id}_{backup_id}"
                self.incremental_engine.save_changes_snapshot(
                    snapshot_name, new_snapshot, incremental_result.changes
                )

            # Paso 9: Limpieza
            self._cleanup_old_backups(job)

            # Calcular estadísticas finales
            total_size = sum(os.path.getsize(f) for f in files_to_backup if os.path.exists(f))
            compressed_size = os.path.getsize(backup_path) if os.path.exists(backup_path) else 0

            result = BackupResult(
                job_id=job_id,
                success=True,
                start_time=start_time,
                end_time=datetime.now(),
                total_files=len(files_to_backup),
                total_size=total_size,
                compressed_size=compressed_size,
                deduplication_stats=dedup_stats,
                replication_results=replication_results,
                verification_result=verification_result
            )

            self.logger.info(f"Backup completado exitosamente: {job.name}")
            return result

        except Exception as e:
            error_msg = str(e)
            self.logger.error(f"Error en backup {job_id}: {error_msg}")
            return BackupResult(
                job_id=job_id,
                success=False,
                start_time=start_time,
                end_time=datetime.now(),
                total_files=0,
                total_size=0,
                compressed_size=0,
                error_message=error_msg
            )

    def _get_files_to_backup(self, job: BackupJob,
                           incremental_result: Optional[IncrementalBackupResult]) -> List[str]:
        """Obtener lista de archivos a respaldar"""
        if incremental_result and job.incremental:
            # Solo archivos cambiados
            return [change.path for change in incremental_result.changes
                   if change.change_type.name in ['CREATED', 'MODIFIED']]
        else:
            # Todos los archivos
            files = []
            for source_path in job.source_paths:
                if os.path.isfile(source_path):
                    files.append(source_path)
                elif os.path.isdir(source_path):
                    for root, dirs, files_in_dir in os.walk(source_path):
                        for file in files_in_dir:
                            files.append(os.path.join(root, file))
            return files

    def _create_backup_archive(self, job: BackupJob, files: List[str], backup_id: str) -> Optional[Path]:
        """Crear archivo de backup comprimido"""
        try:
            backup_dir = Path(self.config_dir.parent / 'backups' / backup_id)
            backup_dir.mkdir(parents=True, exist_ok=True)

            archive_path = backup_dir / f"{backup_id}.tar"

            if job.compression:
                # Usar compresión adaptativa
                # Crear archivo temporal sin comprimir primero
                temp_archive = backup_dir / f"{backup_id}_temp.tar"
                self._create_tar_archive(str(temp_archive), files, job.source_paths[0])

                # Comprimir con algoritmo adaptativo
                compressed_path = backup_dir / f"{backup_id}.tar.zst"
                comp_result = self.compressor.compress_file(str(temp_archive), str(compressed_path))

                if comp_result.success:
                    archive_path = compressed_path
                    # Limpiar archivo temporal
                    temp_archive.unlink(missing_ok=True)
                else:
                    self.logger.warning("Compresión fallida, usando archivo sin comprimir")
                    archive_path = temp_archive
            else:
                # Sin compresión
                self._create_tar_archive(str(archive_path), files, job.source_paths[0])

            return archive_path

        except Exception as e:
            self.logger.error(f"Error creando archivo de backup: {e}")
            return None

    def _create_tar_archive(self, archive_path: str, files: List[str], base_dir: str):
        """Crear archivo tar"""
        import tarfile

        with tarfile.open(archive_path, 'w') as tar:
            for file_path in files:
                if os.path.exists(file_path):
                    arcname = os.path.relpath(file_path, base_dir)
                    tar.add(file_path, arcname=arcname)

    def _cleanup_old_backups(self, job: BackupJob):
        """Limpiar backups antiguos según política de retención"""
        try:
            backup_base = Path(self.config_dir.parent / 'backups')
            if not backup_base.exists():
                return

            cutoff_time = datetime.now() - timedelta(days=job.retention_days)

            for backup_dir in backup_base.iterdir():
                if backup_dir.is_dir():
                    # Verificar si es un directorio de backup antiguo
                    try:
                        # Extraer timestamp del nombre (formato: jobid_YYYYMMDD_HHMMSS)
                        timestamp_str = backup_dir.name.split('_')[-1]
                        if len(timestamp_str) == 15:  # YYYYMMDD_HHMMSS
                            timestamp = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')
                            if timestamp < cutoff_time:
                                import shutil
                                shutil.rmtree(backup_dir)
                                self.logger.info(f"Backup antiguo eliminado: {backup_dir.name}")
                    except (ValueError, IndexError):
                        pass  # No es un directorio de backup con timestamp

        except Exception as e:
            self.logger.warning(f"Error limpiando backups antiguos: {e}")

    def restore_backup(self, backup_id: str, target_path: str,
                      files_to_restore: Optional[List[str]] = None) -> RestoreResult:
        """
        Restaurar un backup

        Args:
            backup_id: ID del backup a restaurar
            target_path: Directorio donde restaurar
            files_to_restore: Lista específica de archivos (opcional)

        Returns:
            Resultado de la restauración
        """
        self.logger.info(f"Iniciando restauración de backup {backup_id}")

        try:
            # Encontrar archivo de backup
            backup_dir = Path(self.config_dir.parent / 'backups' / backup_id)
            if not backup_dir.exists():
                return RestoreResult(errors=["Directorio de backup no encontrado"])

            # Buscar archivo de backup
            backup_files = list(backup_dir.glob(f"{backup_id}.*"))
            if not backup_files:
                return RestoreResult(errors=["Archivo de backup no encontrado"])

            backup_file = backup_files[0]

            # Desencriptar si es necesario
            if backup_file.suffix == '.enc':
                decrypted_file = backup_file.with_suffix('')
                dec_result = self.encryptor.decrypt_file(str(backup_file), str(decrypted_file))
                if not dec_result.success:
                    return RestoreResult(errors=[f"Error desencriptando: {dec_result.error_message}"])
                backup_file = decrypted_file

            # Descomprimir si es necesario
            if backup_file.suffix in ['.zst', '.gz', '.bz2', '.lz4']:
                decompressed_file = backup_file.with_suffix('')
                decomp_result = self.compressor.decompress_file(str(backup_file), str(decompressed_file))
                if not decomp_result.success:
                    return RestoreResult(errors=["Error descomprimiendo backup"])
                backup_file = decompressed_file

            # Usar restaurador granular
            if files_to_restore:
                # Restauración selectiva
                targets = []
                for file_path in files_to_restore:
                    targets.append(self.restorer.RestoreTarget(
                        source_path=file_path,
                        target_path=os.path.join(target_path, os.path.basename(file_path)),
                        snapshot_name=backup_id
                    ))
                return self.restorer.restore_files(targets)
            else:
                # Restauración completa
                # Extraer tar al directorio destino
                import tarfile
                with tarfile.open(backup_file, 'r') as tar:
                    tar.extractall(target_path)

                # Contar archivos extraídos
                extracted_files = []
                for root, dirs, files_in_dir in os.walk(target_path):
                    for file in files_in_dir:
                        extracted_files.append(os.path.join(root, file))

                return RestoreResult(
                    files_restored=len(extracted_files),
                    total_size_restored=sum(os.path.getsize(f) for f in extracted_files)
                )

        except Exception as e:
            self.logger.error(f"Error restaurando backup {backup_id}: {e}")
            return RestoreResult(errors=[str(e)])

    def get_backup_status(self, job_id: str = None) -> Dict:
        """
        Obtener estado del sistema de backup

        Args:
            job_id: ID específico del trabajo (opcional)

        Returns:
            Diccionario con información de estado
        """
        status = {
            'timestamp': datetime.now().isoformat(),
            'total_jobs': len(self.jobs),
            'active_jobs': [jid for jid, job in self.jobs.items() if job.schedule != 'disabled']
        }

        if job_id:
            if job_id in self.jobs:
                job = self.jobs[job_id]
                status['job'] = {
                    'id': job.job_id,
                    'name': job.name,
                    'source_paths': job.source_paths,
                    'schedule': job.schedule,
                    'compression': job.compression,
                    'encryption': job.encryption,
                    'deduplication': job.deduplication,
                    'replication_destinations': job.replication_destinations,
                    'retention_days': job.retention_days,
                    'incremental': job.incremental,
                    'verify_integrity': job.verify_integrity
                }
            else:
                status['error'] = 'Trabajo no encontrado'

        # Información de almacenamiento
        status['storage'] = {
            'destinations': self.storage_manager.list_destinations(),
            'total_backups_size': self._calculate_total_backup_size()
        }

        # Información de deduplicación
        status['deduplication'] = self.deduplicator.get_statistics()

        return status

    def _calculate_total_backup_size(self) -> int:
        """Calcular tamaño total de todos los backups"""
        backup_base = Path(self.config_dir.parent / 'backups')
        if not backup_base.exists():
            return 0

        total_size = 0
        for backup_dir in backup_base.iterdir():
            if backup_dir.is_dir():
                for file_path in backup_dir.rglob('*'):
                    if file_path.is_file():
                        total_size += file_path.stat().st_size

        return total_size

    def schedule_backup_job(self, job_id: str, cron_expression: str):
        """
        Programar un trabajo de backup

        Args:
            job_id: ID del trabajo
            cron_expression: Expresión cron
        """
        if job_id in self.jobs:
            self.jobs[job_id].schedule = cron_expression
            self._save_config()
            self.logger.info(f"Trabajo programado: {job_id} - {cron_expression}")

    def get_system_health(self) -> Dict:
        """
        Obtener salud general del sistema de backup

        Returns:
            Diccionario con métricas de salud
        """
        health = {
            'timestamp': datetime.now().isoformat(),
            'components': {
                'deduplication': {
                    'status': 'operational',
                    'stats': self.deduplicator.get_statistics()
                },
                'compression': {
                    'status': 'operational'
                },
                'encryption': {
                    'status': 'operational',
                    'master_key_exists': Path(self.encryptor.key_file).exists()
                },
                'storage': {
                    'status': 'operational',
                    'destinations': len(self.storage_manager.destinations)
                },
                'verification': {
                    'status': 'operational'
                },
                'incremental': {
                    'status': 'operational',
                    'snapshots': len(self.incremental_engine.list_snapshots())
                }
            },
            'storage_usage': self._calculate_total_backup_size(),
            'last_backup_check': datetime.now().isoformat()  # Placeholder
        }

        return health