#!/usr/bin/env python3
"""
Módulo de Backup Incremental Inteligente
Implementa análisis de cambios y backup incremental basado en diferencias
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import os
import hashlib
import sqlite3
from pathlib import Path
from typing import Dict, List, Tuple, Set, Optional, NamedTuple
from dataclasses import dataclass
from datetime import datetime, timedelta
import logging
import json
from concurrent.futures import ThreadPoolExecutor, as_completed
import stat
from enum import Enum

class FileChangeType(Enum):
    """Tipos de cambios en archivos"""
    CREATED = "created"
    MODIFIED = "modified"
    DELETED = "deleted"
    UNCHANGED = "unchanged"
    RENAMED = "renamed"

@dataclass
class FileMetadata:
    """Metadatos de un archivo"""
    path: str
    size: int
    mtime: float
    ctime: float
    mode: int
    uid: int
    gid: int
    hash_value: Optional[str] = None
    inode: Optional[int] = None

@dataclass
class FileChange:
    """Cambio detectado en un archivo"""
    path: str
    change_type: FileChangeType
    old_metadata: Optional[FileMetadata] = None
    new_metadata: Optional[FileMetadata] = None
    similarity_score: float = 0.0

@dataclass
class IncrementalBackupResult:
    """Resultado de un backup incremental"""
    total_files: int = 0
    changed_files: int = 0
    new_files: int = 0
    deleted_files: int = 0
    modified_files: int = 0
    renamed_files: int = 0
    total_size_changed: int = 0
    processing_time: float = 0.0
    changes: List[FileChange] = None

    def __post_init__(self):
        if self.changes is None:
            self.changes = []

class IncrementalBackupEngine:
    """
    Motor de backup incremental que analiza cambios y optimiza
    el respaldo basado en diferencias
    """

    def __init__(self, db_path: str = None, max_workers: int = 4, hash_block_size: int = 8192):
        """
        Inicializar el motor de backup incremental

        Args:
            db_path: Ruta a la base de datos de metadatos
            max_workers: Número máximo de hilos
            hash_block_size: Tamaño de bloque para hashing rápido
        """
        self.db_path = db_path or os.path.join(os.getcwd(), 'incremental_backup.db')
        self.max_workers = max_workers
        self.hash_block_size = hash_block_size
        self.logger = logging.getLogger(__name__)

        # Inicializar base de datos
        self._init_database()

        # Cache de metadatos para rendimiento
        self.metadata_cache: Dict[str, FileMetadata] = {}

    def _init_database(self):
        """Inicializar base de datos SQLite para metadatos"""
        with sqlite3.connect(self.db_path) as conn:
            # Tabla de snapshots (puntos de respaldo)
            conn.execute('''
                CREATE TABLE IF NOT EXISTS snapshots (
                    id INTEGER PRIMARY KEY,
                    name TEXT UNIQUE,
                    timestamp REAL,
                    total_files INTEGER,
                    total_size INTEGER,
                    description TEXT
                )
            ''')

            # Tabla de metadatos de archivos por snapshot
            conn.execute('''
                CREATE TABLE IF NOT EXISTS file_metadata (
                    snapshot_id INTEGER,
                    file_path TEXT,
                    size INTEGER,
                    mtime REAL,
                    ctime REAL,
                    mode INTEGER,
                    uid INTEGER,
                    gid INTEGER,
                    hash_value TEXT,
                    inode INTEGER,
                    FOREIGN KEY (snapshot_id) REFERENCES snapshots(id),
                    PRIMARY KEY (snapshot_id, file_path)
                )
            ''')

            # Tabla de cambios entre snapshots
            conn.execute('''
                CREATE TABLE IF NOT EXISTS changes (
                    from_snapshot_id INTEGER,
                    to_snapshot_id INTEGER,
                    file_path TEXT,
                    change_type TEXT,
                    old_size INTEGER,
                    new_size INTEGER,
                    similarity_score REAL,
                    FOREIGN KEY (from_snapshot_id) REFERENCES snapshots(id),
                    FOREIGN KEY (to_snapshot_id) REFERENCES snapshots(id),
                    PRIMARY KEY (from_snapshot_id, to_snapshot_id, file_path)
                )
            ''')

            # Índices para rendimiento
            conn.execute('CREATE INDEX IF NOT EXISTS idx_file_metadata_path ON file_metadata(file_path)')
            conn.execute('CREATE INDEX IF NOT EXISTS idx_file_metadata_snapshot ON file_metadata(snapshot_id)')
            conn.execute('CREATE INDEX IF NOT EXISTS idx_changes_snapshots ON changes(from_snapshot_id, to_snapshot_id)')

    def _calculate_file_hash(self, file_path: str) -> Optional[str]:
        """
        Calcular hash rápido de archivo para comparación

        Args:
            file_path: Ruta al archivo

        Returns:
            Hash SHA-256 o None si error
        """
        try:
            hasher = hashlib.sha256()
            with open(file_path, 'rb') as f:
                # Leer bloques para hash rápido
                while True:
                    data = f.read(self.hash_block_size)
                    if not data:
                        break
                    hasher.update(data)
            return hasher.hexdigest()
        except (OSError, IOError) as e:
            self.logger.warning(f"Error calculando hash de {file_path}: {e}")
            return None

    def _get_file_metadata(self, file_path: str) -> Optional[FileMetadata]:
        """
        Obtener metadatos completos de un archivo

        Args:
            file_path: Ruta al archivo

        Returns:
            FileMetadata o None si error
        """
        try:
            stat_info = os.stat(file_path)
            hash_value = self._calculate_file_hash(file_path)

            return FileMetadata(
                path=file_path,
                size=stat_info.st_size,
                mtime=stat_info.st_mtime,
                ctime=stat_info.st_ctime,
                mode=stat_info.st_mode,
                uid=stat_info.st_uid,
                gid=stat_info.st_gid,
                hash_value=hash_value,
                inode=stat_info.st_ino
            )
        except (OSError, IOError) as e:
            self.logger.warning(f"Error obteniendo metadatos de {file_path}: {e}")
            return None

    def _scan_directory(self, directory_path: str, recursive: bool = True) -> Dict[str, FileMetadata]:
        """
        Escanear directorio y obtener metadatos de todos los archivos

        Args:
            directory_path: Ruta al directorio
            recursive: Si debe escanear subdirectorios

        Returns:
            Diccionario de path -> FileMetadata
        """
        metadata = {}

        try:
            if recursive:
                for root, dirs, files in os.walk(directory_path):
                    for file in files:
                        file_path = os.path.join(root, file)
                        if os.path.isfile(file_path):
                            file_meta = self._get_file_metadata(file_path)
                            if file_meta:
                                metadata[file_path] = file_meta
            else:
                for item in os.listdir(directory_path):
                    file_path = os.path.join(directory_path, item)
                    if os.path.isfile(file_path):
                        file_meta = self._get_file_metadata(file_path)
                        if file_meta:
                            metadata[file_path] = file_meta

        except (OSError, IOError) as e:
            self.logger.error(f"Error escaneando directorio {directory_path}: {e}")

        return metadata

    def create_snapshot(self, name: str, directory_path: str,
                       description: str = "", recursive: bool = True) -> int:
        """
        Crear un snapshot (punto de referencia) de un directorio

        Args:
            name: Nombre del snapshot
            directory_path: Directorio a snapshot
            description: Descripción opcional
            recursive: Si debe ser recursivo

        Returns:
            ID del snapshot creado
        """
        self.logger.info(f"Creando snapshot '{name}' de {directory_path}")

        # Escanear directorio
        metadata = self._scan_directory(directory_path, recursive)

        # Calcular estadísticas
        total_files = len(metadata)
        total_size = sum(meta.size for meta in metadata.values())

        # Insertar snapshot en BD
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('''
                INSERT INTO snapshots (name, timestamp, total_files, total_size, description)
                VALUES (?, ?, ?, ?, ?)
            ''', (name, datetime.now().timestamp(), total_files, total_size, description))

            snapshot_id = cursor.lastrowid

            # Insertar metadatos de archivos
            file_metadata_rows = []
            for file_path, meta in metadata.items():
                file_metadata_rows.append((
                    snapshot_id, file_path, meta.size, meta.mtime, meta.ctime,
                    meta.mode, meta.uid, meta.gid, meta.hash_value, meta.inode
                ))

            conn.executemany('''
                INSERT INTO file_metadata
                (snapshot_id, file_path, size, mtime, ctime, mode, uid, gid, hash_value, inode)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', file_metadata_rows)

            conn.commit()

        self.logger.info(f"Snapshot '{name}' creado con {total_files} archivos ({total_size} bytes)")
        return snapshot_id

    def _calculate_similarity(self, old_meta: FileMetadata, new_meta: FileMetadata) -> float:
        """
        Calcular similitud entre dos versiones de un archivo

        Args:
            old_meta: Metadatos antiguos
            new_meta: Metadatos nuevos

        Returns:
            Score de similitud (0.0 a 1.0)
        """
        if not old_meta or not new_meta:
            return 0.0

        # Si el tamaño cambió drásticamente, baja similitud
        size_ratio = min(old_meta.size, new_meta.size) / max(old_meta.size, new_meta.size) if max(old_meta.size, new_meta.size) > 0 else 0

        # Si el hash es igual, similitud perfecta
        if old_meta.hash_value and new_meta.hash_value and old_meta.hash_value == new_meta.hash_value:
            return 1.0

        # Si el tamaño es similar y el mtime cambió poco, alta similitud
        time_diff = abs(new_meta.mtime - old_meta.mtime)
        if time_diff < 3600 and size_ratio > 0.8:  # Menos de 1 hora y 80% tamaño similar
            return 0.9

        # Similitud basada en tamaño
        return size_ratio

    def analyze_changes(self, from_snapshot: str, to_directory: str,
                       recursive: bool = True) -> IncrementalBackupResult:
        """
        Analizar cambios entre un snapshot y el estado actual del directorio

        Args:
            from_snapshot: Nombre del snapshot base
            to_directory: Directorio actual a comparar
            recursive: Si debe ser recursivo

        Returns:
            Resultado del análisis de cambios
        """
        start_time = datetime.now()

        # Obtener metadatos del snapshot
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('SELECT id FROM snapshots WHERE name = ?', (from_snapshot,))
            row = cursor.fetchone()
            if not row:
                raise ValueError(f"Snapshot '{from_snapshot}' no encontrado")

            from_snapshot_id = row[0]

            # Obtener metadatos antiguos
            old_metadata = {}
            cursor = conn.execute('''
                SELECT file_path, size, mtime, ctime, mode, uid, gid, hash_value, inode
                FROM file_metadata
                WHERE snapshot_id = ?
            ''', (from_snapshot_id,))

            for row in cursor:
                path, size, mtime, ctime, mode, uid, gid, hash_val, inode = row
                old_metadata[path] = FileMetadata(
                    path=path, size=size, mtime=mtime, ctime=ctime,
                    mode=mode, uid=uid, gid=gid, hash_value=hash_val, inode=inode
                )

        # Obtener metadatos actuales
        new_metadata = self._scan_directory(to_directory, recursive)

        # Analizar cambios
        changes = []
        processed_paths = set()

        # Archivos en el snapshot anterior
        for file_path, old_meta in old_metadata.items():
            processed_paths.add(file_path)
            if file_path in new_metadata:
                # Archivo existe en ambos
                new_meta = new_metadata[file_path]
                similarity = self._calculate_similarity(old_meta, new_meta)

                if old_meta.hash_value != new_meta.hash_value:
                    changes.append(FileChange(
                        path=file_path,
                        change_type=FileChangeType.MODIFIED,
                        old_metadata=old_meta,
                        new_metadata=new_meta,
                        similarity_score=similarity
                    ))
                # else: unchanged
            else:
                # Archivo eliminado
                changes.append(FileChange(
                    path=file_path,
                    change_type=FileChangeType.DELETED,
                    old_metadata=old_meta,
                    new_metadata=None
                ))

        # Archivos nuevos (no estaban en el snapshot)
        for file_path, new_meta in new_metadata.items():
            if file_path not in processed_paths:
                changes.append(FileChange(
                    path=file_path,
                    change_type=FileChangeType.CREATED,
                    old_metadata=None,
                    new_metadata=new_meta
                ))

        # Calcular estadísticas
        result = IncrementalBackupResult()
        result.total_files = len(new_metadata)
        result.processing_time = (datetime.now() - start_time).total_seconds()
        result.changes = changes

        for change in changes:
            if change.change_type == FileChangeType.CREATED:
                result.new_files += 1
                result.total_size_changed += change.new_metadata.size if change.new_metadata else 0
            elif change.change_type == FileChangeType.MODIFIED:
                result.modified_files += 1
                if change.new_metadata and change.old_metadata:
                    result.total_size_changed += change.new_metadata.size - change.old_metadata.size
            elif change.change_type == FileChangeType.DELETED:
                result.deleted_files += 1
                result.total_size_changed -= change.old_metadata.size if change.old_metadata else 0
            elif change.change_type == FileChangeType.RENAMED:
                result.renamed_files += 1

        result.changed_files = result.new_files + result.modified_files + result.deleted_files + result.renamed_files

        return result

    def get_incremental_files(self, from_snapshot: str, to_directory: str,
                            recursive: bool = True) -> List[str]:
        """
        Obtener lista de archivos que necesitan backup incremental

        Args:
            from_snapshot: Snapshot base
            to_directory: Directorio actual
            recursive: Si debe ser recursivo

        Returns:
            Lista de rutas de archivos a respaldar
        """
        result = self.analyze_changes(from_snapshot, to_directory, recursive)

        files_to_backup = []
        for change in result.changes:
            if change.change_type in [FileChangeType.CREATED, FileChangeType.MODIFIED]:
                files_to_backup.append(change.path)

        return files_to_backup

    def save_changes_snapshot(self, from_snapshot: str, to_snapshot: str,
                            changes: List[FileChange]) -> int:
        """
        Guardar cambios como un nuevo snapshot

        Args:
            from_snapshot: Snapshot origen
            to_snapshot: Nombre del nuevo snapshot
            changes: Lista de cambios

        Returns:
            ID del nuevo snapshot
        """
        # Obtener IDs de snapshots
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('SELECT id FROM snapshots WHERE name = ?', (from_snapshot,))
            from_id = cursor.fetchone()[0]

            # Crear nuevo snapshot
            cursor = conn.execute('''
                INSERT INTO snapshots (name, timestamp, total_files, total_size, description)
                VALUES (?, ?, 0, 0, ?)
            ''', (to_snapshot, datetime.now().timestamp(), f"Incremental from {from_snapshot}"))

            to_id = cursor.lastrowid

            # Guardar cambios
            change_rows = []
            for change in changes:
                change_rows.append((
                    from_id, to_id, change.path, change.change_type.value,
                    change.old_metadata.size if change.old_metadata else 0,
                    change.new_metadata.size if change.new_metadata else 0,
                    change.similarity_score
                ))

            conn.executemany('''
                INSERT INTO changes
                (from_snapshot_id, to_snapshot_id, file_path, change_type, old_size, new_size, similarity_score)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', change_rows)

            conn.commit()

        return to_id

    def get_snapshot_info(self, snapshot_name: str) -> Optional[Dict]:
        """
        Obtener información de un snapshot

        Args:
            snapshot_name: Nombre del snapshot

        Returns:
            Diccionario con información o None
        """
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('''
                SELECT id, name, timestamp, total_files, total_size, description
                FROM snapshots
                WHERE name = ?
            ''', (snapshot_name,))

            row = cursor.fetchone()
            if row:
                return {
                    'id': row[0],
                    'name': row[1],
                    'timestamp': datetime.fromtimestamp(row[2]),
                    'total_files': row[3],
                    'total_size': row[4],
                    'description': row[5]
                }

        return None

    def list_snapshots(self) -> List[Dict]:
        """
        Listar todos los snapshots disponibles

        Returns:
            Lista de diccionarios con información de snapshots
        """
        snapshots = []
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('''
                SELECT id, name, timestamp, total_files, total_size, description
                FROM snapshots
                ORDER BY timestamp DESC
            ''')

            for row in cursor:
                snapshots.append({
                    'id': row[0],
                    'name': row[1],
                    'timestamp': datetime.fromtimestamp(row[2]),
                    'total_files': row[3],
                    'total_size': row[4],
                    'description': row[5]
                })

        return snapshots

    def delete_snapshot(self, snapshot_name: str) -> bool:
        """
        Eliminar un snapshot

        Args:
            snapshot_name: Nombre del snapshot a eliminar

        Returns:
            True si se eliminó correctamente
        """
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('SELECT id FROM snapshots WHERE name = ?', (snapshot_name,))
            row = cursor.fetchone()
            if not row:
                return False

            snapshot_id = row[0]

            # Eliminar referencias en changes
            conn.execute('DELETE FROM changes WHERE from_snapshot_id = ? OR to_snapshot_id = ?',
                        (snapshot_id, snapshot_id))

            # Eliminar metadatos
            conn.execute('DELETE FROM file_metadata WHERE snapshot_id = ?', (snapshot_id,))

            # Eliminar snapshot
            conn.execute('DELETE FROM snapshots WHERE id = ?', (snapshot_id,))

            conn.commit()

        self.logger.info(f"Snapshot '{snapshot_name}' eliminado")
        return True

    def cleanup_old_snapshots(self, keep_days: int = 30) -> int:
        """
        Limpiar snapshots antiguos

        Args:
            keep_days: Días de snapshots a mantener

        Returns:
            Número de snapshots eliminados
        """
        cutoff_time = datetime.now().timestamp() - (keep_days * 24 * 60 * 60)
        deleted_count = 0

        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('SELECT name FROM snapshots WHERE timestamp < ?', (cutoff_time,))
            old_snapshots = [row[0] for row in cursor]

            for snapshot_name in old_snapshots:
                if self.delete_snapshot(snapshot_name):
                    deleted_count += 1

        self.logger.info(f"Eliminados {deleted_count} snapshots antiguos")
        return deleted_count