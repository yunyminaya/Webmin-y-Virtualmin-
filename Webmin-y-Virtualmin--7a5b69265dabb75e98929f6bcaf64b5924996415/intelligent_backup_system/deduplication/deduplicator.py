#!/usr/bin/env python3
"""
Módulo de Deduplicación Inteligente
Implementa deduplicación a nivel de bloque con hashing SHA-256
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import hashlib
import os
import sqlite3
from typing import Dict, List, Tuple, Optional, Set
from pathlib import Path
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
from dataclasses import dataclass
from datetime import datetime

@dataclass
class BlockInfo:
    """Información de un bloque deduplicado"""
    hash_value: str
    size: int
    offset: int
    file_path: str
    block_index: int
    first_seen: datetime

@dataclass
class DeduplicationStats:
    """Estadísticas de deduplicación"""
    total_blocks: int = 0
    unique_blocks: int = 0
    duplicated_blocks: int = 0
    space_saved: int = 0
    processing_time: float = 0.0

class BlockDeduplicator:
    """
    Motor de deduplicación a nivel de bloque con SHA-256
    """

    def __init__(self, block_size: int = 4096, db_path: str = None, max_workers: int = 4):
        """
        Inicializar el deduplicador

        Args:
            block_size: Tamaño de bloque en bytes (default: 4KB)
            db_path: Ruta a la base de datos de hashes
            max_workers: Número máximo de hilos para procesamiento paralelo
        """
        self.block_size = block_size
        self.max_workers = max_workers
        self.db_path = db_path or os.path.join(os.getcwd(), 'deduplication.db')
        self._lock = threading.Lock()

        # Configurar logging
        self.logger = logging.getLogger(__name__)
        self.logger.setLevel(logging.INFO)

        # Inicializar base de datos
        self._init_database()

        # Cache de hashes para rendimiento
        self.hash_cache: Dict[str, BlockInfo] = {}
        self._load_hash_cache()

    def _init_database(self):
        """Inicializar base de datos SQLite para almacenar hashes"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                CREATE TABLE IF NOT EXISTS blocks (
                    hash TEXT PRIMARY KEY,
                    size INTEGER,
                    first_seen TIMESTAMP,
                    reference_count INTEGER DEFAULT 1,
                    data BLOB
                )
            ''')

            conn.execute('''
                CREATE TABLE IF NOT EXISTS file_blocks (
                    file_path TEXT,
                    block_index INTEGER,
                    hash TEXT,
                    offset INTEGER,
                    FOREIGN KEY (hash) REFERENCES blocks(hash),
                    PRIMARY KEY (file_path, block_index)
                )
            ''')

            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_file_blocks_hash
                ON file_blocks(hash)
            ''')

            conn.execute('''
                CREATE INDEX IF NOT EXISTS idx_file_blocks_file
                ON file_blocks(file_path)
            ''')

    def _load_hash_cache(self):
        """Cargar cache de hashes desde la base de datos"""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute('''
                    SELECT hash, size, first_seen
                    FROM blocks
                    ORDER BY first_seen DESC
                    LIMIT 10000
                ''')

                for row in cursor:
                    hash_val, size, first_seen = row
                    self.hash_cache[hash_val] = BlockInfo(
                        hash_value=hash_val,
                        size=size,
                        offset=0,  # No necesitamos offset en cache
                        file_path='',  # No necesitamos file_path en cache
                        block_index=0,  # No necesitamos block_index en cache
                        first_seen=datetime.fromisoformat(first_seen)
                    )

            self.logger.info(f"Cache cargado con {len(self.hash_cache)} hashes")
        except Exception as e:
            self.logger.warning(f"Error cargando cache: {e}")

    def _calculate_sha256(self, data: bytes) -> str:
        """Calcular hash SHA-256 de datos"""
        return hashlib.sha256(data).hexdigest()

    def _read_file_blocks(self, file_path: str) -> List[Tuple[bytes, int]]:
        """
        Leer archivo en bloques

        Args:
            file_path: Ruta al archivo

        Returns:
            Lista de tuplas (datos_del_bloque, offset)
        """
        blocks = []
        try:
            with open(file_path, 'rb') as f:
                offset = 0
                while True:
                    data = f.read(self.block_size)
                    if not data:
                        break
                    blocks.append((data, offset))
                    offset += len(data)
        except Exception as e:
            self.logger.error(f"Error leyendo archivo {file_path}: {e}")
            raise

        return blocks

    def _process_file_blocks(self, file_path: str, blocks: List[Tuple[bytes, int]]) -> Tuple[List[BlockInfo], int]:
        """
        Procesar bloques de un archivo para deduplicación

        Args:
            file_path: Ruta al archivo
            blocks: Lista de bloques (datos, offset)

        Returns:
            Tupla de (lista de BlockInfo, número de bloques duplicados)
        """
        block_infos = []
        duplicated_count = 0

        for i, (data, offset) in enumerate(blocks):
            hash_value = self._calculate_sha256(data)

            # Verificar si el bloque ya existe
            existing_block = self.hash_cache.get(hash_value)

            if existing_block:
                # Bloque duplicado
                block_info = BlockInfo(
                    hash_value=hash_value,
                    size=len(data),
                    offset=offset,
                    file_path=file_path,
                    block_index=i,
                    first_seen=existing_block.first_seen
                )
                duplicated_count += 1
            else:
                # Nuevo bloque único
                block_info = BlockInfo(
                    hash_value=hash_value,
                    size=len(data),
                    offset=offset,
                    file_path=file_path,
                    block_index=i,
                    first_seen=datetime.now()
                )

                # Agregar a cache
                self.hash_cache[hash_value] = block_info

            block_infos.append(block_info)

        return block_infos, duplicated_count

    def deduplicate_file(self, file_path: str) -> Tuple[List[BlockInfo], DeduplicationStats]:
        """
        Deduplicar un archivo completo

        Args:
            file_path: Ruta al archivo a deduplicar

        Returns:
            Tupla de (lista de BlockInfo, estadísticas)
        """
        start_time = datetime.now()

        # Leer bloques del archivo
        blocks = self._read_file_blocks(file_path)

        if not blocks:
            return [], DeduplicationStats()

        # Procesar bloques
        block_infos, duplicated_blocks = self._process_file_blocks(file_path, blocks)

        # Calcular estadísticas
        total_blocks = len(block_infos)
        unique_hashes = set(info.hash_value for info in block_infos)
        unique_blocks = len(unique_hashes)

        # Estimar espacio ahorrado (aproximado)
        space_saved = duplicated_blocks * self.block_size

        stats = DeduplicationStats(
            total_blocks=total_blocks,
            unique_blocks=unique_blocks,
            duplicated_blocks=duplicated_blocks,
            space_saved=space_saved,
            processing_time=(datetime.now() - start_time).total_seconds()
        )

        # Guardar en base de datos
        self._save_to_database(file_path, block_infos)

        self.logger.info(f"Archivo deduplicado: {file_path}")
        self.logger.info(f"Bloques totales: {total_blocks}, únicos: {unique_blocks}, duplicados: {duplicated_blocks}")

        return block_infos, stats

    def _save_to_database(self, file_path: str, block_infos: List[BlockInfo]):
        """Guardar información de bloques en la base de datos"""
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                # Insertar/actualizar bloques
                for block_info in block_infos:
                    # Verificar si el bloque ya existe
                    cursor = conn.execute(
                        'SELECT reference_count FROM blocks WHERE hash = ?',
                        (block_info.hash_value,)
                    )
                    existing = cursor.fetchone()

                    if existing:
                        # Incrementar contador de referencias
                        conn.execute(
                            'UPDATE blocks SET reference_count = reference_count + 1 WHERE hash = ?',
                            (block_info.hash_value,)
                        )
                    else:
                        # Insertar nuevo bloque
                        conn.execute(
                            'INSERT INTO blocks (hash, size, first_seen, reference_count) VALUES (?, ?, ?, 1)',
                            (block_info.hash_value, block_info.size, block_info.first_seen.isoformat())
                        )

                    # Insertar relación archivo-bloque
                    conn.execute(
                        'INSERT OR REPLACE INTO file_blocks (file_path, block_index, hash, offset) VALUES (?, ?, ?, ?)',
                        (file_path, block_info.block_index, block_info.hash_value, block_info.offset)
                    )

                conn.commit()

    def deduplicate_directory(self, directory_path: str, recursive: bool = True) -> DeduplicationStats:
        """
        Deduplicar un directorio completo

        Args:
            directory_path: Ruta al directorio
            recursive: Si debe procesar subdirectorios

        Returns:
            Estadísticas totales de deduplicación
        """
        total_stats = DeduplicationStats()
        files_to_process = []

        # Recopilar archivos
        if recursive:
            for root, dirs, files in os.walk(directory_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    if os.path.isfile(file_path):
                        files_to_process.append(file_path)
        else:
            for item in os.listdir(directory_path):
                file_path = os.path.join(directory_path, item)
                if os.path.isfile(file_path):
                    files_to_process.append(file_path)

        self.logger.info(f"Procesando {len(files_to_process)} archivos en {directory_path}")

        # Procesar archivos en paralelo
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = [executor.submit(self.deduplicate_file, file_path) for file_path in files_to_process]

            for future in as_completed(futures):
                try:
                    block_infos, stats = future.result()
                    total_stats.total_blocks += stats.total_blocks
                    total_stats.unique_blocks += stats.unique_blocks
                    total_stats.duplicated_blocks += stats.duplicated_blocks
                    total_stats.space_saved += stats.space_saved
                    total_stats.processing_time += stats.processing_time
                except Exception as e:
                    self.logger.error(f"Error procesando archivo: {e}")

        return total_stats

    def get_file_blocks(self, file_path: str) -> List[BlockInfo]:
        """
        Obtener información de bloques de un archivo

        Args:
            file_path: Ruta al archivo

        Returns:
            Lista de BlockInfo
        """
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('''
                SELECT fb.block_index, fb.hash, fb.offset, b.size, b.first_seen
                FROM file_blocks fb
                JOIN blocks b ON fb.hash = b.hash
                WHERE fb.file_path = ?
                ORDER BY fb.block_index
            ''', (file_path,))

            block_infos = []
            for row in cursor:
                block_index, hash_val, offset, size, first_seen = row
                block_infos.append(BlockInfo(
                    hash_value=hash_val,
                    size=size,
                    offset=offset,
                    file_path=file_path,
                    block_index=block_index,
                    first_seen=datetime.fromisoformat(first_seen)
                ))

            return block_infos

    def cleanup_unused_blocks(self) -> int:
        """
        Limpiar bloques no referenciados

        Returns:
            Número de bloques eliminados
        """
        with self._lock:
            with sqlite3.connect(self.db_path) as conn:
                # Encontrar bloques con reference_count = 0
                cursor = conn.execute('SELECT hash FROM blocks WHERE reference_count = 0')
                unused_hashes = [row[0] for row in cursor]

                if unused_hashes:
                    # Eliminar de la tabla de bloques
                    conn.executemany('DELETE FROM blocks WHERE hash = ?', [(h,) for h in unused_hashes])

                    # Limpiar cache
                    for hash_val in unused_hashes:
                        self.hash_cache.pop(hash_val, None)

                conn.commit()

                self.logger.info(f"Eliminados {len(unused_hashes)} bloques no utilizados")
                return len(unused_hashes)

    def get_statistics(self) -> Dict:
        """
        Obtener estadísticas generales del sistema de deduplicación

        Returns:
            Diccionario con estadísticas
        """
        with sqlite3.connect(self.db_path) as conn:
            # Estadísticas de bloques
            cursor = conn.execute('SELECT COUNT(*), SUM(size) FROM blocks')
            total_blocks, total_size = cursor.fetchone()

            # Estadísticas de archivos
            cursor = conn.execute('SELECT COUNT(DISTINCT file_path) FROM file_blocks')
            total_files = cursor.fetchone()[0]

            # Espacio potencial ahorrado
            cursor = conn.execute('''
                SELECT SUM((reference_count - 1) * size)
                FROM blocks
                WHERE reference_count > 1
            ''')
            space_saved = cursor.fetchone()[0] or 0

            return {
                'total_blocks': total_blocks or 0,
                'total_size_bytes': total_size or 0,
                'total_files': total_files or 0,
                'space_saved_bytes': space_saved,
                'deduplication_ratio': (total_size / (total_size - space_saved)) if total_size and space_saved else 1.0,
                'cache_size': len(self.hash_cache)
            }