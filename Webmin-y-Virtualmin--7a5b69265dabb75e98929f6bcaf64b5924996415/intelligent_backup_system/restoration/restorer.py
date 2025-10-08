#!/usr/bin/env python3
"""
Módulo de Restauración Granular
Implementa restauración selectiva de archivos, directorios y dominios
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import os
import shutil
import sqlite3
from pathlib import Path
from typing import Dict, List, Tuple, Set, Optional
from dataclasses import dataclass
from datetime import datetime
import logging
import tempfile
import tarfile
import gzip
import bz2
from concurrent.futures import ThreadPoolExecutor, as_completed

@dataclass
class RestoreTarget:
    """Objetivo de restauración"""
    source_path: str
    target_path: str
    snapshot_name: str
    include_subdirs: bool = True

@dataclass
class RestoreResult:
    """Resultado de una operación de restauración"""
    files_restored: int = 0
    directories_restored: int = 0
    total_size_restored: int = 0
    errors: List[str] = None
    processing_time: float = 0.0

    def __post_init__(self):
        if self.errors is None:
            self.errors = []

class GranularRestorer:
    """
    Motor de restauración granular que permite restaurar
    archivos, directorios o dominios específicos
    """

    def __init__(self, backup_root: str, db_path: str = None, max_workers: int = 4):
        """
        Inicializar el restaurador granular

        Args:
            backup_root: Directorio raíz de backups
            db_path: Ruta a la base de datos de metadatos
            max_workers: Número máximo de hilos
        """
        self.backup_root = Path(backup_root)
        self.db_path = db_path or os.path.join(backup_root, 'incremental_backup.db')
        self.max_workers = max_workers
        self.logger = logging.getLogger(__name__)

        # Verificar que existe el directorio de backups
        if not self.backup_root.exists():
            raise ValueError(f"Directorio de backups no existe: {backup_root}")

    def _get_snapshot_files(self, snapshot_name: str) -> Dict[str, Dict]:
        """
        Obtener archivos de un snapshot desde la base de datos

        Args:
            snapshot_name: Nombre del snapshot

        Returns:
            Diccionario de path -> metadatos
        """
        files = {}

        with sqlite3.connect(self.db_path) as conn:
            # Obtener ID del snapshot
            cursor = conn.execute('SELECT id FROM snapshots WHERE name = ?', (snapshot_name,))
            row = cursor.fetchone()
            if not row:
                raise ValueError(f"Snapshot '{snapshot_name}' no encontrado")

            snapshot_id = row[0]

            # Obtener archivos del snapshot
            cursor = conn.execute('''
                SELECT file_path, size, mtime, ctime, mode, uid, gid, hash_value
                FROM file_metadata
                WHERE snapshot_id = ?
            ''', (snapshot_id,))

            for row in cursor:
                path, size, mtime, ctime, mode, uid, gid, hash_val = row
                files[path] = {
                    'size': size,
                    'mtime': mtime,
                    'ctime': ctime,
                    'mode': mode,
                    'uid': uid,
                    'gid': gid,
                    'hash_value': hash_val
                }

        return files

    def _find_backup_file(self, file_path: str, snapshot_name: str) -> Optional[Path]:
        """
        Encontrar el archivo de backup correspondiente

        Args:
            file_path: Ruta del archivo original
            snapshot_name: Nombre del snapshot

        Returns:
            Path al archivo de backup o None
        """
        # Buscar en diferentes formatos de backup
        backup_patterns = [
            self.backup_root / snapshot_name / f"{Path(file_path).name}.gz",
            self.backup_root / snapshot_name / f"{Path(file_path).name}.bz2",
            self.backup_root / snapshot_name / f"{Path(file_path).name}.lz4",
            self.backup_root / snapshot_name / f"{Path(file_path).name}.zst",
            self.backup_root / snapshot_name / f"{Path(file_path).name}.enc",
        ]

        for pattern in backup_patterns:
            if pattern.exists():
                return pattern

        # Buscar en archivos tar
        tar_patterns = [
            self.backup_root / snapshot_name / "backup.tar.gz",
            self.backup_root / snapshot_name / "backup.tar.bz2",
            self.backup_root / snapshot_name / "backup.tar.lz4",
            self.backup_root / snapshot_name / "backup.tar.zst",
        ]

        for tar_path in tar_patterns:
            if tar_path.exists():
                return tar_path

        return None

    def _extract_from_tar(self, tar_path: Path, file_path: str, target_path: Path) -> bool:
        """
        Extraer un archivo específico de un archivo tar

        Args:
            tar_path: Path al archivo tar
            file_path: Ruta del archivo dentro del tar
            target_path: Dónde extraer

        Returns:
            True si se extrajo correctamente
        """
        try:
            # Determinar el tipo de compresión
            if tar_path.suffix == '.gz':
                mode = 'r:gz'
            elif tar_path.suffix == '.bz2':
                mode = 'r:bz2'
            else:
                mode = 'r'

            with tarfile.open(tar_path, mode) as tar:
                # Buscar el archivo en el tar
                member = None
                for tar_member in tar.getmembers():
                    if tar_member.name == file_path or tar_member.name.endswith(file_path):
                        member = tar_member
                        break

                if member:
                    # Extraer el archivo
                    tar.extract(member, target_path.parent)
                    extracted_path = target_path.parent / member.name

                    # Mover al lugar correcto si es necesario
                    if extracted_path != target_path:
                        shutil.move(str(extracted_path), str(target_path))

                    return True
                else:
                    self.logger.warning(f"Archivo {file_path} no encontrado en {tar_path}")

        except Exception as e:
            self.logger.error(f"Error extrayendo de tar {tar_path}: {e}")

        return False

    def _restore_single_file(self, file_path: str, target_path: Path,
                           snapshot_name: str, metadata: Dict) -> bool:
        """
        Restaurar un archivo individual

        Args:
            file_path: Ruta original del archivo
            target_path: Dónde restaurar
            snapshot_name: Nombre del snapshot
            metadata: Metadatos del archivo

        Returns:
            True si se restauró correctamente
        """
        try:
            # Crear directorio padre si no existe
            target_path.parent.mkdir(parents=True, exist_ok=True)

            # Buscar archivo de backup
            backup_file = self._find_backup_file(file_path, snapshot_name)

            if backup_file:
                # Si es un archivo individual comprimido
                if backup_file.suffix in ['.gz', '.bz2', '.lz4', '.zst']:
                    # Descomprimir archivo individual
                    self._decompress_file(backup_file, target_path)
                else:
                    # Extraer de archivo tar
                    self._extract_from_tar(backup_file, file_path, target_path)

                # Restaurar metadatos
                self._restore_file_metadata(target_path, metadata)

                self.logger.info(f"Archivo restaurado: {file_path} -> {target_path}")
                return True
            else:
                self.logger.error(f"Archivo de backup no encontrado para: {file_path}")
                return False

        except Exception as e:
            self.logger.error(f"Error restaurando archivo {file_path}: {e}")
            return False

    def _decompress_file(self, compressed_path: Path, target_path: Path):
        """
        Descomprimir un archivo individual

        Args:
            compressed_path: Archivo comprimido
            target_path: Destino de descompresión
        """
        suffix = compressed_path.suffix

        with open(compressed_path, 'rb') as f_in:
            if suffix == '.gz':
                with gzip.open(f_in, 'rb') as f_gz:
                    with open(target_path, 'wb') as f_out:
                        shutil.copyfileobj(f_gz, f_out)
            elif suffix == '.bz2':
                with bz2.open(f_in, 'rb') as f_bz:
                    with open(target_path, 'wb') as f_out:
                        shutil.copyfileobj(f_bz, f_out)
            else:
                # Para LZ4/Zstd necesitaríamos las librerías específicas
                # Por ahora, copiar tal cual
                with open(target_path, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)

    def _restore_file_metadata(self, file_path: Path, metadata: Dict):
        """
        Restaurar metadatos de archivo (permisos, tiempos, etc.)

        Args:
            file_path: Path al archivo
            metadata: Metadatos a restaurar
        """
        try:
            # Restaurar tiempos de modificación y acceso
            os.utime(file_path, (metadata['atime'], metadata['mtime']))

            # Restaurar permisos
            os.chmod(file_path, metadata['mode'])

            # Intentar restaurar propietario (requiere root)
            try:
                os.chown(file_path, metadata['uid'], metadata['gid'])
            except PermissionError:
                self.logger.warning(f"No se pudieron restaurar permisos de propietario para {file_path}")

        except Exception as e:
            self.logger.warning(f"Error restaurando metadatos de {file_path}: {e}")

    def restore_files(self, targets: List[RestoreTarget]) -> RestoreResult:
        """
        Restaurar múltiples archivos/directorios

        Args:
            targets: Lista de objetivos de restauración

        Returns:
            Resultado de la restauración
        """
        start_time = datetime.now()
        result = RestoreResult()

        for target in targets:
            try:
                # Obtener archivos del snapshot
                snapshot_files = self._get_snapshot_files(target.snapshot_name)

                # Filtrar archivos a restaurar
                files_to_restore = self._filter_files_for_restore(
                    snapshot_files, target.source_path, target.include_subdirs
                )

                if not files_to_restore:
                    result.errors.append(f"No se encontraron archivos para restaurar en {target.source_path}")
                    continue

                # Restaurar archivos en paralelo
                with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
                    futures = []
                    for file_path, metadata in files_to_restore.items():
                        # Calcular ruta de destino relativa
                        rel_path = os.path.relpath(file_path, target.source_path)
                        dest_path = Path(target.target_path) / rel_path

                        future = executor.submit(
                            self._restore_single_file,
                            file_path, dest_path, target.snapshot_name, metadata
                        )
                        futures.append((future, file_path, metadata))

                    # Procesar resultados
                    for future, file_path, metadata in futures:
                        try:
                            success = future.result()
                            if success:
                                result.files_restored += 1
                                result.total_size_restored += metadata['size']
                            else:
                                result.errors.append(f"Error restaurando: {file_path}")
                        except Exception as e:
                            result.errors.append(f"Error procesando {file_path}: {e}")

            except Exception as e:
                result.errors.append(f"Error procesando target {target.source_path}: {e}")

        result.processing_time = (datetime.now() - start_time).total_seconds()
        return result

    def _filter_files_for_restore(self, snapshot_files: Dict[str, Dict],
                                source_path: str, include_subdirs: bool) -> Dict[str, Dict]:
        """
        Filtrar archivos que deben restaurarse

        Args:
            snapshot_files: Todos los archivos del snapshot
            source_path: Path base a restaurar
            include_subdirs: Si incluir subdirectorios

        Returns:
            Archivos filtrados
        """
        filtered = {}

        source_path = os.path.normpath(source_path)

        for file_path, metadata in snapshot_files.items():
            file_path_norm = os.path.normpath(file_path)

            # Si es exactamente el path
            if file_path_norm == source_path:
                filtered[file_path] = metadata
            # Si está dentro del directorio y se incluyen subdirs
            elif include_subdirs and file_path_norm.startswith(source_path + os.sep):
                filtered[file_path] = metadata
            # Si es un archivo en el directorio raíz
            elif not include_subdirs and os.path.dirname(file_path_norm) == source_path:
                filtered[file_path] = metadata

        return filtered

    def restore_domain(self, domain_name: str, target_path: str,
                      snapshot_name: str) -> RestoreResult:
        """
        Restaurar un dominio completo de Virtualmin

        Args:
            domain_name: Nombre del dominio
            target_path: Directorio donde restaurar
            snapshot_name: Snapshot a usar

        Returns:
            Resultado de la restauración
        """
        # Rutas típicas de Virtualmin para un dominio
        domain_paths = [
            f"/home/{domain_name}",  # Home del dominio
            f"/var/www/{domain_name}",  # Document root
            f"/etc/apache2/sites-available/{domain_name}.conf",  # Config Apache
            f"/etc/nginx/sites-available/{domain_name}",  # Config Nginx
            f"/var/log/virtualmin/{domain_name}",  # Logs
        ]

        targets = []
        for path in domain_paths:
            if os.path.exists(path) or True:  # Incluir aunque no exista actualmente
                targets.append(RestoreTarget(
                    source_path=path,
                    target_path=os.path.join(target_path, os.path.basename(path)),
                    snapshot_name=snapshot_name,
                    include_subdirs=True
                ))

        return self.restore_files(targets)

    def restore_database(self, db_name: str, target_file: str,
                        snapshot_name: str) -> bool:
        """
        Restaurar una base de datos específica

        Args:
            db_name: Nombre de la base de datos
            target_file: Archivo donde guardar el dump
            snapshot_name: Snapshot a usar

        Returns:
            True si se restauró correctamente
        """
        try:
            # Buscar archivo de backup de BD
            db_backup_patterns = [
                self.backup_root / snapshot_name / f"{db_name}.sql.gz",
                self.backup_root / snapshot_name / f"{db_name}.sql.bz2",
                self.backup_root / snapshot_name / f"databases/{db_name}.sql.gz",
                self.backup_root / snapshot_name / f"databases/{db_name}.sql.bz2",
            ]

            for pattern in db_backup_patterns:
                if pattern.exists():
                    self._decompress_file(pattern, Path(target_file))
                    self.logger.info(f"Base de datos {db_name} restaurada en {target_file}")
                    return True

            self.logger.error(f"Backup de base de datos {db_name} no encontrado")
            return False

        except Exception as e:
            self.logger.error(f"Error restaurando base de datos {db_name}: {e}")
            return False

    def list_available_snapshots(self) -> List[Dict]:
        """
        Listar snapshots disponibles para restauración

        Returns:
            Lista de snapshots con metadatos
        """
        snapshots = []

        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT name, timestamp, total_files, total_size, description
                    FROM snapshots
                    ORDER BY timestamp DESC
                ''')

                for row in cursor:
                    name, timestamp, total_files, total_size, description = row
                    snapshots.append({
                        'name': name,
                        'timestamp': datetime.fromtimestamp(timestamp),
                        'total_files': total_files,
                        'total_size': total_size,
                        'description': description
                    })
        except Exception as e:
            self.logger.error(f"Error listando snapshots: {e}")

        return snapshots

    def preview_restore(self, target: RestoreTarget) -> Dict:
        """
        Vista previa de lo que se restaurará

        Args:
            target: Objetivo de restauración

        Returns:
            Diccionario con información de preview
        """
        try:
            snapshot_files = self._get_snapshot_files(target.snapshot_name)
            files_to_restore = self._filter_files_for_restore(
                snapshot_files, target.source_path, target.include_subdirs
            )

            total_size = sum(metadata['size'] for metadata in files_to_restore.values())

            return {
                'source_path': target.source_path,
                'target_path': target.target_path,
                'snapshot': target.snapshot_name,
                'files_count': len(files_to_restore),
                'total_size': total_size,
                'files': list(files_to_restore.keys())[:10],  # Primeros 10 archivos
                'truncated': len(files_to_restore) > 10
            }

        except Exception as e:
            return {
                'error': str(e),
                'source_path': target.source_path,
                'target_path': target.target_path,
                'snapshot': target.snapshot_name
            }

    def validate_restore_target(self, target: RestoreTarget) -> List[str]:
        """
        Validar que un objetivo de restauración es válido

        Args:
            target: Objetivo a validar

        Returns:
            Lista de errores de validación
        """
        errors = []

        # Verificar que el snapshot existe
        try:
            self._get_snapshot_files(target.snapshot_name)
        except ValueError:
            errors.append(f"Snapshot '{target.snapshot_name}' no encontrado")

        # Verificar que el directorio de destino es escribible
        target_path = Path(target.target_path)
        if target_path.exists():
            if not os.access(target_path, os.W_OK):
                errors.append(f"Directorio de destino no es escribible: {target.target_path}")
        else:
            # Intentar crear el directorio
            try:
                target_path.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errors.append(f"No se puede crear directorio de destino: {e}")

        return errors