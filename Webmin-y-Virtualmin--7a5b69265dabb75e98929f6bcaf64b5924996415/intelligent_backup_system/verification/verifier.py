#!/usr/bin/env python3
"""
Módulo de Verificación Automática de Integridad
Implementa verificación automática de integridad de backups usando hashes y checksums
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import os
import hashlib
import sqlite3
import json
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import zlib
import hmac

@dataclass
class IntegrityCheck:
    """Resultado de una verificación de integridad"""
    file_path: str
    expected_hash: str
    calculated_hash: str
    is_valid: bool
    check_time: datetime
    error_message: str = ""

@dataclass
class VerificationResult:
    """Resultado completo de verificación"""
    total_files: int = 0
    valid_files: int = 0
    corrupted_files: int = 0
    missing_files: int = 0
    processing_time: float = 0.0
    checks: List[IntegrityCheck] = None

    def __post_init__(self):
        if self.checks is None:
            self.checks = []

@dataclass
class BackupManifest:
    """Manifiesto de backup con información de integridad"""
    backup_id: str
    timestamp: datetime
    total_files: int
    total_size: int
    compression_type: str
    encryption_type: str
    file_hashes: Dict[str, str]
    metadata_hash: str
    signature: str = ""

class IntegrityVerifier:
    """
    Verificador automático de integridad que valida backups
    usando hashes, checksums y validación de metadatos
    """

    def __init__(self, db_path: str = None, manifest_dir: str = None):
        """
        Inicializar el verificador de integridad

        Args:
            db_path: Ruta a la base de datos de metadatos
            manifest_dir: Directorio donde guardar manifiestos
        """
        self.db_path = db_path or os.path.join(os.getcwd(), 'verification.db')
        self.manifest_dir = Path(manifest_dir or os.path.join(os.getcwd(), 'manifests'))
        self.manifest_dir.mkdir(parents=True, exist_ok=True)
        self.logger = logging.getLogger(__name__)

        # Inicializar base de datos
        self._init_database()

    def _init_database(self):
        """Inicializar base de datos de verificación"""
        with sqlite3.connect(self.db_path) as conn:
            # Tabla de verificaciones realizadas
            conn.execute('''
                CREATE TABLE IF NOT EXISTS verification_history (
                    id INTEGER PRIMARY KEY,
                    timestamp REAL,
                    backup_id TEXT,
                    total_files INTEGER,
                    valid_files INTEGER,
                    corrupted_files INTEGER,
                    missing_files INTEGER,
                    processing_time REAL
                )
            ''')

            # Tabla de archivos verificados
            conn.execute('''
                CREATE TABLE IF NOT EXISTS verified_files (
                    verification_id INTEGER,
                    file_path TEXT,
                    expected_hash TEXT,
                    calculated_hash TEXT,
                    is_valid INTEGER,
                    error_message TEXT,
                    FOREIGN KEY (verification_id) REFERENCES verification_history(id)
                )
            ''')

            # Tabla de manifiestos
            conn.execute('''
                CREATE TABLE IF NOT EXISTS manifests (
                    backup_id TEXT PRIMARY KEY,
                    timestamp REAL,
                    manifest_path TEXT,
                    total_files INTEGER,
                    total_size INTEGER,
                    compression_type TEXT,
                    encryption_type TEXT,
                    metadata_hash TEXT,
                    signature TEXT
                )
            ''')

    def create_backup_manifest(self, backup_id: str, backup_dir: str,
                             compression_type: str = "none",
                             encryption_type: str = "none") -> BackupManifest:
        """
        Crear manifiesto de integridad para un backup

        Args:
            backup_id: ID único del backup
            backup_dir: Directorio del backup
            compression_type: Tipo de compresión usado
            encryption_type: Tipo de encriptación usado

        Returns:
            Manifiesto creado
        """
        self.logger.info(f"Creando manifiesto para backup {backup_id}")

        file_hashes = {}
        total_size = 0

        # Calcular hashes de todos los archivos
        for root, dirs, files in os.walk(backup_dir):
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, backup_dir)

                try:
                    file_hash = self._calculate_file_hash(file_path)
                    file_size = os.path.getsize(file_path)

                    file_hashes[rel_path] = file_hash
                    total_size += file_size

                except Exception as e:
                    self.logger.warning(f"Error calculando hash de {file_path}: {e}")

        # Crear metadatos del manifiesto
        manifest_data = {
            'backup_id': backup_id,
            'timestamp': datetime.now().isoformat(),
            'total_files': len(file_hashes),
            'total_size': total_size,
            'compression_type': compression_type,
            'encryption_type': encryption_type,
            'file_hashes': file_hashes
        }

        # Calcular hash de metadatos
        metadata_json = json.dumps(manifest_data, sort_keys=True)
        metadata_hash = hashlib.sha256(metadata_json.encode()).hexdigest()

        # Crear firma (simulada - en producción usar clave privada)
        signature = self._sign_manifest(metadata_hash)

        # Crear objeto manifiesto
        manifest = BackupManifest(
            backup_id=backup_id,
            timestamp=datetime.now(),
            total_files=len(file_hashes),
            total_size=total_size,
            compression_type=compression_type,
            encryption_type=encryption_type,
            file_hashes=file_hashes,
            metadata_hash=metadata_hash,
            signature=signature
        )

        # Guardar manifiesto en archivo
        manifest_path = self.manifest_dir / f"{backup_id}.manifest"
        with open(manifest_path, 'w') as f:
            json.dump(manifest_data, f, indent=2)

        # Guardar en base de datos
        self._save_manifest_to_db(manifest, str(manifest_path))

        self.logger.info(f"Manifiesto creado: {len(file_hashes)} archivos, {total_size} bytes")
        return manifest

    def _calculate_file_hash(self, file_path: str, algorithm: str = 'sha256') -> str:
        """
        Calcular hash de un archivo

        Args:
            file_path: Ruta al archivo
            algorithm: Algoritmo de hash ('sha256', 'md5', etc.)

        Returns:
            Hash en formato hexadecimal
        """
        hash_func = getattr(hashlib, algorithm)()
        block_size = 8192

        with open(file_path, 'rb') as f:
            while True:
                data = f.read(block_size)
                if not data:
                    break
                hash_func.update(data)

        return hash_func.hexdigest()

    def _sign_manifest(self, metadata_hash: str) -> str:
        """
        Firmar manifiesto (simulado - en producción usar criptografía asimétrica)

        Args:
            metadata_hash: Hash de metadatos

        Returns:
            Firma digital simulada
        """
        # En producción, usar clave privada RSA/ECDSA
        # Por ahora, simulamos con HMAC
        key = b'intelligent_backup_system_key'  # En producción: cargar de archivo seguro
        signature = hmac.new(key, metadata_hash.encode(), hashlib.sha256).hexdigest()
        return signature

    def _save_manifest_to_db(self, manifest: BackupManifest, manifest_path: str):
        """Guardar manifiesto en base de datos"""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute('''
                INSERT OR REPLACE INTO manifests
                (backup_id, timestamp, manifest_path, total_files, total_size,
                 compression_type, encryption_type, metadata_hash, signature)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                manifest.backup_id,
                manifest.timestamp.timestamp(),
                manifest_path,
                manifest.total_files,
                manifest.total_size,
                manifest.compression_type,
                manifest.encryption_type,
                manifest.metadata_hash,
                manifest.signature
            ))

    def verify_backup_integrity(self, backup_id: str, backup_dir: str = None) -> VerificationResult:
        """
        Verificar integridad completa de un backup

        Args:
            backup_id: ID del backup a verificar
            backup_dir: Directorio del backup (opcional, se infiere si no se proporciona)

        Returns:
            Resultado de la verificación
        """
        start_time = datetime.now()

        # Obtener manifiesto
        manifest = self._load_manifest(backup_id)
        if not manifest:
            return VerificationResult(
                checks=[IntegrityCheck("", "", "", False, datetime.now(),
                                     "Manifiesto no encontrado")]
            )

        # Determinar directorio del backup
        if not backup_dir:
            backup_dir = self._find_backup_directory(backup_id)

        if not backup_dir or not os.path.exists(backup_dir):
            return VerificationResult(
                checks=[IntegrityCheck("", "", "", False, datetime.now(),
                                     "Directorio de backup no encontrado")]
            )

        self.logger.info(f"Verificando integridad de backup {backup_id} en {backup_dir}")

        result = VerificationResult()
        result.total_files = manifest.total_files

        # Verificar archivos en paralelo
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = []
            for rel_path, expected_hash in manifest.file_hashes.items():
                file_path = os.path.join(backup_dir, rel_path)
                future = executor.submit(self._verify_single_file, file_path, expected_hash)
                futures.append(future)

            for future in as_completed(futures):
                check = future.result()
                result.checks.append(check)

                if check.is_valid:
                    result.valid_files += 1
                else:
                    if "no encontrado" in check.error_message.lower():
                        result.missing_files += 1
                    else:
                        result.corrupted_files += 1

        result.processing_time = (datetime.now() - start_time).total_seconds()

        # Guardar resultado en historial
        self._save_verification_result(backup_id, result)

        self.logger.info(f"Verificación completada: {result.valid_files}/{result.total_files} archivos válidos")
        return result

    def _load_manifest(self, backup_id: str) -> Optional[BackupManifest]:
        """Cargar manifiesto desde base de datos"""
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute('''
                SELECT timestamp, total_files, total_size, compression_type,
                       encryption_type, metadata_hash, signature
                FROM manifests WHERE backup_id = ?
            ''', (backup_id,))

            row = cursor.fetchone()
            if not row:
                return None

            # Cargar hashes de archivos desde archivo
            manifest_path = self.manifest_dir / f"{backup_id}.manifest"
            if not manifest_path.exists():
                return None

            with open(manifest_path, 'r') as f:
                manifest_data = json.load(f)

            return BackupManifest(
                backup_id=backup_id,
                timestamp=datetime.fromtimestamp(row[0]),
                total_files=row[1],
                total_size=row[2],
                compression_type=row[3],
                encryption_type=row[4],
                file_hashes=manifest_data.get('file_hashes', {}),
                metadata_hash=row[5],
                signature=row[6]
            )

    def _find_backup_directory(self, backup_id: str) -> Optional[str]:
        """Encontrar directorio de backup basado en el ID"""
        # Buscar en patrones comunes
        search_paths = [
            os.path.join(os.getcwd(), 'backups', backup_id),
            os.path.join(os.getcwd(), 'enterprise_backups', backup_id),
            f"/opt/backups/{backup_id}",
            f"/var/backups/{backup_id}"
        ]

        for path in search_paths:
            if os.path.exists(path):
                return path

        return None

    def _verify_single_file(self, file_path: str, expected_hash: str) -> IntegrityCheck:
        """
        Verificar integridad de un archivo individual

        Args:
            file_path: Ruta al archivo
            expected_hash: Hash esperado

        Returns:
            Resultado de la verificación
        """
        check = IntegrityCheck(
            file_path=file_path,
            expected_hash=expected_hash,
            calculated_hash="",
            is_valid=False,
            check_time=datetime.now()
        )

        try:
            if not os.path.exists(file_path):
                check.error_message = "Archivo no encontrado"
                return check

            # Calcular hash actual
            calculated_hash = self._calculate_file_hash(file_path)
            check.calculated_hash = calculated_hash

            # Verificar
            check.is_valid = (calculated_hash == expected_hash)
            if not check.is_valid:
                check.error_message = f"Hash mismatch: expected {expected_hash}, got {calculated_hash}"

        except Exception as e:
            check.error_message = f"Error verificando archivo: {e}"

        return check

    def _save_verification_result(self, backup_id: str, result: VerificationResult):
        """Guardar resultado de verificación en historial"""
        with sqlite3.connect(self.db_path) as conn:
            # Insertar verificación principal
            cursor = conn.execute('''
                INSERT INTO verification_history
                (timestamp, backup_id, total_files, valid_files, corrupted_files,
                 missing_files, processing_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (
                datetime.now().timestamp(),
                backup_id,
                result.total_files,
                result.valid_files,
                result.corrupted_files,
                result.missing_files,
                result.processing_time
            ))

            verification_id = cursor.lastrowid

            # Insertar detalles de archivos
            for check in result.checks:
                conn.execute('''
                    INSERT INTO verified_files
                    (verification_id, file_path, expected_hash, calculated_hash,
                     is_valid, error_message)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (
                    verification_id,
                    check.file_path,
                    check.expected_hash,
                    check.calculated_hash,
                    1 if check.is_valid else 0,
                    check.error_message
                ))

    def get_verification_history(self, backup_id: str = None, limit: int = 50) -> List[Dict]:
        """
        Obtener historial de verificaciones

        Args:
            backup_id: ID del backup (opcional, todos si no se especifica)
            limit: Número máximo de registros

        Returns:
            Lista de verificaciones
        """
        with sqlite3.connect(self.db_path) as conn:
            if backup_id:
                cursor = conn.execute('''
                    SELECT id, timestamp, backup_id, total_files, valid_files,
                           corrupted_files, missing_files, processing_time
                    FROM verification_history
                    WHERE backup_id = ?
                    ORDER BY timestamp DESC
                    LIMIT ?
                ''', (backup_id, limit))
            else:
                cursor = conn.execute('''
                    SELECT id, timestamp, backup_id, total_files, valid_files,
                           corrupted_files, missing_files, processing_time
                    FROM verification_history
                    ORDER BY timestamp DESC
                    LIMIT ?
                ''', (limit,))

            history = []
            for row in cursor:
                history.append({
                    'id': row[0],
                    'timestamp': datetime.fromtimestamp(row[1]),
                    'backup_id': row[2],
                    'total_files': row[3],
                    'valid_files': row[4],
                    'corrupted_files': row[5],
                    'missing_files': row[6],
                    'processing_time': row[7]
                })

            return history

    def verify_manifest_signature(self, backup_id: str) -> bool:
        """
        Verificar firma digital del manifiesto

        Args:
            backup_id: ID del backup

        Returns:
            True si la firma es válida
        """
        manifest = self._load_manifest(backup_id)
        if not manifest:
            return False

        # Verificar firma
        expected_signature = self._sign_manifest(manifest.metadata_hash)
        return hmac.compare_digest(expected_signature, manifest.signature)

    def repair_corrupted_backup(self, backup_id: str, source_dir: str = None) -> Dict[str, any]:
        """
        Intentar reparar un backup corrupto usando archivos fuente

        Args:
            backup_id: ID del backup corrupto
            source_dir: Directorio fuente para reparación

        Returns:
            Resultado de la reparación
        """
        self.logger.info(f"Intentando reparar backup {backup_id}")

        # Obtener manifiesto
        manifest = self._load_manifest(backup_id)
        if not manifest:
            return {'success': False, 'error': 'Manifiesto no encontrado'}

        backup_dir = self._find_backup_directory(backup_id)
        if not backup_dir:
            return {'success': False, 'error': 'Directorio de backup no encontrado'}

        if not source_dir:
            return {'success': False, 'error': 'Directorio fuente no especificado'}

        repaired_files = 0
        failed_repairs = 0

        # Verificar cada archivo
        for rel_path, expected_hash in manifest.file_hashes.items():
            backup_path = os.path.join(backup_dir, rel_path)
            source_path = os.path.join(source_dir, rel_path)

            # Si el archivo está corrupto o faltante
            if not os.path.exists(backup_path) or not self._verify_single_file(backup_path, expected_hash).is_valid:
                if os.path.exists(source_path):
                    try:
                        # Copiar archivo fuente
                        os.makedirs(os.path.dirname(backup_path), exist_ok=True)
                        shutil.copy2(source_path, backup_path)
                        repaired_files += 1
                        self.logger.info(f"Reparado: {rel_path}")
                    except Exception as e:
                        failed_repairs += 1
                        self.logger.error(f"Error reparando {rel_path}: {e}")
                else:
                    failed_repairs += 1
                    self.logger.warning(f"Archivo fuente no encontrado: {source_path}")

        return {
            'success': True,
            'repaired_files': repaired_files,
            'failed_repairs': failed_repairs,
            'total_processed': len(manifest.file_hashes)
        }

    def get_backup_health_score(self, backup_id: str) -> float:
        """
        Calcular puntuación de salud del backup (0.0 a 1.0)

        Args:
            backup_id: ID del backup

        Returns:
            Puntuación de salud (1.0 = perfecto)
        """
        # Obtener últimas verificaciones
        history = self.get_verification_history(backup_id, limit=5)

        if not history:
            return 0.0

        # Calcular promedio de archivos válidos
        total_valid = sum(h['valid_files'] for h in history)
        total_files = sum(h['total_files'] for h in history)

        if total_files == 0:
            return 0.0

        # Factor de recencia (verificaciones más recientes pesan más)
        weights = [0.5, 0.2, 0.15, 0.1, 0.05][:len(history)]
        weights.reverse()

        weighted_score = 0
        total_weight = 0

        for i, h in enumerate(history):
            score = h['valid_files'] / h['total_files'] if h['total_files'] > 0 else 0
            weighted_score += score * weights[i]
            total_weight += weights[i]

        return weighted_score / total_weight if total_weight > 0 else 0.0